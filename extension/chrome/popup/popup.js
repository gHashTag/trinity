// Firebird Popup Controller
// φ² + 1/φ² = 3 = TRINITY

const PHI = 1.6180339887;

// DOM Elements
const protectionStatus = document.getElementById('protection-status');
const similarityValue = document.getElementById('similarity-value');
const similarityBar = document.getElementById('similarity-bar');
const evolveBtn = document.getElementById('evolve-btn');
const resetBtn = document.getElementById('reset-btn');
const autoEvolve = document.getElementById('auto-evolve');
const canvasProtect = document.getElementById('canvas-protect');
const webglProtect = document.getElementById('webgl-protect');

// State
let state = {
  enabled: true,
  similarity: 0.85,
  autoEvolve: true,
  canvasProtect: true,
  webglProtect: true,
  evolving: false
};

// Load state from storage
async function loadState() {
  try {
    const result = await chrome.storage.local.get(['firebirdState']);
    if (result.firebirdState) {
      state = { ...state, ...result.firebirdState };
    }
    updateUI();
  } catch (e) {
    console.error('Failed to load state:', e);
  }
}

// Save state to storage
async function saveState() {
  try {
    await chrome.storage.local.set({ firebirdState: state });
  } catch (e) {
    console.error('Failed to save state:', e);
  }
}

// Update UI based on state
function updateUI() {
  // Protection status
  if (state.enabled) {
    protectionStatus.textContent = 'Active';
    protectionStatus.className = 'status-value active';
  } else {
    protectionStatus.textContent = 'Inactive';
    protectionStatus.className = 'status-value inactive';
  }
  
  // Similarity
  similarityValue.textContent = state.similarity.toFixed(2);
  similarityBar.style.width = `${state.similarity * 100}%`;
  
  // Toggles
  autoEvolve.checked = state.autoEvolve;
  canvasProtect.checked = state.canvasProtect;
  webglProtect.checked = state.webglProtect;
  
  // Evolve button
  evolveBtn.disabled = state.evolving;
  evolveBtn.textContent = state.evolving ? '🧬 Evolving...' : '🧬 Evolve Fingerprint';
}

// Evolve fingerprint
async function evolveFingerprint() {
  if (state.evolving) return;
  
  state.evolving = true;
  updateUI();
  
  try {
    // Send message to background worker
    const response = await chrome.runtime.sendMessage({ 
      action: 'evolve',
      targetSimilarity: 0.85
    });
    
    if (response && response.similarity) {
      state.similarity = response.similarity;
    } else {
      // Simulate evolution for demo
      await simulateEvolution();
    }
  } catch (e) {
    console.error('Evolution failed:', e);
    // Simulate for demo
    await simulateEvolution();
  }
  
  state.evolving = false;
  await saveState();
  updateUI();
  
  // Notify content scripts
  notifyContentScripts();
}

// Simulate evolution (demo mode without WASM)
async function simulateEvolution() {
  const steps = 10;
  const targetSim = 0.80 + Math.random() * 0.05; // 0.80-0.85
  const startSim = state.similarity;
  
  for (let i = 1; i <= steps; i++) {
    await new Promise(r => setTimeout(r, 50));
    // φ-spiral convergence
    const progress = 1 - Math.pow(1 - i/steps, PHI);
    state.similarity = startSim + (targetSim - startSim) * progress;
    updateUI();
  }
  
  state.similarity = targetSim;
}

// Reset fingerprint
async function resetFingerprint() {
  state.similarity = 0.70;
  await saveState();
  updateUI();
  notifyContentScripts();
}

// Notify content scripts of state change
async function notifyContentScripts() {
  try {
    const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tabs[0]) {
      await chrome.tabs.sendMessage(tabs[0].id, {
        action: 'updateState',
        state: {
          enabled: state.enabled,
          similarity: state.similarity,
          canvasProtect: state.canvasProtect,
          webglProtect: state.webglProtect
        }
      });
    }
  } catch (e) {
    // Tab might not have content script
  }
}

// Event listeners
evolveBtn.addEventListener('click', evolveFingerprint);
resetBtn.addEventListener('click', resetFingerprint);

autoEvolve.addEventListener('change', async (e) => {
  state.autoEvolve = e.target.checked;
  await saveState();
});

canvasProtect.addEventListener('change', async (e) => {
  state.canvasProtect = e.target.checked;
  await saveState();
  notifyContentScripts();
});

webglProtect.addEventListener('change', async (e) => {
  state.webglProtect = e.target.checked;
  await saveState();
  notifyContentScripts();
});

// Initialize
loadState();
