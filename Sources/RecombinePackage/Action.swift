extension Store {
    public enum ActionStrata {
        case raw(RawAction)
        case refined(RefinedAction)
    }
}
