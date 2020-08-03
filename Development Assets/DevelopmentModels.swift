// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import Combine

// swiftlint:disable force_try
private let decoder = MastodonDecoder()
private var cancellables = Set<AnyCancellable>()
private let devInstanceURL = URL(string: "https://mastodon.social")!
private let devIdentityID = "DEVELOPMENT_IDENTITY_ID"
private let devAccessToken = "DEVELOPMENT_ACCESS_TOKEN"

extension Secrets {
    static func fresh() -> Secrets { Secrets(keychain: FakeKeychain()) }

    static let development: Secrets = {
        let secrets = Secrets.fresh()

        try! secrets.set("DEVELOPMENT_CLIENT_ID", forItem: .clientID, forIdentityID: devIdentityID)
        try! secrets.set("DEVELOPMENT_CLIENT_SECRET", forItem: .clientSecret, forIdentityID: devIdentityID)
        try! secrets.set(devAccessToken, forItem: .accessToken, forIdentityID: devIdentityID)

        return secrets
    }()
}

extension Preferences {
    static func fresh() -> Preferences { Preferences(userDefaults: FakeUserDefaults()) }

    static let development: Preferences = {
        let preferences = Preferences.fresh()

        preferences[.recentIdentityID] = devIdentityID

        return preferences
    }()
}

extension MastodonClient {
    static func fresh() -> MastodonClient { MastodonClient(configuration: .stubbing) }

    static let development: MastodonClient = {
        let client = MastodonClient.fresh()

        client.instanceURL = devInstanceURL
        client.accessToken = devAccessToken

        return client
    }()
}

extension Account {
    static let development = try! decoder.decode(Account.self, from: Data(officialAccountJSON.utf8))
}

extension Instance {
    static let development = try! decoder.decode(Instance.self, from: Data(officialInstanceJSON.utf8))
}

extension IdentityDatabase {
    static func fresh() -> IdentityDatabase { try! IdentityDatabase(inMemory: true) }

    static var development: IdentityDatabase = {
        let db = IdentityDatabase.fresh()

        db.createIdentity(id: devIdentityID, url: devInstanceURL)
            .receive(on: ImmediateScheduler.shared)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        db.updateAccount(.development, forIdentityID: devIdentityID)
            .receive(on: ImmediateScheduler.shared)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        db.updateInstance(.development, forIdentityID: devIdentityID)
            .receive(on: ImmediateScheduler.shared)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        return db
    }()
}

extension Identity {
    static let development: Identity = {
        var identity: Identity?

        IdentityDatabase.development.identityObservation(id: devIdentityID)
            .assertNoFailure()
            .sink(receiveValue: { identity = $0 })
            .store(in: &cancellables)

        return identity!
    }()
}

extension AppEnvironment {
    static func fresh(
        URLSessionConfiguration: URLSessionConfiguration = .stubbing,
        identityDatabase: IdentityDatabase = .fresh(),
        preferences: Preferences = .fresh(),
        secrets: Secrets = .fresh(),
        webAuthSessionType: WebAuthSession.Type = SuccessfulStubbingWebAuthSession.self) -> AppEnvironment {
        AppEnvironment(
            URLSessionConfiguration: URLSessionConfiguration,
            identityDatabase: identityDatabase,
            preferences: preferences,
            secrets: secrets,
            webAuthSessionType: webAuthSessionType)
    }

    static let development = AppEnvironment(
        URLSessionConfiguration: .stubbing,
        identityDatabase: .development,
        preferences: .development,
        secrets: .development,
        webAuthSessionType: SuccessfulStubbingWebAuthSession.self)
}

extension RootViewModel {
    static let development = RootViewModel(environment: .development)
}

extension MainNavigationViewModel {
    static let development = RootViewModel.development.mainNavigationViewModel(identityID: devIdentityID)!
}

extension SettingsViewModel {
    static let development = MainNavigationViewModel.development.settingsViewModel()
}

// swiftlint:enable force_try