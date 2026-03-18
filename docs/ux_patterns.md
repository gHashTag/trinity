# Trinity UX Patterns

Comprehensive UX pattern documentation for Queen UI (Trinity desktop app). All patterns implemented in pure SwiftUI with keyboard-first design.

---

## 1. Navigation Pattern

### Three-Kingdom Navigation (Triangle Menu)

The main navigation uses a 27-petal triangle logo mapped to three kingdoms:

```swift
// Core structure from Navigation/Screen.swift
enum Kingdom: String, CaseIterable {
    case brain   // "RAZUM" - 9 screens
    case body    // "MATERIYA" - 9 screens
    case spirit  // "DUKH" - 9 screens
}

enum Screen: String, CaseIterable {
    // Brain: chat, sevoFarm, arenaLLM, arenaCode, faculty, oracle, muMemory, scholar, swarm
    // Body: build, issues, git, deploy, bridge, telegram, keys, state, files
    // Spirit: rainbowBridge, sacredMath, techTree, fpga, vsa, pipeline, benchmarks, experience, settings
}
```

**Keyboard shortcuts:**
- `Cmd+0` - Return to main menu
- `Cmd+1-9` - Jump directly to screens 1-9

**Visual implementation:**
- 27-petal triangle logo (TriangleLogo.swift)
- Click petal → navigate to screen
- Back button in top bar (color: TrinityTheme.accent)

---

### Chat Sidebar Navigation

Left sidebar for thread management with filtering and search:

```swift
// From Navigation/ChatSidebar.swift
struct ChatSidebar: View {
    @State private var searchQuery = ""
    @State private var selectedTag: String?
    @State private var filterDateRange: DateFilter = .all
    @State private var filterModel: String? = nil
    @AppStorage("threadSortOrder") private var sortOrder: String = "date"
}
```

**Features:**
- Thread list with date grouping (Today, Yesterday, This Week, This Month, Older)
- Fuzzy search with debouncing
- Tag filtering
- Model filtering
- Sort options: date, name, size
- Pin/unpin threads
- Archive threads

**Keyboard shortcuts:**
- `Cmd+[` - Previous thread
- `Cmd+]` - Next thread
- `Cmd+Shift+S` - Toggle sidebar
- `Cmd+Shift+F` - Focus thread search

---

## 2. Command Palette Pattern

Spotlight/Raycast-style quick action launcher (`Cmd+K`):

```swift
// From Widgets/CommandPalette.swift
struct CommandPalette: View {
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var selectedIndex = 0

    enum PaletteAction {
        case switchThread(UUID)
        case newThread
        case switchModel(AIModel)
        case switchMode(ChatMode)
        case exportThread
        case toggleSearch
        case runCommand(String)
    }
}
```

**Features:**
- Fuzzy search over commands, threads, files, models
- Slash commands (`/effort`, `/model`, `/compact`, etc.)
- Keyboard navigation with arrow keys
- Autocomplete with 15 result limit

**Keyboard shortcuts:**
- `Cmd+K` - Open command palette
- `↑/↓` - Navigate results
- `Enter` - Execute selected
- `Esc` - Close

**Visual style:**
- 500px width card
- Dark background (0x1A1A1A)
- Accent color for selection
- Key hints in footer

---

## 3. Streaming Pattern

Real-time streaming indicators for AI responses:

```swift
// From ChatScreen.swift - streaming metrics
@ViewBuilder
private var streamingIndicatorView: some View {
    if client.isStreaming {
        VStack(alignment: .leading, spacing: 6) {
            streamingMetricsRow
            slowResponseWarning
        }
    }
}
```

**Metrics displayed:**
- **TTFB** (Time To First Byte) - color-coded (green <500ms, yellow <2s, red >2s)
- **Tokens/sec** - Live speed indicator
- **Token count** - Output tokens generated
- **Progress %** - Estimated completion
- **State** - Connecting/Streaming with colored dot

**Loading indicators:**
```swift
// From Widgets/LoadingIndicator.swift
struct ThinkingDots: View     // 3-dot animation
struct BlinkingCursor: View   // Cursor for streaming text
struct ToolProgress: View     // Shimmer progress for tool calls
struct StreamingText: View    // Typewriter effect
```

