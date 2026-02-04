// NeoDetect Background Script (Firefox)
// WASM-powered antidetect browser extension
// φ² + 1/φ² = 3 = TRINITY

const PHI = 1.6180339887;
const TRINITY = 3.0;

// NeoDetect state
let neodetectState = {
  enabled: true,
  similarity: 0.85,
  profile: null,
  lastEvolution: null,
  aiMode: false,
  wasmReady: false,
  osType: 0,
  hwType: 1,
  gpuType: 1,
  // Core protections
  canvasProtect: true,
  webglProtect: true,
  audioProtect: true,
  navigatorProtect: true,
  // Advanced protections
  webrtcProtect: true,
  batteryProtect: true,
  bluetoothProtect: true,
  permissionsProtect: true,
  storageProtect: true,
  autoEvolve: true
};

// WASM module
let wasmModule = null;
let wasmExports = null;

// Languages
const LANGUAGES = [
  'en-US', 'en-GB', 'de-DE', 'fr-FR', 'es-ES',
  'it-IT', 'pt-BR', 'ru-RU', 'zh-CN', 'ja-JP'
];

// Version info
const CURRENT_VERSION = '2.0.0';
const UPDATE_CHECK_URL = 'https://raw.githubusercontent.com/gHashTag/trinity/main/extension/version.json';

// Initialize on install
browser.runtime.onInstalled.addListener(async (details) => {
  console.log('🔥 NeoDetect Anti-Detect installed (Firefox)');
  console.log(`φ² + 1/φ² = ${PHI * PHI + 1 / (PHI * PHI)} = TRINITY`);
  console.log(`Version: ${CURRENT_VERSION}`);
  
  if (details.reason === 'update') {
    console.log(`🔥 Updated from ${details.previousVersion} to ${CURRENT_VERSION}`);
  }
  
  // Load saved state
  const result = await browser.storage.local.get(['neodetectState']);
  if (result.neodetectState) {
    neodetectState = { ...neodetectState, ...result.neodetectState };
  }
  
  // Initialize WASM module
  await initWasm();
  
  // Generate initial profile if needed
  if (!neodetectState.profile) {
    await createProfile();
  }
  
  // Check for updates
  await checkForUpdates();
});

// Initialize on startup
browser.runtime.onStartup.addListener(async () => {
  console.log('🔥 NeoDetect starting (Firefox)...');
  
  const result = await browser.storage.local.get(['neodetectState']);
  if (result.neodetectState) {
    neodetectState = { ...neodetectState, ...result.neodetectState };
  }
  
  await initWasm();
  
  if (!neodetectState.profile) {
    await createProfile();
  }
});

// Initialize WASM module
async function initWasm() {
  try {
    const wasmUrl = browser.runtime.getURL('wasm/neodetect.wasm');
    const response = await fetch(wasmUrl);
    
    if (!response.ok) {
      console.log('🔥 NeoDetect WASM not found, using fallback');
      neodetectState.wasmReady = false;
      return;
    }
    
    const wasmBuffer = await response.arrayBuffer();
    const wasmResult = await WebAssembly.instantiate(wasmBuffer, {
      env: {}
    });
    
    wasmModule = wasmResult.module;
    wasmExports = wasmResult.instance.exports;
    
    // Initialize module
    const seed = Date.now();
    const result = wasmExports.wasm_neodetect_init(BigInt(seed));
    
    if (result === 0) {
      neodetectState.wasmReady = true;
      console.log('🔥 NeoDetect WASM initialized');
    }
  } catch (e) {
    console.log('🔥 WASM init failed:', e.message);
    neodetectState.wasmReady = false;
  }
}

// Read string from WASM memory
function readWasmString(ptr, maxLen = 1024) {
  if (!wasmExports || !wasmExports.memory) return '';
  const memory = new Uint8Array(wasmExports.memory.buffer);
  let str = '';
  for (let i = 0; i < maxLen; i++) {
    const char = memory[ptr + i];
    if (char === 0) break;
    str += String.fromCharCode(char);
  }
  return str;
}

