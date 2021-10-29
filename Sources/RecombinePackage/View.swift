import SwiftUI

public extension View {
    @available(iOS, introduced: 15)
    func sync<Value: Equatable>(_ first: Binding<Value>, with second: FocusState<Value>.Binding) -> some View {
        onChange(of: first.wrappedValue) { second.wrappedValue = $0 }
            .onChange(of: second.wrappedValue) { first.wrappedValue = $0 }
    }
}
