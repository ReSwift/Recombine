import SwiftUI

public struct OptionalStoreView<
    BaseState,
    SubState: Equatable,
    RawAction,
    BaseRefinedAction,
    SubRefinedAction,
    Content: View
>: View {
    public typealias Lens = LensedStore<
        BaseState,
        SubState,
        RawAction,
        BaseRefinedAction,
        SubRefinedAction
    >
    public typealias Underlying = AnyStore<
        BaseState,
        SubState?,
        RawAction,
        BaseRefinedAction,
        SubRefinedAction
    >
    let content: (Lens) -> Content
    @ObservedObject var store: Underlying

    public init<Store: StoreProtocol>(
        store: Store,
        content: @escaping (Lens) -> Content
    )
    where Store.SubState == Optional<SubState>,
          Store.BaseState == BaseState,
          Store.RawAction == RawAction,
          Store.BaseRefinedAction == BaseRefinedAction,
          Store.SubRefinedAction == SubRefinedAction
    {
        self.store = store.eraseToAnyStore()
        self.content = content
    }

    public var body: some View {
        if let state = store.state {
            content(store.lensing(state: { _ in state }))
        }
    }
}