// Create browser profile
async function createProfile(config = {}) {
  const seed = BigInt(config.seed || Date.now());
  const osType = config.osType ?? neodetectState.osType;
  const hwType = config.hwType ?? neodetectState.hwType;
  const gpuType = config.gpuType ?? neodetectState.gpuType;
  
  if (neodetectState.wasmReady && wasmExports) {
    // Use WASM
    wasmExports.wasm_create_profile(seed, osType, hwType, gpuType);
    
    // Get profile data
    wasmExports.wasm_get_platform();
    const platform = readWasmString(wasmExports.wasm_get_string_buffer());
    
    wasmExports.wasm_get_user_agent();
    const userAgent = readWasmString(wasmExports.wasm_get_string_buffer());
    
    wasmExports.wasm_get_gpu_vendor();
    const gpuVendor = readWasmString(wasmExports.wasm_get_string_buffer());
    
    wasmExports.wasm_get_gpu_renderer();
    const gpuRenderer = readWasmString(wasmExports.wasm_get_string_buffer());
    
    const langIndex = wasmExports.wasm_get_language_index();
    
    neodetectState.profile = {
      platform,
      userAgent,
      screenWidth: wasmExports.wasm_get_screen_width(),
      screenHeight: wasmExports.wasm_get_screen_height(),
      pixelRatio: wasmExports.wasm_get_pixel_ratio(),
      colorDepth: wasmExports.wasm_get_color_depth(),
      hardwareConcurrency: wasmExports.wasm_get_hardware_concurrency(),
      deviceMemory: wasmExports.wasm_get_device_memory(),
      timezoneOffset: wasmExports.wasm_get_timezone_offset(),
      language: LANGUAGES[langIndex] || 'en-US',
      languages: [LANGUAGES[langIndex] || 'en-US'],
      gpuVendor,
      gpuRenderer,
      canvasHash: wasmExports.wasm_get_canvas_hash().toString(),
      webglHash: wasmExports.wasm_get_webgl_hash().toString(),
      audioHash: wasmExports.wasm_get_audio_hash().toString()
    };
    
    neodetectState.similarity = wasmExports.wasm_get_similarity();
  } else {
    // Fallback profile
    neodetectState.profile = generateFallbackProfile(Number(seed), osType, hwType, gpuType);
    neodetectState.similarity = 0.7;
  }
  
  neodetectState.osType = osType;
  neodetectState.hwType = hwType;
  neodetectState.gpuType = gpuType;
  
  await saveState();
  await notifyAllTabs();
  
  return neodetectState.profile;
}

// Generate fallback profile (when WASM not available)
function generateFallbackProfile(seed, osType, hwType, gpuType) {
  const platforms = ['Win32', 'Win32', 'MacIntel', 'Linux x86_64'];
  const userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:125.0) Gecko/20100101 Firefox/125.0',
    'Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0'
  ];
  const gpuVendors = ['NVIDIA Corporation', 'NVIDIA Corporation', 'NVIDIA Corporation', 'AMD', 'AMD', 'Intel Inc.', 'Apple Inc.', 'Apple Inc.', 'Apple Inc.'];
  const gpuRenderers = ['NVIDIA GeForce RTX 3060/PCIe/SSE2', 'NVIDIA GeForce RTX 4070/PCIe/SSE2', 'NVIDIA GeForce RTX 4090/PCIe/SSE2', 'AMD Radeon RX 6700 XT', 'AMD Radeon RX 7900 XTX', 'Intel(R) UHD Graphics 770', 'Apple M1', 'Apple M2', 'Apple M3'];
  const screens = [[1920, 1080], [2560, 1440], [3840, 2160], [1366, 768], [2560, 1600]];
  const hwConfigs = [[6, 8], [8, 16], [16, 32], [6, 8], [8, 16], [16, 32], [8, 8], [8, 16], [8, 24]];
  
  const screenIdx = seed % screens.length;
  const langIdx = seed % LANGUAGES.length;
  
  return {
    platform: platforms[osType % platforms.length],
    userAgent: userAgents[osType % userAgents.length],
    screenWidth: screens[screenIdx][0],
    screenHeight: screens[screenIdx][1],
    pixelRatio: osType >= 2 ? 2.0 : 1.0,
    colorDepth: 24,
    hardwareConcurrency: hwConfigs[hwType % hwConfigs.length][0],
    deviceMemory: hwConfigs[hwType % hwConfigs.length][1],
    timezoneOffset: [-480, -420, -360, -300, -240, 0, 60, 120, 180, 480][seed % 10],
    language: LANGUAGES[langIdx],
    languages: [LANGUAGES[langIdx]],
    gpuVendor: gpuVendors[gpuType % gpuVendors.length],
    gpuRenderer: gpuRenderers[gpuType % gpuRenderers.length],
    canvasHash: (seed * 31337).toString(),
    webglHash: (seed * 65537).toString(),
    audioHash: (seed * 131071).toString()
  };
}

