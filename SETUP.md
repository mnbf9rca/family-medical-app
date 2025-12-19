# Development Environment Setup

Guide for setting up iOS development environment on macOS (M4 Mac).

## Prerequisites

### Required
- **macOS**: Sonoma (14.0) or later
- **Xcode**: 15.0+ (free from App Store)
  - Includes Swift compiler, iOS Simulator, and all iOS SDKs
  - Large download (~7-15 GB), takes time to install
- **Apple ID**: Free (required for Xcode and running on simulator)

### Optional but Recommended
- **Homebrew**: Package manager for macOS
- **Git**: Already installed on macOS, but Homebrew version is newer

## Installation Steps

### 1. Install Xcode
```bash
# Open Mac App Store
open "macstore://apps.apple.com/app/xcode/id497799835"

# Or search "Xcode" in App Store and install
```

After installation:
```bash
# Accept Xcode license
sudo xcodebuild -license accept

# Install additional components (simulators, command line tools)
xcode-select --install

# Verify installation
xcode-select -p
# Should output: /Applications/Xcode.app/Contents/Developer

swift --version
# Should show Swift 5.9+
```

### 2. Install Homebrew (Optional)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3. Install Development Tools (Optional)
```bash
# SwiftLint: Linting and style checking
brew install swiftlint

# SwiftFormat: Code formatting
brew install swiftformat

# gh: GitHub CLI (if not already installed)
brew install gh
```

## Project Setup

Once environment is ready, create the Xcode project:

```bash
# Create Xcode project (will be done in issue #3)
# For now, this repo just has planning documents
```

## iOS Development Crash Course (for Python/React developers)

### Key Differences from Web Development

| Concept | React/Web | iOS/SwiftUI |
|---------|-----------|-------------|
| **Language** | JavaScript/TypeScript | Swift |
| **UI Framework** | React components | SwiftUI Views |
| **State Management** | useState, Redux | @State, @Binding, @ObservedObject |
| **Styling** | CSS, CSS-in-JS | SwiftUI modifiers (built-in) |
| **Navigation** | React Router | NavigationStack/NavigationLink |
| **IDE** | VS Code, WebStorm | Xcode (required) |
| **Package Manager** | npm/yarn | Swift Package Manager (SPM) |
| **Testing** | Jest, React Testing Library | XCTest |
| **Build** | webpack/vite | Xcode Build System |

### Swift Basics (if you know Python)

```swift
// Variables (like Python, but type-safe)
var mutableValue = "hello"        // var (like let in JS)
let constantValue = "world"       // let (immutable, like const in JS)

// Types (usually inferred, can be explicit)
let name: String = "Alice"
let age: Int = 30
let height: Double = 5.9

// Optionals (handles None/null safely)
var optionalName: String? = nil   // Like Python's None
if let name = optionalName {       // Safe unwrapping
    print(name)
}

// Functions
func greet(name: String) -> String {
    return "Hello, \(name)"       // String interpolation
}

// Classes and Structs (structs are preferred in Swift)
struct Person {
    let name: String
    var age: Int

    func greet() -> String {
        "Hi, I'm \(name)"
    }
}

// Arrays and Dictionaries
let names = ["Alice", "Bob"]      // Array
let ages = ["Alice": 30, "Bob": 25]  // Dictionary

// Closures (like lambda in Python, arrow functions in JS)
let doubled = [1, 2, 3].map { $0 * 2 }
```

### SwiftUI Basics (if you know React)

```swift
// React Component
function Greeting({ name }) {
    const [count, setCount] = useState(0);

    return (
        <div>
            <h1>Hello, {name}!</h1>
            <button onClick={() => setCount(count + 1)}>
                Clicked {count} times
            </button>
        </div>
    );
}

// SwiftUI View (equivalent)
struct Greeting: View {
    let name: String
    @State private var count = 0

    var body: some View {
        VStack {
            Text("Hello, \(name)!")
                .font(.title)
            Button("Clicked \(count) times") {
                count += 1
            }
        }
    }
}
```

### Key SwiftUI Concepts