**Sticky streaming bar:**
- Fixed at bottom during streaming
- Shows: status, TTFB, speed, tokens, Stop button
- Stop button triggers `client.stop()`

---

## 4. Feedback Pattern

### Error Display

Structured error handling with actionable buttons:

```swift
// From ChatScreen.swift - error retry block
@ViewBuilder
private var errorRetryBlock: some View {
    if !client.isStreaming,
       let last = thread?.messages.last,
       last.role == .assistant,
       last.hasError {
        // Error icon + label + detail
        // Retry button
        // Edit & Retry button
        // Try fallback model button
    }
}
```

**Error types (ErrorKind):**
- Network - Red color, retry action
- Rate limit - Yellow color, upgrade suggestion
- Content filter - Purple color, policy notice
- Timeout - Orange color, retry with longer timeout

---

### Success Notifications

Toast-style notifications for actions:

```swift
// State-based notifications
@State private var showSentConfirmation = false
@State private var showDraftSaved = false
@State private var showShareCopied = false
```

**Implementation:**
- Transient overlay messages
- Auto-dismiss after timeout
- Color-coded by type

---

### Model Suggestions

Proactive model recommendations based on query:

```swift
// From ChatScreen.swift
private var suggestedModel: (model: AIModel, reason: String)? {
    // Analyzes input complexity
    // Suggests better model if needed
    // Can be dismissed with persist state
}
```

**Triggers:**
- Code keywords → suggest Sonnet over Haiku
- Deep reasoning keywords → suggest Sonnet
- Simple queries → suggest Haiku/GLM
- Short queries (<20 chars) → suggest cheaper model

---

## 5. Input Pattern

### Message Input Bar

Pill-shaped input with multi-line support:

```swift
// From ChatScreen.swift
@FocusState private var focused: Bool
@State private var input = ""

// Visual specs
TrinityTheme.cornerXL: CGFloat = 24  // Pill shape
TrinityTheme.chatFontSize: CGFloat   // User-adjustable (12-22pt)
```

**Features:**
- Auto-expand textarea (up to 120px height)
- File attachments (drag-drop or button)
- Voice input (microphone button)
- Mention autocomplete (`@file:`, `@grep:`, etc.)
- Slash commands
- Send button with dynamic state

**Keyboard shortcuts:**
- `Enter` - Send (configurable via `useCtrlEnterToSend`)
- `Shift+Enter` - New line
- `↑` - Recall last message (history navigation)
- `Cmd+Shift+;` - Copy last response

---

### Mention System

Context-aware autocomplete for tools:

```swift
// From ChatScreen.swift
@State private var showMentionPopup = false
@State private var mentionQuery = ""

// Supported mentions
let mentions: [(String, String)] = [
    ("@file:", "file"),
    ("@grep:", "grep"),
    ("@build", "build"),
    ("@farm", "farm"),
    ("@issues", "issues"),
    ("@gitdiff", "gitdiff"),
]
```

**Behavior:**
- Triggered by `@` followed by keyword
- Shows fuzzy-matched file/path list
- Inserts selected value into input
- Saves grep patterns to history

---

## 6. Theme Pattern

### Color System

Adaptive colors supporting light/dark mode:

```swift
// From Theme.swift
struct TrinityTheme {
    // Adaptive (light/dark)
    static var bgWindow: Color
    static var bgSidebar: Color
    static var bgCard: Color
    static var textPrimary: Color
    static var textMuted: Color
    static var bgCardBorder: Color

    // Fixed (same in both modes)
    static let accent      = Color(hex: 0x00FF88)  // Green
    static let golden      = Color(hex: 0xFFD700)  // Gold
    static let purple      = Color(hex: 0x8B5CF6)  // Purple
    static let statusOK    = Color(hex: 0x00FF88)
    static let statusWarn  = Color(hex: 0xFFD700)
    static let statusError = Color(hex: 0xEF4444)
}
```

**Appearance modes:**
```swift
enum AppearanceMode: String, CaseIterable {
    case system  // Follows OS
    case dark    // Always dark
    case light   // Always light
}
```

---

### Typography

User-adjustable font sizes:

