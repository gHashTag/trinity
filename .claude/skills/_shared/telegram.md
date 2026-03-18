## Telegram Output (shared module)

### Usage in SKILL.md
After rendering output to stdout, include this section to send to Telegram.

### Parameters (set before including)
- `TG_TEXT` — the message text (required)
- `TG_MODE` — one of: `pin` (edit-or-pin), `send` (fire-and-forget), `dedup` (hash-based skip)
- `TG_CHAT` — chat ID (default: `-5160767429`)
- `TG_PIN_FILE` — pin persistence file (default: `.trinity/pinned_message_id`)
- `TG_PIN_TTL` — max pin age in seconds (default: `144000` = 40h)
- `TG_DEDUP_FILE` — dedup hash file (default: `.trinity/tg_dedup.hash`)
- `TG_SKIP_SIGNATURE` — strip `[emoji mood]` from TG_TEXT (default: true)

### Logic

**Mode: pin** (used by /tri)
1. Read `TG_PIN_FILE` → get `PINNED_ID` and `PIN_TS`
2. If pin exists and age < TTL → `tri notify --chat TG_CHAT --edit PINNED_ID TG_TEXT`
3. If edit fails or no pin → `tri notify --chat TG_CHAT --pin TG_TEXT` → save new ID

**Mode: send** (used by /doctor)
1. `tri notify --chat TG_CHAT TG_TEXT`

**Mode: dedup** (used by /train, /status)
1. Compute hash of TG_TEXT via `cksum`
2. Compare with stored hash in TG_DEDUP_FILE
3. If same → skip (say "no change, skipping Telegram"). If different → send + update hash.

### Shell Template
```bash
# === TELEGRAM OUTPUT ===
export TELEGRAM_BOT_TOKEN="$(grep '^TELEGRAM_BOT_TOKEN=' .env 2>/dev/null | cut -d= -f2)"
export TELEGRAM_CHAT_ID="$(grep '^TELEGRAM_CHAT_ID=' .env 2>/dev/null | cut -d= -f2)"
TG_CHAT="${TG_CHAT:-${TELEGRAM_CHAT_ID:--5160767429}}"
TG_MODE="${TG_MODE:-send}"

# Strip mood signature if needed
if [ "${TG_SKIP_SIGNATURE:-true}" = "true" ]; then
  TG_TEXT=$(echo "$TG_TEXT" | sed '/^\[.*\]$/d')
fi

case "$TG_MODE" in
  pin)
    PIN_FILE="${TG_PIN_FILE:-.trinity/pinned_message_id}"
    PIN_TTL="${TG_PIN_TTL:-144000}"
    PINNED_ID="" AGE=999999
    if [ -f "$PIN_FILE" ]; then
      PINNED_ID=$(awk '{print $1}' "$PIN_FILE")
      PIN_TS=$(awk '{print $2}' "$PIN_FILE" 2>/dev/null || echo "0")
      AGE=$(( $(date +%s) - PIN_TS ))
    fi
    if [ -n "$PINNED_ID" ] && [ "$AGE" -lt "$PIN_TTL" ]; then
      tri notify --chat "$TG_CHAT" --edit "$PINNED_ID" "$TG_TEXT" 2>/dev/null || {
        NEW_ID=$(tri notify --chat "$TG_CHAT" --pin "$TG_TEXT" 2>/dev/null | head -1)
        [ -n "$NEW_ID" ] && echo "$NEW_ID $(date +%s)" > "$PIN_FILE"
      }
    else
      NEW_ID=$(tri notify --chat "$TG_CHAT" --pin "$TG_TEXT" 2>/dev/null | head -1)
      [ -n "$NEW_ID" ] && echo "$NEW_ID $(date +%s)" > "$PIN_FILE"
    fi
    ;;
  dedup)
    DEDUP_FILE="${TG_DEDUP_FILE:-.trinity/tg_dedup.hash}"
    NEW_HASH=$(echo "$TG_TEXT" | cksum | awk '{print $1}')
    OLD_HASH=$(cat "$DEDUP_FILE" 2>/dev/null)
    if [ "$NEW_HASH" != "$OLD_HASH" ]; then
      tri notify --chat "$TG_CHAT" "$TG_TEXT" 2>/dev/null
      echo "$NEW_HASH" > "$DEDUP_FILE"
    fi
    ;;
  send)
    tri notify --chat "$TG_CHAT" "$TG_TEXT" 2>/dev/null
    ;;
esac
```

### Dedup Registry

Default: `TG_DEDUP_FILE=.trinity/tg_dedup_${SKILL_NAME}.hash`

If `TG_DEDUP_FILE` is not set explicitly, derive from skill name automatically:
`TG_DEDUP_FILE=.trinity/tg_dedup_$(echo "$SKILL_NAME" | tr '[:upper:]' '[:lower:]').hash`

| Skill | File | Mode |
|-------|------|------|
| tri | .trinity/tg_dedup_tri.hash | pin |
| train | .trinity/tg_dedup_train.hash | dedup |
| farm | .trinity/tg_dedup_farm.hash | dedup |
| status | .trinity/tg_dedup_status.hash | dedup |
| wave | .trinity/tg_dedup_wave.hash | dedup |
| doctor | (none — uses send mode) | send |

### Key Rules
- `tri notify --pin` sends ONE message, pins it, prints `message_id` to stdout
- `tri notify --edit <id>` edits existing message (no new message sent)
- `.trinity/pinned_message_id` persists: `<message_id> <unix_timestamp>`
- If pin is older than 40 hours (144000s), send a fresh pin
- If edit fails, fall back to new pin
- HTML parse mode is automatic (set in Zig code)
- Do NOT include `[emoji mood]` signature in Telegram messages (stdout only)
- Per-skill dedup files prevent cross-skill interference
- Use the registry above to determine which dedup file a skill should use
