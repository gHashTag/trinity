# ЖАР ПТИЦА Browser Extension

## Структура

```
extension/
├── manifest.json       # Chrome Manifest V3 (генерируется из .vibee)
├── popup/
│   ├── popup.html      # Popup UI (генерируется)
│   ├── popup.js        # Popup logic (генерируется)
│   └── popup.css       # Styles (генерируется)
├── background/
│   └── background.js   # Service worker (генерируется)
├── content/
│   └── content.js      # Content script (генерируется)
├── wasm/
│   ├── firebird.wasm   # Compiled from extension_wasm.zig
│   └── firebird.js     # WASM loader (генерируется)
├── icons/
│   ├── firebird-16.png
│   ├── firebird-32.png
│   ├── firebird-48.png
│   └── firebird-128.png
└── README.md           # This file
```

## Сборка

### 1. Компиляция WASM модуля

```bash
# Из корня проекта
cd /workspaces/trinity

# Компиляция Zig → WASM (требует wasm32 target)
zig build-lib src/firebird/extension_wasm.zig \
  -target wasm32-freestanding \
  -O ReleaseFast \
  -femit-bin=extension/wasm/firebird.wasm
```

### 2. Генерация JS/HTML из .vibee

```bash
# Генерация из спецификаций
./bin/vibee gen specs/tri/browser_extension/manifest.vibee
./bin/vibee gen specs/tri/browser_extension/popup_ui.vibee
./bin/vibee gen specs/tri/browser_extension/content_script.vibee
./bin/vibee gen specs/tri/browser_extension/tri_staking.vibee
```

### 3. Загрузка в Chrome

1. Открыть `chrome://extensions/`
2. Включить "Developer mode"
3. Нажать "Load unpacked"
4. Выбрать папку `extension/`

## Спецификации (.vibee)

Все файлы extension генерируются из спецификаций:

| Спецификация | Генерирует |
|--------------|------------|
| `extension_core.vibee` | Основная логика |
| `manifest.vibee` | manifest.json |
| `popup_ui.vibee` | popup.html/js/css |
| `content_script.vibee` | content.js |
| `tri_staking.vibee` | Staking UI/logic |

## WASM API

Экспортируемые функции из `extension_wasm.zig`:

```zig
// Инициализация
export fn wasm_init(seed: u64) i32;

// Профили
export fn wasm_create_profile(seed: u64, dim: u32) i32;
export fn wasm_get_similarity() f64;
export fn wasm_get_canvas_hash() u64;
export fn wasm_get_webgl_hash() u64;
export fn wasm_get_audio_hash() u64;

// Навигация
export fn wasm_init_navigation(dim: u32, seed: u64) i32;
export fn wasm_navigate_step(strength: f64) f64;
export fn wasm_get_nav_steps() u32;

// DePIN
export fn wasm_get_pending_tri() f64;
export fn wasm_get_total_tri() f64;
export fn wasm_claim_rewards() f64;
export fn wasm_record_evasion() void;

// Evasion helpers
export fn wasm_get_screen_width() u32;
export fn wasm_get_screen_height() u32;
export fn wasm_get_timezone_offset() i32;
export fn wasm_get_language_index() u32;

// Cleanup
export fn wasm_cleanup() void;
```

## Тестирование

```bash
# Unit tests для WASM модуля
zig test src/firebird/extension_wasm.zig
# 31 tests passed

# После загрузки в Chrome
# 1. Открыть https://browserleaks.com/canvas
# 2. Проверить что canvas hash отличается
# 3. Проверить консистентность при перезагрузке
```

## Ограничения

⚠️ **Согласно правилам проекта (AGENTS.md):**
- .js, .html, .css файлы НЕ создаются вручную
- Все файлы ГЕНЕРИРУЮТСЯ из .vibee спецификаций
- Только .vibee и .zig файлы редактируются напрямую

---

*φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL*
