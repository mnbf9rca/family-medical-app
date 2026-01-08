# Test Helpers

Shared test fixtures and utilities to reduce duplication across test files.

## Available Helpers

| Helper | Purpose |
|--------|---------|
| `AttachmentTestHelper` | Create test images and Attachment model instances |
| `AttachmentServiceTestFixtures` | Complete AttachmentService mock setup with all dependencies |
| `PersonTestHelper` | Create test Person model instances |
| `ExampleSchema` | Comprehensive RecordSchema exercising all field types |
| `BindingTestHarness` | Test two-way SwiftUI bindings with ViewInspector |

## Usage Examples

### AttachmentTestHelper

```swift
// Create a test UIImage
let image = AttachmentTestHelper.makeTestImage(size: CGSize(width: 100, height: 100))

// Create an Attachment with random HMAC (for tests that don't compare HMACs)
let attachment = try AttachmentTestHelper.makeTestAttachment(
    fileName: "photo.jpg",
    mimeType: "image/jpeg"
)

// Create an Attachment with deterministic HMAC (for tests that compare equality)
let deterministicAttachment = try AttachmentTestHelper.makeTestAttachmentDeterministic(
    id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
    hmacByte: 0xAB
)
```

### AttachmentServiceTestFixtures

```swift
// Create a fully configured fixture with mocked dependencies
let fixtures = AttachmentServiceTestFixtures.make()

// Use the service
let attachment = try await fixtures.service.addAttachment(
    fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
)

// Verify mock interactions
#expect(fixtures.repository.saveCalls.count == 1)
#expect(fixtures.fileStorage.storeCalls.count == 1)

// Access test keys
let primaryKey = fixtures.primaryKey
let fmk = fixtures.fmk

// Create test data
let jpegData = AttachmentServiceTestFixtures.makeTestJPEGData(seed: 0)
let pdfData = AttachmentServiceTestFixtures.makeTestPDFData()
```

### PersonTestHelper

```swift
// Create a Person with defaults (uses random Date() for dateOfBirth)
let person = try PersonTestHelper.makeTestPerson(name: "John Doe")

// Create a Person with deterministic values (fixed timestamp)
let deterministicPerson = try PersonTestHelper.makeTestPersonDeterministic(
    id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
    name: "Jane Doe",
    dateOfBirthTimestamp: 631_152_000  // 1990-01-01
)
```

### ExampleSchema

```swift
// Get a comprehensive schema with all field types
let schema = ExampleSchema.comprehensive

// Schema includes fields of every type:
// - string, int, double, bool, date, stringArray, attachmentIds
// Use for validation testing, form rendering tests, etc.
```

### BindingTestHarness

```swift
// Test two-way bindings in SwiftUI views
@MainActor
@Test
func testBindingUpdatesViewModel() throws {
    var boundValue = "initial"
    let harness = BindingTestHarness(value: boundValue) { newValue in
        boundValue = newValue
    }

    let view = MyView(text: harness.binding)
    // ... use ViewInspector to modify the binding

    #expect(boundValue == "updated")
}
```

## Adding New Helpers

When creating new test helpers:

1. **Place in this directory** - Keep all shared helpers together
2. **Use descriptive names** - `{Model}TestHelper` or `{Service}TestFixtures`
3. **Provide both random and deterministic variants** - Random for most tests, deterministic for equality comparisons
4. **Document usage** - Update this README with examples

## Related Documentation

- [Testing Patterns](../../../docs/testing-patterns.md) - Comprehensive testing guide
- [ADR-0010](../../../docs/adr/adr-0010-deterministic-testing-architecture.md) - Deterministic testing architecture
