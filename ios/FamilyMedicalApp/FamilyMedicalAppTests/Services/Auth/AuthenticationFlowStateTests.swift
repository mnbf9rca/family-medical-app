import Testing
@testable import FamilyMedicalApp

struct AuthenticationFlowStateTests {
    // MARK: - State Distinctness

    @Test
    func newUserFlowStatesAreDistinct() {
        let states: [AuthenticationFlowState] = [
            .emailEntry,
            .codeVerification(email: "test@example.com"),
            .passphraseCreation(email: "test@example.com"),
            .passphraseConfirmation(email: "test@example.com", passphrase: "test"),
            .biometricSetup(email: "test@example.com", passphrase: "test")
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
        let returningState = AuthenticationFlowState.passphraseEntry(email: "test@example.com", isReturningUser: true)
        let newUserState = AuthenticationFlowState.passphraseCreation(email: "test@example.com")

        #expect(returningState != newUserState)
    }

    // MARK: - Equatable Conformance

    @Test
    func sameStatesAreEqual() {
        let state1 = AuthenticationFlowState.emailEntry
        let state2 = AuthenticationFlowState.emailEntry
        #expect(state1 == state2)
    }

    @Test
    func statesWithSameAssociatedValuesAreEqual() {
        let state1 = AuthenticationFlowState.codeVerification(email: "user@example.com")
        let state2 = AuthenticationFlowState.codeVerification(email: "user@example.com")
        #expect(state1 == state2)
    }

    @Test
    func statesWithDifferentAssociatedValuesAreNotEqual() {
        let state1 = AuthenticationFlowState.codeVerification(email: "user1@example.com")
        let state2 = AuthenticationFlowState.codeVerification(email: "user2@example.com")
        #expect(state1 != state2)
    }

    // MARK: - All States Exist

    @Test
    func allExpectedStatesExist() {
        // Verify all states can be instantiated (compile-time check via usage)
        let _: [AuthenticationFlowState] = [
            .emailEntry,
            .codeVerification(email: "test@example.com"),
            .passphraseCreation(email: "test@example.com"),
            .passphraseConfirmation(email: "test@example.com", passphrase: "pass"),
            .passphraseEntry(email: "test@example.com", isReturningUser: true),
            .biometricSetup(email: "test@example.com", passphrase: "pass"),
            .unlock,
            .authenticated
        ]

        // If this compiles, all states exist
        #expect(true)
    }
}
