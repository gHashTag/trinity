/**
 * Cloudflare Bypass Module
 * Advanced techniques for bypassing Cloudflare protection
 * φ² + 1/φ² = 3 = TRINITY
 */

// User agent pool - real browser fingerprints
const USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0'
];

// Accept-Language variations
const ACCEPT_LANGUAGES = [
    'en-US,en;q=0.9',
    'en-GB,en;q=0.9,en-US;q=0.8',
    'en-US,en;q=0.9,es;q=0.8',
    'en,en-US;q=0.9'
];

// φ-based timing (golden ratio delays)
const PHI = 1.618033988749895;
const PHI_SQUARED = PHI * PHI; // 2.618...
const PHI_INVERSE = 1 / PHI;   // 0.618...

function phiDelay(base = 1000) {
    // Golden ratio based random delay
    const factor = 1 + (Math.random() * (PHI - 1));
    return Math.floor(base * factor);
}

// φ-mutation: Generate unique fingerprint variations using golden ratio
function phiMutate(seed = Date.now()) {
    // Use φ to create deterministic but varied mutations
    const mutations = [];
    let value = seed;
    
    for (let i = 0; i < 5; i++) {
        value = (value * PHI) % 1000000;
        mutations.push(Math.floor(value));
    }
    
    return mutations;
}

// Generate φ-mutated headers for each request
function generatePhiHeaders(requestCount = 0) {
    const mutations = phiMutate(Date.now() + requestCount);
    const baseHeaders = generateHeaders();
    
    // Apply φ-mutations to create unique fingerprint
    const phiHeaders = {
        ...baseHeaders,
        // Mutate sec-ch-ua version based on φ
        'sec-ch-ua': `"Not_A Brand";v="${8 + (mutations[0] % 3)}", "Chromium";v="${118 + (mutations[1] % 5)}", "Google Chrome";v="${118 + (mutations[1] % 5)}"`,
        // Add unique request ID based on φ
        'X-Request-ID': `${mutations[2].toString(16)}-${mutations[3].toString(16)}`,
        // Vary cache control
        'Cache-Control': mutations[4] % 2 === 0 ? 'max-age=0' : 'no-cache'
    };
    
    return phiHeaders;
}

function getRandomUserAgent() {
    return USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];
}

function getRandomAcceptLanguage() {
    return ACCEPT_LANGUAGES[Math.floor(Math.random() * ACCEPT_LANGUAGES.length)];
}

// Generate Cloudflare-evading headers
function generateHeaders() {
    return {
        'User-Agent': getRandomUserAgent(),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': getRandomAcceptLanguage(),
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
        'Cache-Control': 'max-age=0',
        'sec-ch-ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"'
    };
}

// Wait for Cloudflare challenge to complete
async function waitForCloudflare(page, timeout = 30000) {
    const startTime = Date.now();
    
    while (Date.now() - startTime < timeout) {
        const title = await page.title();
        const url = page.url();
        
        // Check if still on challenge page
        if (title.includes('Just a moment') || 
            title.includes('Checking your browser') ||
            title.includes('Please wait') ||
            url.includes('challenge')) {
            
            console.log('    Waiting for Cloudflare challenge...');
            await page.waitForTimeout(phiDelay(2000));
            continue;
        }
        
        // Challenge passed
        return true;
    }
    
    return false;
}

// Attempt navigation with Cloudflare bypass
async function navigateWithBypass(page, url, options = {}) {
    const maxRetries = options.maxRetries || 3;
    const headers = generateHeaders();
    
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        console.log(`    Attempt ${attempt}/${maxRetries} with bypass...`);
        
        try {
            // Set extra headers
            await page.setExtraHTTPHeaders(headers);
            
            // Navigate with longer timeout
            await page.goto(url, {
                waitUntil: 'domcontentloaded',
                timeout: 30000
            });
            
            // Wait for potential Cloudflare challenge
            const passed = await waitForCloudflare(page, 15000);
            
            if (passed) {
                const title = await page.title();
                if (!title.includes('Just a moment') && !title.includes('Checking')) {
                    console.log(`    Cloudflare bypassed on attempt ${attempt}`);
                    return true;
                }
            }
            
            // Rotate user agent for next attempt
            headers['User-Agent'] = getRandomUserAgent();
            
            // φ-based delay before retry
            await page.waitForTimeout(phiDelay(3000));
            
        } catch (error) {
            console.log(`    Attempt ${attempt} failed: ${error.message}`);
            if (attempt < maxRetries) {
                await page.waitForTimeout(phiDelay(2000));
            }
        }
    }
    
    return false;
}

// Create browser context with Cloudflare evasion
async function createBypassContext(browser) {
    const userAgent = getRandomUserAgent();
    
    const context = await browser.newContext({
        userAgent,
        viewport: { width: 1920, height: 1080 },
        locale: 'en-US',
        timezoneId: 'America/New_York',
        geolocation: { latitude: 40.7128, longitude: -74.0060 },
        permissions: ['geolocation'],
        extraHTTPHeaders: generateHeaders()
    });
    
    // Inject stealth scripts
    await context.addInitScript(() => {
        // Hide webdriver
        Object.defineProperty(navigator, 'webdriver', { get: () => false });
        
        // Fake plugins
        Object.defineProperty(navigator, 'plugins', {
            get: () => [1, 2, 3, 4, 5]
        });
        
        // Fake languages
        Object.defineProperty(navigator, 'languages', {
            get: () => ['en-US', 'en']
        });
        
        // Override permissions
        const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.query = (parameters) => (
            parameters.name === 'notifications' ?
                Promise.resolve({ state: Notification.permission }) :
                originalQuery(parameters)
        );
        
        // Fake chrome object
        window.chrome = {
            runtime: {},
            loadTimes: function() {},
            csi: function() {},
            app: {}
        };
        
        // Override toString to hide modifications
        const originalToString = Function.prototype.toString;
        Function.prototype.toString = function() {
            if (this === navigator.permissions.query) {
                return 'function query() { [native code] }';
            }
            return originalToString.call(this);
        };
    });
    
    return context;
}

module.exports = {
    USER_AGENTS,
    PHI,
    PHI_SQUARED,
    PHI_INVERSE,
    phiDelay,
    phiMutate,
    getRandomUserAgent,
    getRandomAcceptLanguage,
    generateHeaders,
    generatePhiHeaders,
    waitForCloudflare,
    navigateWithBypass,
    createBypassContext
};
