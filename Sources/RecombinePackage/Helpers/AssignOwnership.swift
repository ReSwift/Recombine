// Copyright (c) 2020 Combine Community, and/or Shai Mishali
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Combine

/// The ownership of an object
///
/// - seealso: https://docs.swift.org/swift-book/LanguageGuide/AutomaticReferenceCounting.html#ID52
public enum ObjectOwnership {
    /// Keep a strong hold of the object, preventing ARC
    /// from disposing it until its released or has no references.
    case strong

    /// Weakly owned. Does not keep a strong hold of the object,
    /// allowing ARC to dispose it even if its referenced.
    case weak

    /// Unowned. Similar to weak, but implicitly unwrapped so may
    /// crash if the object is released beore being accessed.
    case unowned
}

public extension Publisher {
    /// Assigns a publisher’s output to a property of an object.
    ///
    /// - parameter keyPath: A key path that indicates the subject to send into.
    /// - parameter object: The object that contains the subject.
    ///                     The subscriber sends into the object’s subject every time
    ///                     it receives a new value.
    /// - parameter ownership: The retainment / ownership strategy for the object, defaults to `strong`.
    ///
    /// - returns: An AnyCancellable instance. Call cancel() on this instance when you no longer want
    ///            the publisher to automatically assign the property. Deinitializing this instance
    ///            will also cancel automatic assignment.
    func forward<Root: AnyObject, S: Subject>(
        to keyPath: KeyPath<Root, S>,
        on object: Root,
        ownership: ObjectOwnership
    ) -> AnyCancellable
        where S.Output == Output, S.Failure == Failure
    {
        switch ownership {
        case .strong:
            return sink {
                object[keyPath: keyPath].send(completion: $0)
            } receiveValue: {
                object[keyPath: keyPath].send($0)
            }
        case .weak:
            return sink { [weak object] in
                object?[keyPath: keyPath].send(completion: $0)
            } receiveValue: { [weak object] in
                object?[keyPath: keyPath].send($0)
            }
        case .unowned:
            return sink { [unowned object] in
                object[keyPath: keyPath].send(completion: $0)
            } receiveValue: {
                object[keyPath: keyPath].send($0)
            }
        }
    }

    func forward<Root1: AnyObject, Root2: AnyObject, S1: Subject, S2: Subject>(
        to keyPath1: KeyPath<Root1, S1>, on object1: Root1,
        and keyPath2: KeyPath<Root2, S2>, on object2: Root2,
        ownership: ObjectOwnership
    ) -> AnyCancellable
        where S1.Output == Output, S1.Failure == Failure,
        S2.Output == Output, S2.Failure == Failure
    {
        switch ownership {
        case .strong:
            return sink {
                object1[keyPath: keyPath1].send(completion: $0)
                object2[keyPath: keyPath2].send(completion: $0)
            } receiveValue: {
                object1[keyPath: keyPath1].send($0)
                object2[keyPath: keyPath2].send($0)
            }
        case .weak:
            return sink { [weak object1, weak object2] in
                object1?[keyPath: keyPath1].send(completion: $0)
                object2?[keyPath: keyPath2].send(completion: $0)
            } receiveValue: { [weak object1, weak object2] in
                object1?[keyPath: keyPath1].send($0)
                object2?[keyPath: keyPath2].send($0)
            }
        case .unowned:
            return sink { [unowned object1, unowned object2] in
                object1[keyPath: keyPath1].send(completion: $0)
                object2[keyPath: keyPath2].send(completion: $0)
            } receiveValue: { [unowned object1, unowned object2] in
                object1[keyPath: keyPath1].send($0)
                object2[keyPath: keyPath2].send($0)
            }
        }
    }

    func forward<Root1: AnyObject, Root2: AnyObject, Root3: AnyObject, S1: Subject, S2: Subject, S3: Subject>(
        to keyPath1: KeyPath<Root1, S1>, on object1: Root1,
        and keyPath2: KeyPath<Root2, S2>, on object2: Root2,
        and keyPath3: KeyPath<Root3, S3>, on object3: Root3,
        ownership: ObjectOwnership
    ) -> AnyCancellable
        where S1.Output == Output, S1.Failure == Failure,
        S2.Output == Output, S2.Failure == Failure,
        S3.Output == Output, S3.Failure == Failure
    {
        switch ownership {
        case .strong:
            return sink {
                object1[keyPath: keyPath1].send(completion: $0)
                object2[keyPath: keyPath2].send(completion: $0)
                object3[keyPath: keyPath3].send(completion: $0)
            } receiveValue: {
                object1[keyPath: keyPath1].send($0)
                object2[keyPath: keyPath2].send($0)
                object3[keyPath: keyPath3].send($0)
            }
        case .weak:
            return sink { [weak object1, weak object2, weak object3] in
                object1?[keyPath: keyPath1].send(completion: $0)
                object2?[keyPath: keyPath2].send(completion: $0)
                object3?[keyPath: keyPath3].send(completion: $0)
            } receiveValue: { [weak object1, weak object2, weak object3] in
                object1?[keyPath: keyPath1].send($0)
                object2?[keyPath: keyPath2].send($0)
                object3?[keyPath: keyPath3].send($0)
            }
        case .unowned:
            return sink { [unowned object1, unowned object2, unowned object3] in
                object1[keyPath: keyPath1].send(completion: $0)
                object2[keyPath: keyPath2].send(completion: $0)
                object3[keyPath: keyPath3].send(completion: $0)
            } receiveValue: { [unowned object1, unowned object2] in
                object1[keyPath: keyPath1].send($0)
                object2[keyPath: keyPath2].send($0)
                object3[keyPath: keyPath3].send($0)
            }
        }
    }
}

