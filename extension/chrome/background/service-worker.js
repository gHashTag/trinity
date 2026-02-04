// Firebird Background Service Worker
// φ² + 1/φ² = 3 = TRINITY

const PHI = 1.6180339887;
const TRINITY = 3.0;

// Firebird state
let firebirdState = {
  enabled: true,
  similarity: 0.85,
  fingerprint: null,
  lastEvolution: null
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
});

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
