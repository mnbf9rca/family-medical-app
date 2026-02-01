import Foundation
import Testing
@testable import FamilyMedicalApp

struct AuthenticationFlowStateTests {
    // MARK: - State Distinctness

    @Test
    func newUserFlowStatesAreDistinct() {
        let states: [AuthenticationFlowState] = [
            .welcome,
            .usernameEntry(isNewUser: true),
            .passphraseCreation(username: "testuser"),
            .passphraseConfirmation(username: "testuser", passphrase: "test"),
            .biometricSetup(username: "testuser", passphrase: "test", isReturningUser: false)
        ]

        // Each state should be unique
        for (index, state) in states.enumerated() {
            for (otherIndex, otherState) in states.enumerated() where index != otherIndex {
                #expect(state != otherState)
            }
        }
    }

    @Test
    func returningUserStatesIncludeIsReturningFlag() {
        let returningState = AuthenticationFlowState.passphraseEntry(username: "testuser", isReturningUser: true)
        let newUserState = AuthenticationFlowState.passphraseCreation(username: "testuser")

        #expect(returningState != newUserState)
    }

    // MARK: - Equatable Conformance

    @Test
    func sameStatesAreEqual() {
        let state1 = AuthenticationFlowState.welcome
        let state2 = AuthenticationFlowState.welcome
        #expect(state1 == state2)
    }

    @Test
    func usernameEntryStatesWithSameParameterAreEqual() {
        let state1 = AuthenticationFlowState.usernameEntry(isNewUser: true)
        let state2 = AuthenticationFlowState.usernameEntry(isNewUser: true)
        #expect(state1 == state2)
    }

    @Test
    func usernameEntryStatesWithDifferentParameterAreNotEqual() {
        let state1 = AuthenticationFlowState.usernameEntry(isNewUser: true)
        let state2 = AuthenticationFlowState.usernameEntry(isNewUser: false)
        #expect(state1 != state2)
    }

    @Test
    func statesWithSameAssociatedValuesAreEqual() {
        let state1 = AuthenticationFlowState.passphraseCreation(username: "testuser")
        let state2 = AuthenticationFlowState.passphraseCreation(username: "testuser")
        #expect(state1 == state2)
    }

    @Test
    func statesWithDifferentAssociatedValuesAreNotEqual() {
        let state1 = AuthenticationFlowState.passphraseCreation(username: "user1")
        let state2 = AuthenticationFlowState.passphraseCreation(username: "user2")
        #expect(state1 != state2)
    }

    // MARK: - All States Exist

    @Test
    func allExpectedStatesExist() {
        // Verify all states can be instantiated (compile-time check via usage)
        let loginResult = OpaqueLoginResult(
            exportKey: Data(repeating: 0x42, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        let _: [AuthenticationFlowState] = [
            .welcome,
            .usernameEntry(isNewUser: true),
            .usernameEntry(isNewUser: false),
            .passphraseCreation(username: "testuser"),
            .passphraseConfirmation(username: "testuser", passphrase: "pass"),
            .passphraseEntry(username: "testuser", isReturningUser: true),
            .biometricSetup(username: "testuser", passphrase: "pass", isReturningUser: false),
            .accountExistsConfirmation(username: "testuser", loginResult: loginResult, enableBiometric: false),
            .demo,
            .unlock,
            .authenticated
        ]

        // If this compiles, all states exist
        #expect(true)
    }

    // MARK: - Account Exists Confirmation Tests

    @Test
    func accountExistsConfirmationStatesWithSameValuesAreEqual() {
        let loginResult = OpaqueLoginResult(
            exportKey: Data(repeating: 0x42, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        let state1 = AuthenticationFlowState.accountExistsConfirmation(
            username: "testuser",
            loginResult: loginResult,
            enableBiometric: false
        )
        let state2 = AuthenticationFlowState.accountExistsConfirmation(
            username: "testuser",
            loginResult: loginResult,
            enableBiometric: false
        )
        #expect(state1 == state2)
    }

    @Test
    func accountExistsConfirmationStatesWithDifferentUsernamesAreNotEqual() {
        let loginResult = OpaqueLoginResult(
            exportKey: Data(repeating: 0x42, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        let state1 = AuthenticationFlowState.accountExistsConfirmation(
            username: "user1",
            loginResult: loginResult,
            enableBiometric: false
        )
        let state2 = AuthenticationFlowState.accountExistsConfirmation(
            username: "user2",
            loginResult: loginResult,
            enableBiometric: false
        )
        #expect(state1 != state2)
    }

    @Test
    func accountExistsConfirmationStatesWithDifferentBiometricAreNotEqual() {
        let loginResult = OpaqueLoginResult(
            exportKey: Data(repeating: 0x42, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        let state1 = AuthenticationFlowState.accountExistsConfirmation(
            username: "testuser",
            loginResult: loginResult,
            enableBiometric: true
        )
        let state2 = AuthenticationFlowState.accountExistsConfirmation(
            username: "testuser",
            loginResult: loginResult,
            enableBiometric: false
        )
        #expect(state1 != state2)
    }

    // MARK: - Demo Mode Tests

    @Test
    func demoStateExists() {
        let state = AuthenticationFlowState.demo
        #expect(state == .demo)
    }

    @Test
    func demoStateIsDistinctFromOtherStates() {
        let demoState = AuthenticationFlowState.demo
        let welcomeState = AuthenticationFlowState.welcome
        let authenticatedState = AuthenticationFlowState.authenticated

        #expect(demoState != welcomeState)
        #expect(demoState != authenticatedState)
    }
}