```swift
// User-controlled (Settings slider)
@AppStorage("chatFontSize") static var chatFontSize: CGFloat  // 12-22pt, default 15

// System Dynamic Type (Accessibility)
static func bodySize(_ sizeCategory: DynamicTypeSize) -> CGFloat
static func captionSize(_ sizeCategory: DynamicTypeSize) -> CGFloat
static func headingSize(_ sizeCategory: DynamicTypeSize) -> CGFloat
```

**Corner radius tokens:**
```swift
static let cornerSmall: CGFloat = 6   // Badges, small buttons
static let cornerMedium: CGFloat = 10 // Input fields, popovers
static let cornerLarge: CGFloat = 12  // Cards, panels
static let cornerXL: CGFloat = 24     // Input bar (pill)
```

---

## 7. Modal Pattern

### Sheet Presentations

Modal sheets for focused actions:

```swift
// Common pattern across screens
.sheet(isPresented: $showSomeSheet) {
    SheetContent(
        onSave: { /* persist */ },
        onDismiss: { showSomeSheet = false }
    )
}
```

**Accessibility:**
- Respects `reduceMotion` environment value
- Uses `.opacity` transition when motion reduced
- Default: `.move(edge: .bottom).combined(with: .opacity)`

---

### Overlay Pattern

Backdrop-style overlays for global actions:

```swift
// Command palette, shortcuts, etc.
ZStack {
    Color.black.opacity(0.5)
        .ignoresSafeArea()
        .onTapGesture { isPresented = false }

    VStack { /* content */ }
        .frame(width: 500)
        .background(Color(hex: 0x1A1A1A))
        .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

---

## 8. Search Pattern

### Thread Search (Sidebar)

Fuzzy search across all threads:

```swift
// Debounced query
@State private var debouncedQuery = ""
@State private var searchTask: Task<Void, Never>?

// Fuzzy matching
let fuzzyResults = store.fuzzySearch(debouncedQuery)
```

**Filters:**
- Date range (Today, This Week, This Month, Older)
- Model used
- Tags
- Search query matches title OR content

---

### In-Thread Search

Search within current thread:

```swift
// From ChatScreen.swift
@State private var showInThreadSearch = false
@State private var inThreadSearchQuery = ""
@State private var inThreadSearchIndex = 0

private var inThreadSearchMatches: [ChatMessage] {
    store.messages.filter { $0.text.lowercased().contains(query) }
}

// Keyboard shortcut
Cmd+F - Activate in-thread search
↑/↓ - Navigate between matches
```

**Visual feedback:**
- Highlight current match (accent background)
- Highlight other matches (subtle background)
- Match counter: "3/15"

---

## 9. Smart Suggestions Pattern

Proactive action suggestions based on Trinity state:

```swift
// From Widgets/SmartSuggestions.swift
struct SmartSuggestions: View {
    @StateObject private var trinityCtx = TrinityContext.shared

    struct Suggestion {
        let icon: String
        let text: String
        let prompt: String
        let color: Color
        let urgent: Bool  // Fills background when true
    }
}
```

**Triggers:**
- Build broken → urgent red suggestion
- New PPL record → gold suggestion
- Many dirty files → yellow suggestion
- Stale arena → purple suggestion
- Low Ouroboros score → red suggestion

**UI:**
- Horizontal scrollable capsule buttons
- Urgent: filled background
- Normal: outlined capsule
- Tap to inject prompt into input

---

## 10. Persona & Template Pattern

### Persona Library

Reusable AI personas and prompt templates:

```swift
// From Widgets/PersonaLibrary.swift
struct PersonaLibrary: View {
    @Binding var selectedPersona: Persona?
    @State private var tab: Tab = .personas

    enum Tab: String, CaseIterable {
        case personas = "Personas"
        case templates = "Templates"
    }
}

