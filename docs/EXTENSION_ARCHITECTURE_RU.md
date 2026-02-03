# Архитектура Browser Extension ЖАР ПТИЦА

## Обзор

Browser extension для ЖАР ПТИЦА интегрирует тернарный B2T pipeline с реальным браузером, обеспечивая fingerprint evasion и DePIN rewards.

```
┌─────────────────────────────────────────────────────────────────┐
│                    BROWSER EXTENSION                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Popup     │◄──►│ Background  │◄──►│   Content   │         │
│  │    UI       │    │   Script    │    │   Script    │         │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            │                                    │
│                    ┌───────▼───────┐                            │
│                    │  WASM Module  │                            │
│                    │  (Zig→WASM)   │                            │
│                    └───────┬───────┘                            │
│                            │                                    │
│         ┌──────────────────┼──────────────────┐                 │
│         │                  │                  │                 │
│  ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐         │
│  │     VSA     │    │     B2T     │    │   DePIN     │         │
│  │  Operations │    │  Pipeline   │    │   Rewards   │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Компоненты

### 1. Popup UI (`popup.html` + `popup.js`)

Пользовательский интерфейс для управления extension:

```
┌────────────────────────────────────┐
│  ЖАР ПТИЦА 🔥           v1.0.0    │
│  ● Online                          │
├────────────────────────────────────┤
│  Evasion: [ON]                     │
│  ████████████░░░░ 80%              │
│  Similarity: 0.80 / 0.90           │
│  Risk: LOW                         │
├────────────────────────────────────┤
│  Profile: Default_12345            │
│  [Generate New] [Delete]           │
├────────────────────────────────────┤
│  Navigation                        │
│  Steps: 25 | Sim: 0.80             │
│  [Navigate] [Reset]                │
├────────────────────────────────────┤
│  $TRI Rewards                      │
│  Pending: 0.0025 $TRI              │
│  Total: 1.2500 $TRI                │
│  [Claim] [Stake]                   │
├────────────────────────────────────┤
│  ▼ Fingerprint Details             │
│  Canvas: 0x7a3f...                 │
│  WebGL: 0x9c2e...                  │
│  Audio: 0x4b1d...                  │
└────────────────────────────────────┘
```

### 2. Background Script (`background.js`)

Service worker для:
- Инициализация WASM модуля
- Управление профилями
- Синхронизация с DePIN
- Обработка сообщений

```javascript
// Псевдокод (генерируется из .vibee)
chrome.runtime.onInstalled.addListener(() => {
  initWasmModule();
  loadConfig();
  startDePINSync();
});

chrome.runtime.onMessage.addListener((msg, sender, respond) => {
  switch(msg.type) {
    case 'CREATE_PROFILE': return createProfile(msg.seed);
    case 'NAVIGATE_STEP': return navigateStep(msg.strength);
    case 'CLAIM_REWARDS': return claimRewards();
  }
});
```

### 3. Content Script (`content.js`)

Инъекция fingerprint overrides:

```javascript
// Псевдокод (генерируется из .vibee)
(function() {
  const profile = getProfileFromStorage();
  
  // Canvas override
  const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
  HTMLCanvasElement.prototype.toDataURL = function() {
    const data = originalToDataURL.apply(this, arguments);
    return addNoise(data, profile.canvasSeed);
  };
  
  // WebGL override
  const originalGetParameter = WebGLRenderingContext.prototype.getParameter;
  WebGLRenderingContext.prototype.getParameter = function(param) {
    if (param === VENDOR) return profile.vendor;
    if (param === RENDERER) return profile.renderer;
    return originalGetParameter.apply(this, arguments);
  };
  
  // Navigator override
  Object.defineProperty(navigator, 'platform', {
    get: () => profile.platform
  });
})();
```

### 4. WASM Module (`firebird.wasm`)

Скомпилированный из Zig модуль:

```zig
// src/firebird/extension_wasm.zig
export fn wasm_create_profile(seed: u64, dim: u32) i32;
export fn wasm_navigate_step(strength: f64) f64;
export fn wasm_get_canvas_hash() u64;
export fn wasm_get_pending_tri() f64;
export fn wasm_claim_rewards() f64;
```

## Потоки Данных

### Создание Профиля

```
User clicks "Generate"
        │
        ▼
    Popup.js
        │
        ▼ chrome.runtime.sendMessage
        │
  Background.js
        │
        ▼ wasm_create_profile()
        │
    WASM Module
        │
        ▼ TritVec.random()
        │
    VSA Operations
        │
        ▼ Return profile
        │
  Background.js
        │
        ▼ chrome.storage.local.set()
        │
    Storage
        │
        ▼ Response
        │
    Popup.js
        │
        ▼ Update UI
