#!/usr/bin/env node
/**
 * WebArena Playwright Bridge
 * JSON-RPC server for Zig agent communication
 * φ² + 1/φ² = 3 = TRINITY
 */

const readline = require('readline');

// Playwright will be dynamically imported when available
let playwright = null;
let browser = null;
let context = null;
let page = null;

// FIREBIRD fingerprint configuration
const FIREBIRD_FINGERPRINT = {
    // Canvas fingerprint noise
    canvasNoise: 0.0001,
    // WebGL vendor/renderer spoofing
    webglVendor: 'Intel Inc.',
    webglRenderer: 'Intel Iris OpenGL Engine',
    // Audio context noise
    audioNoise: 0.0001,
    // Navigator properties
    navigator: {
        platform: 'MacIntel',
        language: 'en-US',
        languages: ['en-US', 'en'],
        hardwareConcurrency: 8,
        deviceMemory: 8,
        maxTouchPoints: 0
    },
    // Screen properties
    screen: {
        width: 1920,
        height: 1080,
        colorDepth: 24,
        pixelDepth: 24
    }
};

// Fingerprint injection script
const FINGERPRINT_SCRIPT = `
// Canvas fingerprint protection
const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
HTMLCanvasElement.prototype.toDataURL = function(type) {
    const canvas = this;
    const ctx = canvas.getContext('2d');
    if (ctx) {
        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        for (let i = 0; i < imageData.data.length; i += 4) {
            imageData.data[i] += Math.floor(Math.random() * 2) - 1;
        }
        ctx.putImageData(imageData, 0, 0);
    }
    return originalToDataURL.apply(this, arguments);
};

// WebGL fingerprint protection
const getParameterProxyHandler = {
    apply: function(target, thisArg, args) {
        const param = args[0];
        if (param === 37445) return '${FIREBIRD_FINGERPRINT.webglVendor}';
        if (param === 37446) return '${FIREBIRD_FINGERPRINT.webglRenderer}';
        return Reflect.apply(target, thisArg, args);
    }
};

// Navigator spoofing
Object.defineProperty(navigator, 'platform', { get: () => '${FIREBIRD_FINGERPRINT.navigator.platform}' });
Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => ${FIREBIRD_FINGERPRINT.navigator.hardwareConcurrency} });
Object.defineProperty(navigator, 'deviceMemory', { get: () => ${FIREBIRD_FINGERPRINT.navigator.deviceMemory} });

// Screen spoofing
Object.defineProperty(screen, 'width', { get: () => ${FIREBIRD_FINGERPRINT.screen.width} });
Object.defineProperty(screen, 'height', { get: () => ${FIREBIRD_FINGERPRINT.screen.height} });

console.log('[FIREBIRD] Fingerprint protection active');
`;

// JSON-RPC request handler
async function handleRequest(request) {
    const { id, method, params } = request;
    
    try {
        let result;
        
        switch (method) {
            case 'connect':
                result = await connect(params);
                break;
            case 'disconnect':
                result = await disconnect();
                break;
            case 'navigate':
                result = await navigate(params);
                break;
            case 'click':
                result = await click(params);
                break;
            case 'type':
                result = await typeText(params);
                break;
            case 'scroll':
                result = await scroll(params);
                break;
            case 'getState':
                result = await getState();
                break;
            case 'screenshot':
                result = await screenshot(params);
                break;
            case 'getAccessibilityTree':
                result = await getAccessibilityTree();
                break;
            case 'injectFingerprint':
                result = await injectFingerprint();
                break;
            case 'ping':
                result = { pong: true, timestamp: Date.now() };
                break;
            default:
                throw new Error(`Unknown method: ${method}`);
        }
        
        return { jsonrpc: '2.0', id, result };
    } catch (error) {
        return { 
            jsonrpc: '2.0', 
            id, 
            error: { code: -32000, message: error.message } 
        };
    }
}

// Connect to browser
async function connect(params = {}) {
    const { headless = true, viewport = { width: 1280, height: 720 }, stealth = true } = params;
    
    // Try to import playwright
    try {
        playwright = require('playwright');
    } catch (e) {
        // Playwright not installed - return mock response
        return { 
            success: true, 
            mock: true, 
            message: 'Playwright not installed - running in mock mode',
            sessionId: 'mock-' + Date.now()
        };
    }
    
    browser = await playwright.chromium.launch({ 
        headless,
        args: [
            '--disable-blink-features=AutomationControlled',
            '--disable-features=IsolateOrigins,site-per-process'
        ]
    });
    
    context = await browser.newContext({
        viewport,
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        locale: 'en-US',
        timezoneId: 'America/New_York'
    });
    
    page = await context.newPage();
    
    // Inject fingerprint protection if stealth enabled
    if (stealth) {
        await page.addInitScript(FINGERPRINT_SCRIPT);
    }
    
    return { 
        success: true, 
        mock: false,
        sessionId: 'session-' + Date.now(),
        viewport
    };
}

