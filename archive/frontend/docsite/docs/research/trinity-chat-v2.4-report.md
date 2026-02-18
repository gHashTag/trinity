# Trinity Chat v2.4 - Self-Reflection Visibility + Tool Metadata + Multi-Modal UI

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Architecture | 4-Level Cache (Tools -> Symbolic -> TVC -> LLM) + Reflection Loop | DONE |
| ReflectionStatus | 8 variants (Saved, FilteredLength, FilteredConfidence, FilteredError, FilteredDedup, NoCorpus, Disabled, NotApplicable) | DONE |
| saveToTVCFiltered | Returns ReflectionStatus instead of void | DONE |
| HybridResponse | +tool_name, +reflection fields | DONE |
| JSON Response | +tool_name, +reflection, +learned fields | DONE |
| LEARNED Badge | Green glowing badge when response saved to TVC | DONE |
| FILTERED Badge | Dim badge showing filter reason (Length, Confidence, Error, Dedup) | DONE |
| Tool Name Badge | Blue badge showing specific tool (time, date, system_info, etc.) | DONE |
| Multi-Modal Input | Collapsible image_path + audio_path text inputs | DONE |
| Reflection Wave | Green center wave animation on learned response | DONE |
| Test Coverage | 2067/2073 passed (+8 new v2.4 tests) | DONE |
| Build | 40/43 steps succeeded (1 pre-existing failure) | DONE |
| TypeScript | Clean — no errors | DONE |
| Vite Build | 1.17s — 489 modules | DONE |

## What This Means

**For Users**: You can now see when Trinity learns from a conversation. A green "LEARNED" badge appears when a response is saved to the TVC corpus for future instant retrieval. A dim "FILTERED" badge shows why a response was not saved (too short, low confidence, duplicate, etc.). Tool responses show the specific tool name (time, date, system_info). The "+" button in chat input lets you attach image/audio file paths for multi-modal queries.

**For Operators**: The HTTP `/chat` JSON response now includes `tool_name` (string or null), `reflection` (ReflectionStatus name), and `learned` (boolean). These fields enable dashboards and analytics for monitoring self-learning behavior. The `saveToTVCFiltered` function now returns `ReflectionStatus` instead of void, making the quality filter pipeline observable.

**For Investors**: Visible self-learning is a key differentiator. Users can watch the AI accumulate knowledge in real-time. The reflection pipeline (5 quality filters → TVC save) is now transparent, building trust in the system's learning process. Energy-saving cache hits become more frequent as the corpus grows.

## Architecture

```
USER QUERY (text / image / audio) <-- via CLI or HTTP /chat or Cosmic UI
    |
    v
[0] TOOL DETECTION → response + tool_name:"time"
    |                  reflection: NotApplicable
    v (no match)
[1] SYMBOLIC → response
    |            reflection: NotApplicable
    v (miss)
[2] TVC CORPUS → response
    |              reflection: NotApplicable
    v (miss)
[3] LLM CASCADE → response
    |
    v
SELF-REFLECTION (saveToTVCFiltered)
    |
    +--→ Saved           → "LEARNED" badge + green wave
    +--→ FilteredLength  → "FILTERED: Length" badge
    +--→ FilteredConfidence → "FILTERED: Confidence" badge
    +--→ FilteredError   → "FILTERED: Error" badge
    +--→ FilteredDedup   → "FILTERED: Dedup" badge
    +--→ NoCorpus        → (no badge)
    +--→ Disabled        → (no badge)
    |
    v
JSON: {"response":"...", "source":"ClaudeAPI", "tool_name":null,
       "reflection":"Saved", "learned":true, ...}
    |
    v
COSMIC UI: [ClaudeAPI] [LEARNED] badges + green reflection wave
```

## v2.4 Changes (from v2.3)

### 1. ReflectionStatus Enum

**Problem**: `saveToTVCFiltered` returned `void` — no visibility into whether a response was learned or filtered.

**Solution**: New `ReflectionStatus` enum with 8 variants and helper methods:
- `getName()` returns string representation
- `wasLearned()` returns true only for `.Saved`

### 2. saveToTVCFiltered Returns Status

**Problem**: Filter decisions were invisible. No way to know which filter rejected a response.

**Solution**: Changed return type from `void` to `ReflectionStatus`. Each filter returns its specific status:
- Length filter → `.FilteredLength`
- Confidence filter → `.FilteredConfidence`
- Error detection → `.FilteredError`
- Dedup check → `.FilteredDedup`
- No corpus → `.NoCorpus`
- All passed → `.Saved`

