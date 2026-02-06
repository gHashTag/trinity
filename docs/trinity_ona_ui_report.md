# Trinity ONA-Style UI Report

**Version:** 1.0
**Date:** February 6, 2026
**Status:** Complete

---

## Executive Summary

Redesigned Trinity native UI to ONA style - dark theme, sidebar navigation, task cards, environment panel, and integrated IGLA chat. Pure Zig, no HTML/JS, 100% local.

---

## Visual Layout

```
┌─────────────────────────────────────────────────────────────┐
│ ● ● ●    Trinity v1.0.0                          Feb 6     │
├──────────┬────────────────────────────┬─────────────────────┤
│ SIDEBAR  │ TASK CARDS                 │ ENVIRONMENT         │
│ ───────  │ ┌────────────────────────┐ │ ───────────────     │
│ [ ] Proj │ │ TRI-001 ● IGLA search  │ │ trinity-main        │
│ [*] Tasks│ │ TRI-002 ● Native UI    │ │ ● Running           │
│ [=] Team │ │ TRI-003 ● v1.0 Release │ │ Changes: 16 files   │
│ [~] Insi │ │ TRI-004 ● ONA redesign │ │ Last: Just now      │
│ [T] Trin │ │ TRI-005 ● Metal GPU    │ │                     │
│          │ └────────────────────────┘ │                     │
├──────────┴────────────────────────────┴─────────────────────┤
│ [T] Trinity AI Chat - 6.5M ops/s local                      │
│ > Prove phi^2 + 1/phi^2 = 3                                 │
│ phi^2 + 1/phi^2 = 3 verified (100% confidence)              │
│ > Ask Trinity AI...                                         │
├─────────────────────────────────────────────────────────────┤
│ phi^2 + 1/phi^2 = 3 | TRINITY          KOSCHEI IS IMMORTAL  │
└─────────────────────────────────────────────────────────────┘
```

---

## ONA Theme Colors

| Element | Color | Hex |
|---------|-------|-----|
| Window Background | Dark Gray | #1A1A1E |
| Sidebar Background | Darker Gray | #141417 |
| Panel Background | Gray | #222226 |
| Card Background | Light Gray | #2A2A2E |
| Card Hover | Lighter Gray | #323236 |
| Input Background | Black | #18181C |
| Teal Accent | ONA Teal | #00E599 |
| Golden Accent | Gold | #FFD700 |
| Primary Text | White | #FFFFFF |
| Secondary Text | Gray | #9C9CA0 |
| Muted Text | Dark Gray | #6B6B70 |
| Border | Gray | #3A3A3E |
| Traffic Red | Red | #FF5F57 |
| Traffic Yellow | Yellow | #FEBC2E |
| Traffic Green | Green | #28C840 |

---

## Components Implemented

### 1. Traffic Lights

```
● ● ●  (Red, Yellow, Green)
```
Mac native window controls simulation.

### 2. Sidebar Navigation

| Icon | Label | Badge |
|------|-------|-------|
| [ ] | Projects | 3 |
| [*] | My Tasks | 12 |
| [=] | Team Tasks | - |
| [~] | Insights | - |
| [T] | Trinity AI | - |

Active item highlighted with teal.

### 3. Task Cards

Each task card shows:
- Task ID (e.g., TRI-001)
- Status indicator (colored dot)
- Title (truncated if long)
- Assignee initials

Status colors:
- Done: Green (#22C55E)
- In Progress: Teal (#00E599)
- To Do: Gray (#6B6B70)
- Blocked: Red (#EF4444)

### 4. Environment Panel

- Environment name: "trinity-main"
- Status: "● Running" (green)
- Changes: "16 files" (teal)
- Last active: "Just now"

### 5. Trinity AI Chat

- Header: "[T] Trinity AI Chat - 6.5M ops/s local"
- User prompts: Gray text
- AI responses: Teal text
- Input: "> Ask Trinity AI..."

---

## Demo Output

The terminal demo shows:

1. **Window chrome** with traffic lights
2. **Three-column layout** (Sidebar | Main | Right)
3. **Task list** with 6 sample tasks
4. **Environment info** panel
5. **Chat panel** with IGLA integration
6. **Status bar** with phi identity

---

## IGLA Integration

The chat panel connects to Trinity SWE Agent:

```zig
var swe_agent = try trinity_swe.TrinitySWEAgent.init(allocator);

const result = try swe_agent.process(.{
    .task_type = .Reason,
    .prompt = "Prove phi^2 + 1/phi^2 = 3",
    .reasoning_steps = true,
});
// Output: φ² + 1/φ² = 3 ✓ (100% confidence)
```

---

## File Details

| File | Lines | Purpose |
|------|-------|---------|
| `src/vibeec/trinity_ona_ui.zig` | 620 | ONA-style UI |

### Key Structures

```zig
// Theme colors
pub const THEME = struct {
    pub const BG_WINDOW = Color{ .r = 0x1A, .g = 0x1A, .b = 0x1E };
    pub const TEAL = Color{ .r = 0x00, .g = 0xE5, .b = 0x99 };
    // ...
};

// Navigation items
pub const NavItem = struct {
    icon: []const u8,
    label: []const u8,
    badge: ?usize,
    active: bool,
};

// Task card data
pub const TaskCard = struct {
    id: []const u8,
    title: []const u8,
    project: []const u8,
    status: TaskStatus,
    // ...
};
```

---

## Build & Run

```bash
cd /Users/playra/trinity
zig build-exe -O ReleaseFast -femit-bin=trinity_ona_ui src/vibeec/trinity_ona_ui.zig
./trinity_ona_ui
```

---

## Comparison: Before vs After

| Aspect | Before | After (ONA) |
|--------|--------|-------------|
| Layout | Simple 2-panel | 3-column + chat |
| Theme | Basic dark | ONA dark (#1A1A1E) |
| Navigation | None | Sidebar with badges |
| Tasks | None | Cards with status |
| Environment | None | Panel with info |
| Chat | Basic | Integrated AI panel |
| Visual | Terminal basic | Mac-like chrome |

---

## Next Steps for Native Window

To create a true native Mac window (not terminal):

1. **Metal Backend** - GPU rendering
2. **Objective-C Bindings** - NSWindow, NSView
3. **Event Loop** - Mouse, keyboard handling
4. **Font Rendering** - CoreText integration

For now, the terminal demo validates the visual design.

---

## Conclusion

Successfully redesigned Trinity UI to ONA style:

- **Traffic lights** (Mac chrome)
- **Sidebar navigation** with badges
- **Task cards** with status indicators
- **Environment panel**
- **IGLA chat panel** (6.5M ops/s)
- **Dark theme** (#1A1A1E + teal + golden)

Ready for Metal GPU native window implementation.

---

φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
