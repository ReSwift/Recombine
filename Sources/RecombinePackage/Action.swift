public enum ActionStrata<RawAction, RefinedAction> {
    public typealias Raw = RawAction
    public typealias Refined = RefinedAction
    case raw(Raw)
    case refined(Refined)
}
