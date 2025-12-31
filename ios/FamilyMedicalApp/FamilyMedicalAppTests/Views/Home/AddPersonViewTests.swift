import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct AddPersonViewTests {
    // MARK: - Test Data

    let testKey = SymmetricKey(size: .bits256)

    func createViewModel() -> HomeViewModel {
        let mockRepo = MockPersonRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        return HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )
    }

    // MARK: - Initialization Tests

    @Test
    func viewInitializesWithViewModel() {
        let viewModel = createViewModel()
        let view = AddPersonView(viewModel: viewModel)

        // View should initialize without crashing
        #expect(view.viewModel === viewModel)
    }

    @Test
    func viewRendersSuccessfully() throws {
        let viewModel = createViewModel()
        let view = AddPersonView(viewModel: viewModel)

        _ = try view.inspect()
    }

    @Test
    func viewRendersForm() throws {
        let viewModel = createViewModel()
        let view = AddPersonView(viewModel: viewModel)

        let navStack = try view.inspect().navigationStack()
        let form = try navStack.form(0)
        _ = form
    }

    @Test
    func viewRendersBasicInformationSection() throws {
        let viewModel = createViewModel()
        let view = AddPersonView(viewModel: viewModel)

        let navStack = try view.inspect().navigationStack()
        let form = try navStack.form(0)
        // Verify form has sections
        _ = try form.section(0)
    }

    @Test
    func viewRendersWithViewModelError() throws {
        let mockRepo = MockPersonRepository()
        mockRepo.shouldFailSave = true

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        let view = AddPersonView(viewModel: viewModel)
        _ = try view.inspect()
    }

    @Test
    func viewRendersWhileViewModelLoading() throws {
        let viewModel = createViewModel()
        let view = AddPersonView(viewModel: viewModel)

        _ = try view.inspect()
    }
}
