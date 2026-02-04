/**
 * FIREBIRD Fingerprint Protection Module
 * Injects stealth scripts to evade browser fingerprinting
 * φ² + 1/φ² = 3 = TRINITY
 */

// Golden ratio constants
const PHI = 1.6180339887;
const PHI_INV = 0.618033988749895;

// Fingerprint configuration
const DEFAULT_CONFIG = {
    // Canvas protection
    canvas: {
        enabled: true,
        noise: 0.0001,
        method: 'random' // 'random' or 'deterministic'
    },
    
    // WebGL protection
    webgl: {
        enabled: true,
        vendor: 'Intel Inc.',
        renderer: 'Intel Iris OpenGL Engine',
        unmaskedVendor: 'Intel Inc.',
        unmaskedRenderer: 'Intel(R) Iris(TM) Graphics 6100'
    },
    
    // Audio protection
    audio: {
        enabled: true,
        noise: 0.0001
    },
    
    // Navigator spoofing
    navigator: {
        enabled: true,
        platform: 'MacIntel',
        language: 'en-US',
        languages: ['en-US', 'en'],
        hardwareConcurrency: 8,
        deviceMemory: 8,
        maxTouchPoints: 0,
        vendor: 'Google Inc.',
        appVersion: '5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    },
    
    // Screen spoofing
    screen: {
        enabled: true,
        width: 1920,
        height: 1080,
        availWidth: 1920,
        availHeight: 1057,
        colorDepth: 24,
        pixelDepth: 24
    },
    
    // Timezone
    timezone: {
        enabled: true,
        offset: -300, // EST
        id: 'America/New_York'
    },
    
    // WebRTC protection
    webrtc: {
        enabled: true,
        mode: 'disable' // 'disable', 'fake', or 'default'
    },
    
    // Plugins
    plugins: {
        enabled: true,
        list: [
            { name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer' },
            { name: 'Chrome PDF Viewer', filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai' },
            { name: 'Native Client', filename: 'internal-nacl-plugin' }
        ]
    }
};

/**
 * Generate fingerprint injection script
 * @param {Object} config - Fingerprint configuration
 * @returns {string} - JavaScript code to inject
 */
function generateScript(config = DEFAULT_CONFIG) {
    const scripts = [];
    
    // Canvas protection
    if (config.canvas?.enabled) {
        scripts.push(`
// FIREBIRD Canvas Protection
(function() {
    const noise = ${config.canvas.noise};
    const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
    const originalGetImageData = CanvasRenderingContext2D.prototype.getImageData;
    
    HTMLCanvasElement.prototype.toDataURL = function(type) {
        const ctx = this.getContext('2d');
        if (ctx) {
            try {
                const imageData = originalGetImageData.call(ctx, 0, 0, this.width, this.height);
                for (let i = 0; i < imageData.data.length; i += 4) {
                    imageData.data[i] += Math.floor((Math.random() - 0.5) * noise * 255);
                    imageData.data[i+1] += Math.floor((Math.random() - 0.5) * noise * 255);
                    imageData.data[i+2] += Math.floor((Math.random() - 0.5) * noise * 255);
                }
                ctx.putImageData(imageData, 0, 0);
            } catch(e) {}
        }
        return originalToDataURL.apply(this, arguments);
    };
})();
`);
    }
    
    // WebGL protection
    if (config.webgl?.enabled) {
        scripts.push(`
// FIREBIRD WebGL Protection
(function() {
    const getParameterProxyHandler = {
        apply: function(target, thisArg, args) {
            const param = args[0];
            // VENDOR
            if (param === 37445) return '${config.webgl.vendor}';
            // RENDERER
            if (param === 37446) return '${config.webgl.renderer}';
            // UNMASKED_VENDOR_WEBGL
            if (param === 37445) return '${config.webgl.unmaskedVendor}';
            // UNMASKED_RENDERER_WEBGL
            if (param === 37446) return '${config.webgl.unmaskedRenderer}';
            return Reflect.apply(target, thisArg, args);
        }
    };
    
    try {
        WebGLRenderingContext.prototype.getParameter = new Proxy(
            WebGLRenderingContext.prototype.getParameter, 
            getParameterProxyHandler
        );
        WebGL2RenderingContext.prototype.getParameter = new Proxy(
            WebGL2RenderingContext.prototype.getParameter, 
            getParameterProxyHandler
        );
    } catch(e) {}
})();
`);
    }
    
    // Navigator spoofing
    if (config.navigator?.enabled) {
        scripts.push(`
// FIREBIRD Navigator Protection
(function() {
    const nav = ${JSON.stringify(config.navigator)};
    
    Object.defineProperty(navigator, 'platform', { get: () => nav.platform });
    Object.defineProperty(navigator, 'language', { get: () => nav.language });
    Object.defineProperty(navigator, 'languages', { get: () => Object.freeze([...nav.languages]) });
    Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => nav.hardwareConcurrency });
    Object.defineProperty(navigator, 'deviceMemory', { get: () => nav.deviceMemory });
    Object.defineProperty(navigator, 'maxTouchPoints', { get: () => nav.maxTouchPoints });
    Object.defineProperty(navigator, 'vendor', { get: () => nav.vendor });
    Object.defineProperty(navigator, 'appVersion', { get: () => nav.appVersion });
    
    // Hide webdriver
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
})();
`);
    }
    
    // Screen spoofing
    if (config.screen?.enabled) {
        scripts.push(`
// FIREBIRD Screen Protection
(function() {
    const scr = ${JSON.stringify(config.screen)};
    
    Object.defineProperty(screen, 'width', { get: () => scr.width });
    Object.defineProperty(screen, 'height', { get: () => scr.height });
    Object.defineProperty(screen, 'availWidth', { get: () => scr.availWidth });
    Object.defineProperty(screen, 'availHeight', { get: () => scr.availHeight });
    Object.defineProperty(screen, 'colorDepth', { get: () => scr.colorDepth });
    Object.defineProperty(screen, 'pixelDepth', { get: () => scr.pixelDepth });
})();
`);
    }
    
    // WebRTC protection
    if (config.webrtc?.enabled && config.webrtc.mode === 'disable') {
        scripts.push(`
// FIREBIRD WebRTC Protection
(function() {
    const noop = () => {};
    window.RTCPeerConnection = function() { return { close: noop, createDataChannel: noop }; };
    window.webkitRTCPeerConnection = window.RTCPeerConnection;
    window.mozRTCPeerConnection = window.RTCPeerConnection;
})();
`);
    }
    
    // Automation detection bypass
    scripts.push(`
// FIREBIRD Automation Detection Bypass
(function() {
    // Remove automation indicators
    delete window.cdc_adoQpoasnfa76pfcZLmcfl_Array;
    delete window.cdc_adoQpoasnfa76pfcZLmcfl_Promise;
    delete window.cdc_adoQpoasnfa76pfcZLmcfl_Symbol;
    
    // Override permission query
    const originalQuery = window.navigator.permissions.query;
    window.navigator.permissions.query = (parameters) => (
        parameters.name === 'notifications' ?
            Promise.resolve({ state: Notification.permission }) :
            originalQuery(parameters)
    );
    
    // Chrome runtime
    window.chrome = { runtime: {} };
    
    console.log('[FIREBIRD] Fingerprint protection active - φ² + 1/φ² = 3');
})();
`);
    
    return scripts.join('\n');
}

/**
 * Calculate fingerprint similarity score
 * @param {Object} original - Original fingerprint
 * @param {Object} spoofed - Spoofed fingerprint
 * @returns {number} - Similarity score (0-1)
 */
function calculateSimilarity(original, spoofed) {
    // Use golden ratio for weighted scoring
    let score = 0;
    let weights = 0;
    
    const checks = [
        { key: 'canvas', weight: PHI },
        { key: 'webgl', weight: PHI_INV },
        { key: 'navigator', weight: 1 },
        { key: 'screen', weight: PHI_INV },
        { key: 'audio', weight: PHI_INV * PHI_INV }
    ];
    
    for (const check of checks) {
        if (original[check.key] && spoofed[check.key]) {
            // Simple equality check (in real impl, would be more sophisticated)
            const match = JSON.stringify(original[check.key]) !== JSON.stringify(spoofed[check.key]);
            score += match ? check.weight : 0;
        }
        weights += check.weight;
    }
    
    return score / weights;
}

/**
 * Evolve fingerprint configuration
 * @param {Object} config - Current configuration
 * @param {number} generations - Number of evolution generations
 * @returns {Object} - Evolved configuration
 */
function evolveFingerprint(config, generations = 20) {
    const evolved = JSON.parse(JSON.stringify(config));
    
    for (let gen = 0; gen < generations; gen++) {
        // Mutate canvas noise
        if (evolved.canvas) {
            evolved.canvas.noise *= (1 + (Math.random() - 0.5) * PHI_INV * 0.1);
            evolved.canvas.noise = Math.max(0.00001, Math.min(0.001, evolved.canvas.noise));
        }
        
        // Mutate audio noise
        if (evolved.audio) {
            evolved.audio.noise *= (1 + (Math.random() - 0.5) * PHI_INV * 0.1);
            evolved.audio.noise = Math.max(0.00001, Math.min(0.001, evolved.audio.noise));
        }
        
        // Occasionally change hardware concurrency
        if (Math.random() < 0.1 && evolved.navigator) {
            const cores = [4, 6, 8, 12, 16];
            evolved.navigator.hardwareConcurrency = cores[Math.floor(Math.random() * cores.length)];
        }
    }
    
    return evolved;
}

module.exports = {
    DEFAULT_CONFIG,
    generateScript,
    calculateSimilarity,
    evolveFingerprint,
    PHI,
    PHI_INV
};
