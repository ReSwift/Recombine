import Combine
import SwiftUI

public class PreviewBaseStore<
    State: Equatable,
    RawAction,
    RefinedAction
>: BaseStore<
    State,
    RawAction,
    RefinedAction
> {
    public convenience init(
        state: State
    ) {
        self.init(
            state: state,
            reducer: PureReducer(),
            publishOn: RunLoop.main
        )
    }
}