public extension Publisher where Self.Failure == Never {
    /// Assigns a publisher’s output to a property of an object.
    ///
    /// - parameter keyPath: A key path that indicates the property to assign.
    /// - parameter object: The object that contains the property.
    ///                     The subscriber assigns the object’s property every time
    ///                     it receives a new value.
    /// - parameter ownership: The retainment / ownership strategy for the object, defaults to `strong`.
    ///
    /// - returns: An AnyCancellable instance. Call cancel() on this instance when you no longer want
    ///            the publisher to automatically assign the property. Deinitializing this instance
    ///            will also cancel automatic assignment.
    func assign<Root: AnyObject>(
        to keyPath: ReferenceWritableKeyPath<Root, Self.Output>,
        on object: Root,
        ownership: ObjectOwnership
    ) -> AnyCancellable {
        switch ownership {
        case .strong:
            return assign(to: keyPath, on: object)
        case .weak:
            return sink { [weak object] value in
                object?[keyPath: keyPath] = value
            }
        case .unowned:
            return sink { [unowned object] value in
                object[keyPath: keyPath] = value
            }
        }
    }

    /// Assigns each element from a Publisher to properties of the provided objects
    ///
    /// - Parameters:
    ///   - keyPath1: The key path of the first property to assign.
    ///   - object1: The first object on which to assign the value.
    ///   - keyPath2: The key path of the second property to assign.
    ///   - object2: The second object on which to assign the value.
    ///   - ownership: The retainment / ownership strategy for the object, defaults to `strong`.
    ///
    /// - Returns: A cancellable instance; used when you end assignment of the received value.
    ///            Deallocation of the result will tear down the subscription stream.
    func assign<Root1: AnyObject, Root2: AnyObject>(
        to keyPath1: ReferenceWritableKeyPath<Root1, Output>, on object1: Root1,
        and keyPath2: ReferenceWritableKeyPath<Root2, Output>, on object2: Root2,
        ownership: ObjectOwnership
    ) -> AnyCancellable {
        switch ownership {
        case .strong:
            return sink { value in
                object1[keyPath: keyPath1] = value
                object2[keyPath: keyPath2] = value
            }
        case .weak:
            return sink { [weak object1, weak object2] value in
                object1?[keyPath: keyPath1] = value
                object2?[keyPath: keyPath2] = value
            }
        case .unowned:
            return sink { [unowned object1, unowned object2] value in
                object1[keyPath: keyPath1] = value
                object2[keyPath: keyPath2] = value
            }
        }
    }

    /// Assigns each element from a Publisher to properties of the provided objects
    ///
    /// - Parameters:
    ///   - keyPath1: The key path of the first property to assign.
    ///   - object1: The first object on which to assign the value.
    ///   - keyPath2: The key path of the second property to assign.
    ///   - object2: The second object on which to assign the value.
    ///   - keyPath3: The key path of the third property to assign.
    ///   - object3: The third object on which to assign the value.
    ///   - ownership: The retainment / ownership strategy for the object, defaults to `strong`.
    ///
    /// - Returns: A cancellable instance; used when you end assignment of the received value.
    ///            Deallocation of the result will tear down the subscription stream.
    func assign<Root1: AnyObject, Root2: AnyObject, Root3: AnyObject>(
        to keyPath1: ReferenceWritableKeyPath<Root1, Output>, on object1: Root1,
        and keyPath2: ReferenceWritableKeyPath<Root2, Output>, on object2: Root2,
        and keyPath3: ReferenceWritableKeyPath<Root3, Output>, on object3: Root3,
        ownership: ObjectOwnership
    ) -> AnyCancellable {
        switch ownership {
        case .strong:
            return sink { value in
                object1[keyPath: keyPath1] = value
                object2[keyPath: keyPath2] = value
                object3[keyPath: keyPath3] = value
            }
        case .weak:
            return sink { [weak object1, weak object2, weak object3] value in
                object1?[keyPath: keyPath1] = value
                object2?[keyPath: keyPath2] = value
                object3?[keyPath: keyPath3] = value
            }
        case .unowned:
            return sink { [unowned object1, unowned object2, unowned object3] value in
                object1[keyPath: keyPath1] = value
                object2[keyPath: keyPath2] = value
                object3[keyPath: keyPath3] = value
            }
        }
    }
}
