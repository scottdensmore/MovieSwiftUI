import Foundation

public protocol Action {}
public protocol FluxState {}

public typealias DispatchFunction = (Action) -> Void

public protocol AsyncAction: Action {
    func execute(state: FluxState?, dispatch: @escaping DispatchFunction)
}

public typealias Middleware<State> =
    (@escaping DispatchFunction, @escaping () -> State) -> (@escaping DispatchFunction) -> DispatchFunction
