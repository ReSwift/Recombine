# Recombine

Recombine is a [Redux](https://github.com/reactjs/redux)-like implementation of the unidirectional data flow architecture in Swift.

# About Recombine

Recombine relies on three principles:
- **The Store** stores your entire app state in the form of a single data structure. This state can only be modified by dispatching Actions to the store. Whenever the state in the store changes, the store will notify all observers.
- **Actions** are a declarative way of describing a state change. Actions don't contain any code, they are consumed by the store and forwarded to reducers. Reducers will handle the actions by implementing a different state change for each action.
- **Reducers** provide pure functions that create a new app state from actions and the current app state.

![](Docs/img/recombine_concept.png)

# Installation

Whoa slow down, this is beta software at the moment.

# Credits

- Huge thanks to [Evan Czaplicki](https://github.com/evancz) for creating [Elm](https://github.com/elm-lang), the first language to implement unidirectional data flow as a paradigm.
- Thanks a lot to [Dan Abramov](https://github.com/gaearon) for building [Redux](https://github.com/reactjs/redux), many ideas in here were provided by his library.
- Thanks a lot to [Benjamin Encz](https://github.com/Ben-G) for building [ReSwift](https://github.com/ReSwift/ReSwift), the base from which this project was originally derived.

# Get in touch

If you have any questions, you can find the core team on twitter:

- [@chartortorella](https://twitter.com/chartortorella)