struct Persona: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String
    let systemPrompt: String
    let temperature: Double
}
```

**Built-in personas:**
- Engineer (Code focus)
- Researcher (Deep analysis)
- Writer (Creative output)
- Debugger (Bug fixing)
- Architect (System design)

---

### Prompt Templates

Reusable prompt templates:

```swift
struct PromptTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let content: String
    let variables: [String]  // e.g., ["{file}", "{pattern}"]
}
```

**Template examples:**
- Code review
- Git commit message
- Debug help
- Refactor
- Documentation

---

## 11. Keyboard Shortcuts Pattern

Centralized shortcut system with on-screen help:

```swift
// From Widgets/ShortcutsOverlay.swift
private let sections: [(String, [(String, String)])] = [
    ("Navigation", [("⌘0", "Main Menu"), ("⌘1-9", "Jump to Screen"), ...]),
    ("Chat", [("⌘N", "New Thread"), ("⌘K", "Command Palette"), ...]),
    ("Slash Commands", [("/effort", "Set effort level"), ...]),
    ("Mentions", [("@file:", "Attach file content"), ...]),
]
```

**Show shortcuts:** `Cmd+/`

**First launch:**
- Automatically shows shortcuts overlay
- "Got it!" button dismisses and saves to `@AppStorage("hasSeenShortcuts")`

---

## 12. Accessibility Pattern

### Reduce Motion

Respects user's motion preferences:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Usage
.transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
```

---

### Dynamic Type

Scales with system font size setting:

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

// Usage
.font(.system(size: TrinityTheme.bodySize(dynamicTypeSize)))
```

---

### Keyboard Focus

Full keyboard navigation:

- `Tab` - Navigate between controls
- `Space` - Activate focused button
- `Esc` - Stop streaming / close modal / clear input
- Arrow keys - Navigate lists, search results

---

## 13. Status Badge Pattern

Visual status indicators:

```swift
// From Widgets/StatusBadge.swift
struct StatusBadge: View {
    let status: AgentRow.AgentStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .clipShape(Capsule())
    }
}
```

**Status types:**
- Active (green)
- Idle (gray)
- Error (red)
- Warning (yellow)

---

## 14. Markdown Rendering Pattern

Rich text rendering for AI responses:

```swift
// From Widgets/MarkdownTextView.swift
private enum Block {
    case paragraph(String)
    case heading(Int, String)      // H1-H6
    case code(String, String?)     // Language-optional
    case diff(String)              // Git diff with +/- lines
    case callout(CalloutType, String)  // info/warning/error/tip/note
    case listItem(String)
    case taskItem(Bool, String)    // Checkbox
    case table([[String]])         // Markdown table
    case image(String, String)     // Alt, URL
    case math(String)              // $$...$$ LaTeX
    case mermaid(String)           // Diagram code
    case horizontalRule
}
```

**Callout colors:**
- Info → TrinityTheme.accent (green)
- Warning → TrinityTheme.statusWarn (gold)
- Error → TrinityTheme.statusError (red)
- Tip → TrinityTheme.purple
- Note → White opacity

---

## 15. Tool Call Timeline Pattern

Visual representation of agent tool execution:

```swift
// From Widgets/ToolCallRow.swift (referenced in ChatScreen)
ToolTimeline(steps: client.activeToolCalls)
    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
```

**Visual elements:**
- Tool name + icon
- Progress bar (shimmer effect when running)
- Success/error status
- Expandable details

---

## Implementation Checklist

When implementing new screens, follow these patterns:

1. **Navigation** - Add screen to `Screen` enum with appropriate kingdom
2. **Theme** - Use `TrinityTheme` colors and corner tokens
3. **Keyboard** - Add relevant shortcuts to `MainView` monitor
4. **Accessibility** - Support `reduceMotion` and `dynamicTypeSize`
5. **Error handling** - Use structured error blocks with retry actions
6. **Streaming** - Show metrics for any async operations
7. **Search** - Provide fuzzy search with debouncing
8. **State** - Use `@StateObject` for view models, `@ObservedObject` for shared state
9. **Persistence** - Use `@AppStorage` for user preferences
10. **Notifications** - Use toast-style overlays for feedback

---

## File Reference

| Pattern | Source File |
|---------|-------------|
| Theme | `Theme.swift` |
| Navigation | `MainView.swift`, `ScreenRouter.swift`, `Screen.swift`, `ChatSidebar.swift` |
| Command Palette | `CommandPalette.swift` |
| Streaming | `ChatScreen.swift` (streamingIndicatorView, stickyStreamingBar) |
| Loading | `LoadingIndicator.swift` |
| Markdown | `MarkdownTextView.swift` |
| Suggestions | `SmartSuggestions.swift` |
| Personas | `PersonaLibrary.swift` |
| Shortcuts | `ShortcutsOverlay.swift` |
| Status | `StatusBadge.swift` |