// Evolve fingerprint
async function evolveFingerprint(targetSimilarity = 0.85, useAI = false) {
  if (neodetectState.wasmReady && wasmExports) {
    let similarity;
    
    if (useAI) {
      similarity = wasmExports.wasm_ai_evolve(targetSimilarity);
    } else {
      similarity = wasmExports.wasm_evolve_fingerprint(targetSimilarity, 100);
    }
    
    neodetectState.similarity = similarity;
    neodetectState.lastEvolution = Date.now();
    
    // Update profile hashes
    if (neodetectState.profile) {
      neodetectState.profile.canvasHash = wasmExports.wasm_get_canvas_hash().toString();
      neodetectState.profile.webglHash = wasmExports.wasm_get_webgl_hash().toString();
      neodetectState.profile.audioHash = wasmExports.wasm_get_audio_hash().toString();
    }
  } else {
    // Fallback evolution
    neodetectState.similarity = Math.min(targetSimilarity, neodetectState.similarity + 0.05);
    neodetectState.lastEvolution = Date.now();
  }
  
  await saveState();
  await notifyAllTabs();
  
  return {
    similarity: neodetectState.similarity,
    profile: neodetectState.profile
  };
}

// Initialize AI model
async function initAIModel() {
  if (neodetectState.wasmReady && wasmExports) {
    const result = wasmExports.wasm_init_ai_model(256, 64, 2, BigInt(Date.now()));
    return result === 0;
  }
  return false;
}

// Message handler
browser.runtime.onMessage.addListener((message, sender) => {
  return handleMessage(message, sender);
});

async function handleMessage(message, sender) {
  switch (message.action) {
    case 'getState':
      return {
        ...neodetectState,
        wasmReady: neodetectState.wasmReady
      };
    
    case 'setState':
      neodetectState = { ...neodetectState, ...message.state };
      await saveState();
      await notifyAllTabs();
      return { success: true };
    
    case 'evolve':
      return await evolveFingerprint(message.targetSimilarity || 0.85, message.useAI || false);
    
    case 'aiEvolve':
      return await evolveFingerprint(message.targetSimilarity || 0.90, true);
    
    case 'reset':
      return await createProfile({
        seed: message.seed || Date.now(),
        osType: message.osType ?? neodetectState.osType,
        hwType: message.hwType ?? neodetectState.hwType,
        gpuType: message.gpuType ?? neodetectState.gpuType
      });
    
    case 'initAI':
      const aiResult = await initAIModel();
      return { success: aiResult };
    
    case 'getProfile':
      return neodetectState.profile;
    
    default:
      return { error: 'Unknown action' };
  }
}

// Save state to storage
async function saveState() {
  await browser.storage.local.set({ neodetectState });
}

// Notify all tabs of state change
async function notifyAllTabs() {
  const tabs = await browser.tabs.query({});
  for (const tab of tabs) {
    try {
      await browser.tabs.sendMessage(tab.id, {
        action: 'profileUpdated',
        profile: neodetectState.profile,
        similarity: neodetectState.similarity,
        wasmReady: neodetectState.wasmReady
      });
    } catch (e) {
      // Tab might not have content script
    }
  }
}

// Check for updates
async function checkForUpdates() {
  try {
    const response = await fetch(UPDATE_CHECK_URL, { cache: 'no-store' });
    if (!response.ok) return;
    
    const data = await response.json();
    if (data.version && data.version !== CURRENT_VERSION) {
      console.log(`🔥 New version available: ${data.version}`);
      neodetectState.updateAvailable = data.version;
      neodetectState.updateUrl = data.downloadUrl || 'https://github.com/gHashTag/trinity/releases';
      await saveState();
      
      browser.browserAction.setBadgeText({ text: '!' });
      browser.browserAction.setBadgeBackgroundColor({ color: '#f39c12' });
    }
  } catch (e) {
    console.log('Update check failed:', e.message);
  }
}

// Schedule update check
browser.alarms.create('updateCheck', { periodInMinutes: 1440 });

// Auto-evolve check
browser.alarms.create('autoEvolve', { periodInMinutes: 30 });

browser.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === 'updateCheck') {
    await checkForUpdates();
  } else if (alarm.name === 'autoEvolve') {
    const result = await browser.storage.local.get(['neodetectState']);
    if (result.neodetectState?.autoEvolve) {
      console.log('🔥 Auto-evolving fingerprint...');
      await evolveFingerprint(0.85);
    }
  }
});

console.log('🔥 NeoDetect background script started (Firefox)');
