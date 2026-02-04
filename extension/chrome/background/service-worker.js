// Firebird Background Service Worker
// φ² + 1/φ² = 3 = TRINITY
// CPU Inference enabled for AI-powered anti-detect

const PHI = 1.6180339887;
const TRINITY = 3.0;

// Firebird state
let firebirdState = {
  enabled: true,
  similarity: 0.85,
  fingerprint: null,
  lastEvolution: null,
  aiMode: false,
  inferenceReady: false
};

// WASM inference module
let wasmModule = null;
let wasmExports = null;

// Inference configuration
const INFERENCE_CONFIG = {
  vocabSize: 256,    // Small vocab for browser
  hiddenDim: 64,     // Tiny model
  numLayers: 2,      // 2 layers
  maxTokens: 100,
  temperature: 0.7
};

// Initialize on install
chrome.runtime.onInstalled.addListener(async () => {
  console.log('🔥 Firebird Anti-Detect installed');
  console.log(`φ² + 1/φ² = ${PHI * PHI + 1 / (PHI * PHI)} = TRINITY`);
  
  // Load saved state
  const result = await chrome.storage.local.get(['firebirdState']);
  if (result.firebirdState) {
    firebirdState = { ...firebirdState, ...result.firebirdState };
  }
  
  // Generate initial fingerprint
  if (!firebirdState.fingerprint) {
    firebirdState.fingerprint = generateFingerprint();
    await saveState();
  }
  
  // Initialize WASM inference module
  await initInference();
});

// Initialize WASM inference
async function initInference() {
  try {
    const wasmUrl = chrome.runtime.getURL('wasm/firebird.wasm');
    const response = await fetch(wasmUrl);
    
    if (!response.ok) {
      console.log('🔥 WASM module not found, using JS fallback');
      firebirdState.inferenceReady = false;
      return;
    }
    
    const wasmBuffer = await response.arrayBuffer();
    const wasmResult = await WebAssembly.instantiate(wasmBuffer, {
      env: {
        // Memory imports if needed
      }
    });
    
    wasmModule = wasmResult.module;
    wasmExports = wasmResult.instance.exports;
    
    // Initialize inference model
    const seed = Date.now();
    const result = wasmExports.wasm_init_inference(
      INFERENCE_CONFIG.vocabSize,
      INFERENCE_CONFIG.hiddenDim,
      INFERENCE_CONFIG.numLayers,
      BigInt(seed)
    );
    
    if (result === 0) {
      firebirdState.inferenceReady = true;
      console.log('🔥 CPU Inference initialized');
    }
  } catch (e) {
    console.log('🔥 WASM init failed, using JS fallback:', e.message);
    firebirdState.inferenceReady = false;
  }
}

// JavaScript fallback inference (when WASM not available)
function jsInference(prompt, maxTokens = 100) {
  // Simple Markov-like generation using fingerprint as seed
  const seed = firebirdState.fingerprint?.trits || [];
  const tokens = [];
  
  for (let i = 0; i < maxTokens; i++) {
    // Generate pseudo-random token based on seed
    const idx = (i * 31337 + (seed[i % seed.length] || 0) + 128) % 256;
    tokens.push(idx);
    
    // Stop on "EOS" (token 0)
    if (idx === 0) break;
  }
  
  return {
    tokens,
    latency: maxTokens * 2, // ~2ms per token in JS
    source: 'js-fallback'
  };
}

// Generate text using inference
async function generateText(prompt, config = {}) {
  const maxTokens = config.maxTokens || INFERENCE_CONFIG.maxTokens;
  const temperature = config.temperature || INFERENCE_CONFIG.temperature;
  
  if (firebirdState.inferenceReady && wasmExports) {
    // Use WASM inference
    const startToken = prompt.charCodeAt(0) % INFERENCE_CONFIG.vocabSize;
    const count = wasmExports.wasm_generate(maxTokens, temperature, startToken);
    const latency = wasmExports.wasm_get_inference_latency();
    
    return {
      tokensGenerated: count,
      latency,
      source: 'wasm'
    };
  } else {
    // Use JS fallback
    return jsInference(prompt, maxTokens);
  }
}

// Generate fingerprint variation using AI
async function generateAIVariation(targetSimilarity = 0.85) {
  if (firebirdState.inferenceReady && wasmExports) {
    const similarity = wasmExports.wasm_generate_variation(targetSimilarity);
    return { similarity, source: 'wasm-ai' };
  } else {
    // Fallback to regular evolution
    return await evolveFingerprint(targetSimilarity);
  }
}

// Message handler
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  handleMessage(message, sender).then(sendResponse);
  return true; // Keep channel open for async response
});

