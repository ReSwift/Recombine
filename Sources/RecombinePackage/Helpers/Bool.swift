extension Bool {
    func `if`<T>(true truth: @autoclosure () throws -> T, false falsity: @autoclosure () throws -> T) rethrows -> T {
        if self {
            return try truth()
        } else {
            return try falsity()
        }
    }

    func `if`<T>(true value: @autoclosure () throws -> T?) rethrows -> T? {
        if self {
            return try value()
        } else {
            return nil
        }
    }

    func `if`<T>(false value: @autoclosure () throws -> T?) rethrows -> T? {
        if self {
            return nil
        } else {
            return try value()
        }
    }
}
