public struct SideEffect<RefinedAction, Environment> {
    public typealias Function = ([RefinedAction], Environment) -> Void
    internal let closure: Function

    /// Create a passthrough `SideEffect`.
    public init() {
        closure = { _, _ in }
    }

    /// Create a `SideEffect` out of multiple other `SideEffect`s.
    public init(_ effects: Self...) {
        self = effects.reduce(.init()) { $0.appending($1) }
    }

    /// Initialises the `SideEffect` with a transformative function.
    /// - parameter closure: The function that receives actions.
    public init(
        _ closure: @escaping Function
    ) {
        self.closure = closure
    }

    /// Creates a `SideEffect` that will run both the callee and caller's closures when run.
    public func appending(_ other: Self) -> Self {
        .init {
            self.closure($0, $1)
            other.closure($0, $1)
        }
    }
}
