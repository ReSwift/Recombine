import Combine
import Foundation

public final class AtomicCollection<Element> {
    public typealias Collection = [Element]
    private let lock: os_unfair_lock_t
    private var wrapped: Collection
    private var semaphores: [DispatchSemaphore] = []

    /// Atomically get or set the value of the variable.
    public var value: Collection {
        get {
            access { $0 }
        }
        set(newValue) {
            replace(newValue)
        }
    }

    /// Initialize the variable with the given initial value.
    ///
    /// - parameters:
    ///   - value: Initial value for `self`.
    public init(_ value: Collection = []) {
        wrapped = value
        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    internal func semaphore() -> DispatchSemaphore {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        let semaphore = DispatchSemaphore(value: 0)
        if !wrapped.isEmpty {
            semaphore.signal()
        } else {
            semaphores.append(semaphore)
        }
        return semaphore
    }

    /// Atomically modifies the variable.
    ///
    /// - parameters:
    ///   - action: A closure that takes the current value.
    ///
    /// - returns: The result of the action.
    @discardableResult
    public func modify<Mapped>(_ action: (inout Collection) throws -> Mapped) rethrows -> Mapped {
        os_unfair_lock_lock(lock)
        defer {
            if !wrapped.isEmpty {
                let s = self.semaphores
                semaphores.removeAll()
                os_unfair_lock_unlock(lock)
                s.forEach { $0.signal() }
            } else {
                os_unfair_lock_unlock(lock)
            }
        }
        return try action(&wrapped)
    }

    /// Atomically perform an arbitrary action using the current value of the
    /// variable.
    ///
    /// - parameters:
    ///   - action: A closure that takes the current value.
    ///
    /// - returns: The result of the action.
    @discardableResult
    public func access<Mapped>(_ action: (Collection) throws -> Mapped) rethrows -> Mapped {
        try modify { try action($0) }
    }

    /// Atomically replace the contents of the variable.
    ///
    /// - parameters:
    ///   - newValue: A new value for the variable.
    ///
    /// - returns: The old value.
    @discardableResult
    public func replace(_ newValue: Collection) -> Collection {
        modify { (ward: inout Collection) in
            defer { ward = newValue }
            return ward
        }
    }
}

/// Convenient windowing extensions.
@available(iOS 10.0, *)
@available(macOS 10.12, *)
@available(tvOS 10.0, *)
@available(watchOS 3.0, *)
public extension AtomicCollection {
    /// Adds a new element to the end of this protected collection.
    ///
    /// - Parameter newElement: The `Element` to append.
    func append(_ newElement: Collection.Element) {
        modify { $0.append(newElement) }
    }

    /// Adds the elements of a sequence to the end of this protected collection.
    ///
    /// - Parameter newElements: The `Sequence` to append.
    func append<S: Sequence>(contentsOf newElements: S) where S.Element == Collection.Element {
        modify { $0.append(contentsOf: newElements) }
    }
}

public struct AtomicCollectionPublisher<Output>: Publisher {
    public typealias Failure = Never

    public let underlying: AtomicCollection<Output>

    public init(_ underlying: AtomicCollection<Output>) {
        self.underlying = underlying
    }

    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let subscription = Subscription(underlying: underlying, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

private extension AtomicCollectionPublisher {
    final class Subscription<S: Subscriber> where S.Input == Output, S.Failure == Failure {
        private let underlying: AtomicCollection<Output>
        private var subscriber: S?

        init(underlying: AtomicCollection<Output>, subscriber: S) {
            self.underlying = underlying
            self.subscriber = subscriber
        }
    }
}

extension AtomicCollectionPublisher.Subscription: Subscription {
    func request(_ demand: Subscribers.Demand) {
        DispatchQueue.global().async { [weak self] in
            var demand = demand
            while let subscriber = self?.subscriber, demand > 0 {
                self?.underlying.semaphore().wait()
                while let value = self?.underlying.modify({ collection -> Output? in
                    if !collection.isEmpty {
                        return collection.removeFirst()
                    } else {
                        return nil
                    }
                }), demand > 0 {
                    demand -= 1
                    demand += DispatchQueue.main.sync {
                        subscriber.receive(value)
                    }
                }
            }
        }
    }
}

extension AtomicCollectionPublisher.Subscription: Cancellable {
    func cancel() {
        subscriber = nil
    }
}

public extension AtomicCollection {
    var publisher: AtomicCollectionPublisher<Element> {
        .init(self)
    }
}
