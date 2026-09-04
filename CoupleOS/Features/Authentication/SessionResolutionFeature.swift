import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct SessionResolutionFeature {
    @ObservableState
    struct State: Equatable {
        let id: UUID
        let authenticatedUser: AuthenticatedUser
        var error: UserClientError?
    }

    enum Action {
        case retryTapped
    }

    var body: some ReducerOf<Self> { EmptyReducer() }
}

@Reducer
nonisolated struct ProfileProvisioningFeature {
    @ObservableState
    struct State: Equatable {
        let id: UUID
        let authenticatedUser: AuthenticatedUser
        let firstName: String
        var error: UserClientError?
    }

    enum Action {
        case retryTapped
    }

    var body: some ReducerOf<Self> { EmptyReducer() }
}
