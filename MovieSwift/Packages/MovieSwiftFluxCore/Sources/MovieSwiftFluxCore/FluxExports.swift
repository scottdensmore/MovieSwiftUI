// Re-export the in-repo `Flux` Redux primitives (Store, Action, AsyncAction,
// FluxState, DispatchFunction, Reducer, Middleware, ConnectedView,
// StoreConnector, StoreProvider) so anything importing `MovieSwiftFluxCore` —
// the app targets and tests, which already link it — sees them without a
// separate `import Flux` or an extra project-level package link.
@_exported import Flux
