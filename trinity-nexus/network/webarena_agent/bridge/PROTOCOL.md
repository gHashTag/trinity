# FIREBIRD Playwright Bridge Protocol

**Version**: 1.0.0  
**Transport**: JSON-RPC 2.0 over stdin/stdout  
**Formula**: φ² + 1/φ² = 3 = TRINITY

---

## Overview

The FIREBIRD Playwright Bridge uses JSON-RPC 2.0 for communication between the Zig agent and Node.js Playwright process.

```
┌─────────────────┐     stdin (JSON-RPC)      ┌─────────────────┐
│   Zig Agent     │ ─────────────────────────▶│  Node.js Bridge │
│  (subprocess    │                           │  (Playwright)   │
│   spawner)      │ ◀───────────────────────── │                 │
└─────────────────┘     stdout (JSON-RPC)     └─────────────────┘
```

---

## Request Format

```json
{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "methodName",
    "params": { ... }
}
```

## Response Format

```json
{
    "jsonrpc": "2.0",
    "id": 1,
    "result": { ... }
}
```

## Error Format

```json
{
    "jsonrpc": "2.0",
    "id": 1,
    "error": {
        "code": -32000,
        "message": "Error description"
    }
}
```

---

## Methods

### connect

Start browser and create context with optional stealth.

**Request:**
```json
{
    "method": "connect",
    "params": {
        "headless": true,
        "viewport": { "width": 1280, "height": 720 },
        "stealth": true
    }
}
```

**Response:**
```json
{
    "result": {
        "success": true,
        "mock": false,
        "sessionId": "session-1234567890",
        "viewport": { "width": 1280, "height": 720 }
    }
}
```

### disconnect

Close browser and cleanup.

**Request:**
```json
{
    "method": "disconnect"
}
```

**Response:**
```json
{
    "result": { "success": true }
}
```

### navigate

Navigate to URL.

**Request:**
```json
{
    "method": "navigate",
    "params": {
        "url": "https://example.com",
        "timeout": 30000
    }
}
```

**Response:**
```json
{
    "result": {
        "success": true,
        "url": "https://example.com/",
        "title": "Example Domain"
    }
}
```

### click

Click element by selector, ID, or coordinates.

**Request:**
```json
{
    "method": "click",
    "params": {
        "selector": "button.submit",
        "elementId": 42,
        "coords": { "x": 100, "y": 200 },
        "timeout": 5000
    }
}
```

**Response:**
```json
{
    "result": { "success": true }
}
```

### type

Type text into element.

**Request:**
```json
{
    "method": "type",
    "params": {
        "selector": "input[name='search']",
        "text": "search query",
        "delay": 50
    }
}
```

**Response:**
```json
{
    "result": { "success": true }
}
```

### scroll

Scroll page.

**Request:**
```json
{
    "method": "scroll",
    "params": {
        "direction": "down",
        "amount": 300
    }
}
```

**Response:**
```json
{
    "result": { "success": true }
}
```

### getState

Get current page state.

**Request:**
```json
{
    "method": "getState"
}
```

**Response:**
```json
{
    "result": {
        "url": "https://example.com/",
        "title": "Example Domain",
        "elementsCount": 42
    }
}
```

### getAccessibilityTree

Get simplified accessibility tree.

**Request:**
```json
{
    "method": "getAccessibilityTree"
}
```

**Response:**
```json
{
    "result": {
        "tree": [
            {
                "id": 0,
                "tag": "button",
                "role": "button",
                "text": "Submit",
                "bounds": { "x": 100, "y": 200, "width": 80, "height": 30 },
                "clickable": true,
                "focusable": true
            }
        ]
    }
}
```

### screenshot

Take screenshot.

**Request:**
```json
{
    "method": "screenshot",
    "params": {
        "format": "base64",
        "fullPage": false
    }
}
```

**Response:**
```json
{
    "result": {
        "data": "iVBORw0KGgoAAAANSUhEUgAA...",
        "format": "png"
    }
}
```

### injectFingerprint

Inject FIREBIRD fingerprint protection.

**Request:**
```json
{
    "method": "injectFingerprint"
}
```

**Response:**
```json
{
    "result": {
        "success": true,
        "fingerprint": {
            "canvasNoise": 0.0001,
            "webglVendor": "Intel Inc.",
            "webglRenderer": "Intel Iris OpenGL Engine"
        }
    }
}
```

### ping

Check connection.

**Request:**
```json
{
    "method": "ping"
}
```

**Response:**
```json
{
    "result": {
        "pong": true,
        "timestamp": 1234567890
    }
}
```

---

## Error Codes

| Code | Message | Description |
|------|---------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid request | Missing required fields |
| -32601 | Method not found | Unknown method |
| -32000 | Server error | Browser/Playwright error |

---

## Mock Mode

When Playwright is not installed, the bridge runs in mock mode:
- All methods return `{ "success": true, "mock": true }`
- No actual browser is spawned
- Useful for testing without dependencies

---

## FIREBIRD Fingerprint Protection

When `stealth: true` is passed to `connect`, the following protections are injected:

1. **Canvas Fingerprint**: Random noise added to canvas data
2. **WebGL Fingerprint**: Vendor/renderer spoofed
3. **Audio Fingerprint**: Noise added to audio context
4. **Navigator Properties**: Platform, hardware info spoofed
5. **Screen Properties**: Resolution normalized

---

**φ² + 1/φ² = 3 = TRINITY | FIREBIRD BRIDGE PROTOCOL**