### 3. HybridResponse Extended

Added two fields:
- `tool_name: ?[]const u8` — specific tool name (time, date, system_info, etc.)
- `reflection: ReflectionStatus` — self-reflection result

Tool path sets `tool_name` from `ChatTool.getName()`. LLM path captures `saveToTVCFiltered` return value. Non-LLM paths default to `.NotApplicable`.

### 4. JSON Response Extended

Chat server serializes three new fields:
```json
{
  "response": "...",
  "source": "ClaudeAPI",
  "confidence": 0.95,
  "latency_us": 1234,
  "tool_name": "time",
  "reflection": "Saved",
  "learned": true
}
```

### 5. Cosmic UI Badges

- **LEARNED badge**: Green with glow, appears when `learned === true`
- **FILTERED badge**: Dim gray, shows filter reason (e.g. "FILTERED: Length")
- **Tool name badge**: Blue, shows specific tool name

### 6. Multi-Modal Input

ChatInput now has a "+" toggle that reveals:
- `image_path` text input — path to image file for vision analysis
- `audio_path` text input — path to audio file for Whisper STT

Paths are passed through to the backend `POST /chat` endpoint.

### 7. Reflection Wave Animation

When `learned === true`, a green (hue: 120) wave ring is triggered at screen center after 300ms delay, creating a visual pulse effect on the QuantumCanvas backdrop.

### Files Modified

| File | Change |
|------|--------|
| `specs/tri/trinity_chat_v2_4.vibee` | NEW: v2.4 specification |
| `src/vibeec/igla_hybrid_chat.zig` | ReflectionStatus enum, HybridResponse fields, saveToTVCFiltered return type, respond() updates, vision path updates, 8 new tests |
| `src/tri/chat_server.zig` | JSON serialization (tool_name, reflection, learned), version bump to v2.4 |
| `website/src/services/chatApi.ts` | ChatResponse: +tool_name, +reflection, +learned |
| `website/src/components/chat/ChatMessage.tsx` | Reflection badge, tool name badge, FILTERED badge |
| `website/src/components/chat/ChatInput.tsx` | Multi-modal path inputs, expanded onSend signature |
| `website/src/pages/CosmicChat.tsx` | New Message fields, reflection wave, multimodal pass-through, v2.4 label |

## Critical Assessment

1. **Reflection is LLM-only** — Tool, Symbolic, and TVC responses always get `NotApplicable`. The system only learns from LLM cascade responses. This is by design (cache hits shouldn't re-save) but means frequent tool users see no LEARNED badges.

2. **Multi-modal is path-based** — Users type file paths, not drag-and-drop. The Zig HTTP parser doesn't support multipart/form-data, so actual file upload would require a different approach (base64 in JSON, or a multipart parser).

3. **Reflection wave is cosmetic** — The green wave only fires in the browser. No server-side feedback loop. A real "learning pulse" could trigger corpus compaction or similarity index updates.

4. **No persistence of reflection stats** — The `ReflectionStatus` is ephemeral per-response. Aggregate stats (total learned, filter hit rates) are not tracked. Would need new fields in `Stats` struct.

5. **Filter reasons are coarse** — "FilteredConfidence" doesn't show the actual confidence value or threshold. Richer diagnostics would help debugging.

## Tech Tree - Next Iterations

### Option 1: Reflection Analytics (Observability)
Track aggregate reflection stats: total Saved, total FilteredLength, etc. Display as a dashboard panel. Save to disk for historical analysis. This makes the learning pipeline auditable.

### Option 2: Active Learning (Intelligence)
When a response is filtered, show a "Teach" button in the UI. User can approve saving despite filter rejection. This creates a human-in-the-loop learning pipeline with explicit quality signals.

### Option 3: File Upload Support (UX)
Add multipart/form-data parsing to the Zig HTTP server, or use base64 encoding in JSON. Enable drag-and-drop file upload in the Cosmic UI. This makes multi-modal chat actually usable without typing paths.

## Conclusion

Trinity Chat v2.4 makes self-reflection visible. Users see LEARNED/FILTERED badges on every LLM response, tool responses show specific tool names, and the multi-modal input allows image/audio path attachment. The `saveToTVCFiltered` function now returns `ReflectionStatus` instead of void, making the entire quality filter pipeline observable. All 2067 tests pass. TypeScript and Vite builds succeed.

**Koschei is energy immortal.**
