// Copyright © 2020 Metabolist. All rights reserved.

import Combine
import Foundation
import ServiceLayer

public final class RootViewModel: ObservableObject {
    @Published public private(set) var identification: Identification?

    @Published private var mostRecentlyUsedIdentityID: UUID?
    private let allIdentitiesService: AllIdentitiesService
    private let userNotificationService: UserNotificationService
    private let registerForRemoteNotifications: () -> AnyPublisher<Data, Error>
    private var cancellables = Set<AnyCancellable>()

    public init(environment: AppEnvironment,
                registerForRemoteNotifications: @escaping () -> AnyPublisher<Data, Error>) throws {
        allIdentitiesService = try AllIdentitiesService(environment: environment)
        userNotificationService = UserNotificationService(environment: environment)
        self.registerForRemoteNotifications = registerForRemoteNotifications

        allIdentitiesService.mostRecentlyUsedIdentityID.assign(to: &$mostRecentlyUsedIdentityID)

        newIdentitySelected(id: mostRecentlyUsedIdentityID)

        userNotificationService.isAuthorized()
            .filter { $0 }
            .zip(registerForRemoteNotifications())
            .map { $1 }
            .flatMap(allIdentitiesService.updatePushSubscriptions(deviceToken:))
            .sink { _ in } receiveValue: { _ in }
            .store(in: &cancellables)
    }
}

public extension RootViewModel {
    func newIdentitySelected(id: UUID?) {
        guard let id = id else {
            identification = nil

            return
        }

        let identification: Identification

        do {
            identification = try Identification(service: allIdentitiesService.identityService(id: id))
            self.identification = identification
        } catch {
            return
        }

        identification.observationErrors
            .receive(on: RunLoop.main)
            .map { [weak self] _ in self?.mostRecentlyUsedIdentityID }
            .sink { [weak self] in self?.newIdentitySelected(id: $0) }
            .store(in: &cancellables)

        identification.service.updateLastUse()
            .sink { _ in } receiveValue: { _ in }
            .store(in: &cancellables)

        userNotificationService.isAuthorized()
            .filter { $0 }
            .zip(registerForRemoteNotifications())
            .filter { identification.identity.lastRegisteredDeviceToken != $1 }
            .map { ($1, identification.identity.pushSubscriptionAlerts) }
            .flatMap(identification.service.createPushSubscription(deviceToken:alerts:))
            .sink { _ in } receiveValue: { _ in }
            .store(in: &cancellables)
    }

    func deleteIdentity(_ identity: Identity) {
        allIdentitiesService.deleteIdentity(identity)
            .sink { _ in } receiveValue: { _ in }
            .store(in: &cancellables)
    }

    func addIdentityViewModel() -> AddIdentityViewModel {
        AddIdentityViewModel(allIdentitiesService: allIdentitiesService)
    }
}