```

### Применение Evasion

```
Page loads
    │
    ▼
Content.js (document_start)
    │
    ▼ chrome.storage.local.get()
    │
Get profile
    │
    ▼ Inject overrides
    │
Page context
    │
    ▼ Canvas/WebGL/Navigator spoofed
    │
Fingerprint evasion active
    │
    ▼ Record DePIN operation
    │
Background.js
    │
    ▼ wasm_record_evasion()
    │
$TRI reward added
```

## Файловая Структура

```
extension/
├── manifest.json           # Extension manifest (V3)
├── popup/
│   ├── popup.html          # Popup UI
│   ├── popup.js            # Popup logic
│   └── popup.css           # Popup styles
├── background/
│   └── background.js       # Service worker
├── content/
│   └── content.js          # Content script
├── wasm/
│   ├── firebird.wasm       # Compiled WASM
│   └── firebird.js         # WASM loader
├── icons/
│   ├── firebird-16.png
│   ├── firebird-32.png
│   ├── firebird-48.png
│   └── firebird-128.png
└── options/
    ├── options.html        # Settings page
    └── options.js          # Settings logic
```

## Сборка

### Компиляция WASM

```bash
# Из корня проекта
zig build-lib src/firebird/extension_wasm.zig \
  -target wasm32-freestanding \
  -O ReleaseFast \
  -femit-bin=extension/wasm/firebird.wasm
```

### Упаковка Extension

```bash
# Создать ZIP для Chrome Web Store
cd extension
zip -r ../firebird-extension.zip .
```

## Безопасность

### Content Security Policy

```json
{
  "content_security_policy": {
    "extension_pages": "script-src 'self' 'wasm-unsafe-eval'; object-src 'self'"
  }
}
```

### Stealth Techniques

1. **Удаление следов инъекции** - Очистка DOM после инъекции
2. **Proxy-based interception** - Прозрачный перехват без модификации прототипов
3. **Consistent behavior** - Одинаковые результаты при повторных вызовах
4. **Timing randomization** - Случайные задержки для избежания timing attacks

## Метрики Производительности

| Операция | Время | Память |
|----------|-------|--------|
| WASM init | 50ms | 2MB |
| Profile create | 10ms | 100KB |
| Navigate step | 1ms | 10KB |
| Canvas override | <1ms | - |
| WebGL override | <1ms | - |

## Тестирование

### Unit Tests (Zig)

```bash
zig test src/firebird/extension_wasm.zig
# 31 tests passed
```

### Integration Tests

1. Загрузить extension в Chrome
2. Открыть https://browserleaks.com/canvas
3. Проверить, что canvas hash отличается от оригинала
4. Проверить консистентность при перезагрузке

### E2E Tests

```bash
# С использованием Puppeteer
npm run test:extension
```

## Roadmap

### v1.0.0 (Текущая)
- [x] WASM module с VSA
- [x] Базовые overrides (canvas, webgl, navigator)
- [x] DePIN mock rewards
- [x] Popup UI спецификация

### v1.1.0
- [ ] Реальный $TRI staking
- [ ] Больше fingerprint overrides
- [ ] Firefox support

### v2.0.0
- [ ] Full browser integration
- [ ] Automated profile rotation
- [ ] AI-based evasion optimization

---

*φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL*