// Disconnect from browser
async function disconnect() {
    if (browser) {
        await browser.close();
        browser = null;
        context = null;
        page = null;
    }
    return { success: true };
}

// Navigate to URL
async function navigate(params) {
    const { url, timeout = 30000 } = params;
    
    if (!page) {
        // Mock mode
        return { success: true, mock: true, url };
    }
    
    await page.goto(url, { timeout, waitUntil: 'domcontentloaded' });
    return { 
        success: true, 
        url: page.url(),
        title: await page.title()
    };
}

// Click element
async function click(params) {
    const { selector, elementId, coords, timeout = 5000 } = params;
    
    if (!page) {
        return { success: true, mock: true };
    }
    
    if (selector) {
        await page.click(selector, { timeout });
    } else if (coords) {
        await page.mouse.click(coords.x, coords.y);
    } else if (elementId !== undefined) {
        // Click by accessibility tree ID
        const elements = await page.$$('[data-testid], button, a, input');
        if (elementId < elements.length) {
            await elements[elementId].click();
        }
    }
    
    return { success: true };
}

// Type text
async function typeText(params) {
    const { selector, elementId, text, delay = 50 } = params;
    
    if (!page) {
        return { success: true, mock: true };
    }
    
    if (selector) {
        await page.fill(selector, text);
    } else {
        // Type with human-like delay
        for (const char of text) {
            await page.keyboard.type(char, { delay: delay + Math.random() * 50 });
        }
    }
    
    return { success: true };
}

// Scroll page
async function scroll(params) {
    const { direction = 'down', amount = 300 } = params;
    
    if (!page) {
        return { success: true, mock: true };
    }
    
    const delta = direction === 'down' ? amount : -amount;
    await page.mouse.wheel(0, delta);
    
    return { success: true };
}

// Get current page state
async function getState() {
    if (!page) {
        return {
            mock: true,
            url: 'http://mock',
            title: 'Mock Page',
            elementsCount: 0
        };
    }
    
    const url = page.url();
    const title = await page.title();
    const elementsCount = await page.$$eval('*', els => els.length);
    
    return { url, title, elementsCount };
}

// Take screenshot
async function screenshot(params = {}) {
    const { format = 'base64', fullPage = false } = params;
    
    if (!page) {
        return { mock: true, data: '' };
    }
    
    const buffer = await page.screenshot({ fullPage });
    return { 
        data: buffer.toString('base64'),
        format: 'png'
    };
}

// Get accessibility tree
async function getAccessibilityTree() {
    if (!page) {
        return { mock: true, tree: [] };
    }
    
    // Get simplified accessibility tree
    const tree = await page.evaluate(() => {
        const elements = [];
        const walker = document.createTreeWalker(
            document.body,
            NodeFilter.SHOW_ELEMENT,
            null,
            false
        );
        
        let id = 0;
        let node;
        while (node = walker.nextNode()) {
            const rect = node.getBoundingClientRect();
            if (rect.width > 0 && rect.height > 0) {
                elements.push({
                    id: id++,
                    tag: node.tagName.toLowerCase(),
                    role: node.getAttribute('role') || node.tagName.toLowerCase(),
                    text: (node.textContent || '').slice(0, 100).trim(),
                    bounds: {
                        x: Math.round(rect.x),
                        y: Math.round(rect.y),
                        width: Math.round(rect.width),
                        height: Math.round(rect.height)
                    },
                    clickable: node.tagName === 'BUTTON' || node.tagName === 'A' || 
                               node.onclick !== null || node.getAttribute('role') === 'button',
                    focusable: node.tabIndex >= 0
                });
            }
            if (id >= 500) break; // Limit elements
        }
        return elements;
    });
    
    return { tree };
}

// Inject FIREBIRD fingerprint protection
async function injectFingerprint() {
    if (!page) {
        return { success: true, mock: true };
    }
    
    await page.addInitScript(FINGERPRINT_SCRIPT);
    return { success: true, fingerprint: FIREBIRD_FINGERPRINT };
}

// Main: Read JSON-RPC from stdin, write to stdout
async function main() {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
        terminal: false
    });
    
    console.error('[FIREBIRD Bridge] Started - φ² + 1/φ² = 3 = TRINITY');
    
    rl.on('line', async (line) => {
        try {
            const request = JSON.parse(line);
            const response = await handleRequest(request);
            console.log(JSON.stringify(response));
        } catch (error) {
            console.log(JSON.stringify({
                jsonrpc: '2.0',
                id: null,
                error: { code: -32700, message: 'Parse error: ' + error.message }
            }));
        }
    });
    
    rl.on('close', async () => {
        await disconnect();
        process.exit(0);
    });
}

// Run if executed directly
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { handleRequest, connect, disconnect, navigate, click, typeText, getState };
