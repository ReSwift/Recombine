# Recombine

Recombine is a [Redux](https://github.com/reactjs/redux)-like implementation of the unidirectional data flow architecture in Swift.

# About Recombine

Recombine relies on three principles:
- **The Store** stores your entire app state in the form of a single data structure. This state can only be modified by dispatching Actions to the store. Whenever the state in the store changes, the store will notify all observers.
- **Actions** are a declarative way of describing a state change. Actions don't contain any code, they are consumed by the store and forwarded to reducers. Reducers will handle the actions by implementing a different state change for each action.
- **Reducers** provide pure functions that create a new app state from actions and the current app state.

![](Docs/img/recombine_concept.png)

For a very simple app, one that maintains a counter that can be increased and decreased, you can define the app state as following:

```swift
struct AppState {
  var counter: Int
}
```

You would also define two actions, one for increasing and one for decreasing the counter. For the simple actions in this example we can use a very basic enum:

```swift
// It's recommended that you use enums for your actions to ensure a well typed implementation.
enum AppAction: Action {
    case modify(Modification)
    
    enum Modification {
        case increase
        case decrease
    }
}
```

Your reducer needs to respond to these different actions, that can be done by switching over the value of action:

```swift
let appReducer: Reducer<AppState> { state, action in
    var state = state
    switch action {
    case .modify(.increase):
        state.counter += 1
    case .modify(.decrease):
        state.counter -= 1
    }
    return state
}
```

# Credits

- Huge thanks to [Evan Czaplicki](https://github.com/evancz) for creating [Elm](https://github.com/elm-lang), the first language to implement unidirectional data flow as a paradigm.
- Thanks a lot to [Dan Abramov](https://github.com/gaearon) for building [Redux](https://github.com/reactjs/redux), many ideas in here were provided by his library.
- Thanks a lot to [Benjamin Encz](https://github.com/Ben-G) for building [ReSwift](https://github.com/ReSwift/ReSwift), the base from which this project was originally derived.

# Get in touch

If you have any questions, you can find the core team on twitter:

- [@chartortorella](https://twitter.com/chartortorella)