**Declarative UI** (just like React):
```swift
VStack {              // Vertical stack (like flexbox column)
    Text("Title")
    Image("icon")
    Button("Click") { action() }
}
```

**State Management**:
```swift
@State var name = ""           // Local state (like useState)
@Binding var name: String      // Passed from parent (like props with setter)
@ObservedObject var model      // Observable object (like Redux/Context)
```

**Modifiers** (like CSS but chained):
```swift
Text("Hello")
    .font(.title)
    .foregroundColor(.blue)
    .padding()
    .background(Color.gray)
```

## Learning Resources

### Before Starting Development
Recommended Swift/SwiftUI tutorials (1-2 hours total):

1. **Swift Basics** (if new to Swift):
   - [Swift in 100 Minutes](https://www.hackingwithswift.com/100/swiftui) (free)
   - [Swift Tour](https://docs.swift.org/swift-book/GuidedTour/GuidedTour.html) (official)

2. **SwiftUI Fundamentals**:
   - [Apple's SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui) (official, hands-on)
   - [100 Days of SwiftUI](https://www.hackingwithswift.com/100/swiftui) (comprehensive, free)

3. **iOS Development Concepts**:
   - Xcode basics (project structure, simulator, debugging)
   - iOS app lifecycle
   - SwiftUI preview canvas (live preview while coding)

### Reference
- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios)

## Xcode Tips

### Shortcuts (similar to VS Code)
- `⌘ + B`: Build project
- `⌘ + R`: Build and run in simulator
- `⌘ + .`: Stop running app
- `⌘ + Shift + O`: Open quickly (file search)
- `⌘ + Click`: Jump to definition
- `⌘ + Option + [`: Move line up
- `⌘ + /`: Comment/uncomment

### Live Preview
- Canvas on the right shows live preview of SwiftUI views
- `⌘ + Option + P`: Resume preview
- `⌘ + Option + Enter`: Toggle canvas

### Simulator
- iOS Simulator runs on your Mac (no device needed for development)
- Test different iPhone/iPad models
- Simulate Face ID, location, etc.

## Backend Development (Phase 2)

When we reach Phase 2 (sync backend), we'll add:
- **Devcontainer** for backend API (Python FastAPI likely)
- **Docker Compose** for local database
- Backend can be developed in VS Code while iOS in Xcode

Configuration will be added in Phase 2 issues.

## Verification

Check your setup:
```bash
# Xcode installed and licensed
xcodebuild -version
# Should show: Xcode 15.x

# Swift compiler works
swift --version
# Should show: Swift 5.9+

# Optional tools
swiftlint version
gh --version
```

## Troubleshooting

### "xcode-select: error: tool 'xcodebuild' requires Xcode"
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Simulator won't launch
```bash
# Reset simulator
xcrun simctl erase all
```

### Xcode acting weird
```bash
# Clear derived data (like node_modules or __pycache__)
rm -rf ~/Library/Developer/Xcode/DerivedData
```

## Next Steps

1. Complete Xcode installation
2. Review Swift/SwiftUI basics (1-2 hours recommended)
3. Start with Issue #3 (Set up iOS project)
4. Follow along with issues #4-12 for Phase 1 implementation

## Python Background Notes

Coming from Python, you'll find:
- ✅ **Swift is more familiar than you think**: Clean syntax, type inference, first-class functions
- ✅ **No manual memory management**: Like Python (ARC handles it)
- ✅ **Strong typing catches bugs early**: More like TypeScript than JavaScript
- ⚠️ **Xcode learning curve**: Different from VS Code/PyCharm, but powerful
- ⚠️ **Compiled language**: No REPL-style development (but Swift Playgrounds exist)

## React Background Notes

Coming from React:
- ✅ **SwiftUI is very similar**: Declarative, component-based, state-driven
- ✅ **No separate styling**: Modifiers replace CSS
- ✅ **Type-safe props**: Function parameters instead of PropTypes
- ⚠️ **No npm/webpack**: Swift Package Manager is simpler
- ⚠️ **Different state management**: No Redux needed initially (@State is sufficient)

---

Questions? Open an issue or check Apple's documentation.
