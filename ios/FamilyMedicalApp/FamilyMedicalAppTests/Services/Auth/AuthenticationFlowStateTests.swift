import Testing
@testable import FamilyMedicalApp

struct AuthenticationFlowStateTests {
    // MARK: - State Distinctness

    @Test
    func newUserFlowStatesAreDistinct() {
        let states: [AuthenticationFlowState] = [
            .usernameEntry,
            .passphraseCreation(username: "testuser"),
            .passphraseConfirmation(username: "testuser", passphrase: "test"),
            .biometricSetup(username: "testuser", passphrase: "test")
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
        let state1 = AuthenticationFlowState.usernameEntry
        let state2 = AuthenticationFlowState.usernameEntry
        #expect(state1 == state2)
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
        let _: [AuthenticationFlowState] = [
            .usernameEntry,
            .passphraseCreation(username: "testuser"),
            .passphraseConfirmation(username: "testuser", passphrase: "pass"),
            .passphraseEntry(username: "testuser", isReturningUser: true),
            .biometricSetup(username: "testuser", passphrase: "pass"),
            .unlock,
            .authenticated
        ]

        // If this compiles, all states exist
        #expect(true)
    }
}