async function handleMessage(message, sender) {
  switch (message.action) {
    case 'evolve':
      return await evolveFingerprint(message.targetSimilarity || 0.85);
    
    case 'getState':
      return firebirdState;
    
    case 'getFingerprint':
      return firebirdState.fingerprint;
    
    case 'setState':
      firebirdState = { ...firebirdState, ...message.state };
      await saveState();
      return { success: true };
    
    // AI Inference actions
    case 'generate':
      return await generateText(message.prompt || '', message.config || {});
    
    case 'aiEvolve':
      return await generateAIVariation(message.targetSimilarity || 0.85);
    
    case 'toggleAI':
      firebirdState.aiMode = !firebirdState.aiMode;
      await saveState();
      return { aiMode: firebirdState.aiMode, inferenceReady: firebirdState.inferenceReady };
    
    case 'getAIStatus':
      return { 
        aiMode: firebirdState.aiMode, 
        inferenceReady: firebirdState.inferenceReady,
        config: INFERENCE_CONFIG
      };
    
    default:
      return { error: 'Unknown action' };
  }
}

// Generate ternary fingerprint vector
function generateFingerprint(dim = 1000) {
  const trits = new Int8Array(dim);
  for (let i = 0; i < dim; i++) {
    const r = Math.random();
    if (r < 0.333) trits[i] = -1;
    else if (r < 0.666) trits[i] = 0;
    else trits[i] = 1;
  }
  return {
    trits: Array.from(trits),
    dim: dim,
    created: Date.now()
  };
}

// Evolve fingerprint towards human-like pattern
async function evolveFingerprint(targetSimilarity) {
  const dim = firebirdState.fingerprint?.dim || 1000;
  const humanPattern = generateHumanPattern(dim);
  
  let currentFp = firebirdState.fingerprint?.trits || generateFingerprint(dim).trits;
  let similarity = cosineSimilarity(currentFp, humanPattern);
  
  const maxGenerations = 50;
  const guideRate = 0.9;
  
  for (let gen = 0; gen < maxGenerations; gen++) {
    if (similarity >= targetSimilarity) break;
    
    // Guided mutation: move towards human pattern
    const newFp = new Int8Array(dim);
    for (let i = 0; i < dim; i++) {
      if (Math.random() < guideRate) {
        newFp[i] = humanPattern[i];
      } else if (Math.random() < 0.3) {
        newFp[i] = currentFp[i];
      } else {
        // Random trit
        const r = Math.random();
        if (r < 0.333) newFp[i] = -1;
        else if (r < 0.666) newFp[i] = 0;
        else newFp[i] = 1;
      }
    }
    
    const newSim = cosineSimilarity(Array.from(newFp), humanPattern);
    if (newSim > similarity) {
      currentFp = Array.from(newFp);
      similarity = newSim;
    }
  }
  
  firebirdState.fingerprint = {
    trits: currentFp,
    dim: dim,
    created: Date.now()
  };
  firebirdState.similarity = similarity;
  firebirdState.lastEvolution = Date.now();
  
  await saveState();
  
  // Notify all tabs
  notifyAllTabs();
  
  return {
    success: true,
    similarity: similarity,
    generations: maxGenerations
  };
}

// Generate human-like pattern (seeded for consistency)
function generateHumanPattern(dim) {
  const pattern = new Int8Array(dim);
  // Use φ-based seed for reproducibility
  let seed = PHI * 1000000;
  
  for (let i = 0; i < dim; i++) {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    const r = (seed / 2147483648);
    if (r < 0.333) pattern[i] = -1;
    else if (r < 0.666) pattern[i] = 0;
    else pattern[i] = 1;
  }
  
  return Array.from(pattern);
}

// Cosine similarity for ternary vectors
function cosineSimilarity(a, b) {
  let dot = 0;
  let normA = 0;
  let normB = 0;
  
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  
  if (normA === 0 || normB === 0) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

// Save state to storage
async function saveState() {
  await chrome.storage.local.set({ firebirdState });
}

// Notify all tabs of state change
async function notifyAllTabs() {
  const tabs = await chrome.tabs.query({});
  for (const tab of tabs) {
    try {
      await chrome.tabs.sendMessage(tab.id, {
        action: 'fingerprintUpdated',
        fingerprint: firebirdState.fingerprint,
        similarity: firebirdState.similarity
      });
    } catch (e) {
      // Tab might not have content script
    }
  }
}

// Periodic evolution check (auto-evolve)
chrome.alarms.create('autoEvolve', { periodInMinutes: 30 });

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === 'autoEvolve') {
    const result = await chrome.storage.local.get(['firebirdState']);
    if (result.firebirdState?.autoEvolve) {
      console.log('🔥 Auto-evolving fingerprint...');
      await evolveFingerprint(0.85);
    }
  }
});

console.log('🔥 Firebird service worker started');
