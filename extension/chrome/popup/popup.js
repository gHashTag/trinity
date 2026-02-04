// NeoDetect Popup Controller
// Uses WASM module for antidetect functionality
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
const audioProtect = document.getElementById('audio-protect');
const navigatorProtect = document.getElementById('navigator-protect');
const webrtcProtect = document.getElementById('webrtc-protect');
const batteryProtect = document.getElementById('battery-protect');
const bluetoothProtect = document.getElementById('bluetooth-protect');
const permissionsProtect = document.getElementById('permissions-protect');
const storageProtect = document.getElementById('storage-protect');
const aiMode = document.getElementById('ai-mode');
const aiEvolveBtn = document.getElementById('ai-evolve-btn');
const wasmBadge = document.getElementById('wasm-badge');

// Profile config selectors
const osSelect = document.getElementById('os-select');
const hwSelect = document.getElementById('hw-select');
const gpuSelect = document.getElementById('gpu-select');

// Profile management elements
const profileList = document.getElementById('profile-list');
const profileEmpty = document.getElementById('profile-empty');
const profileCount = document.getElementById('profile-count');
const saveProfileBtn = document.getElementById('save-profile-btn');
const importBtn = document.getElementById('import-btn');
const exportBtn = document.getElementById('export-btn');
const importFile = document.getElementById('import-file');
const saveModal = document.getElementById('save-modal');
const profileNameInput = document.getElementById('profile-name-input');
const modalCancel = document.getElementById('modal-cancel');
const modalSave = document.getElementById('modal-save');

// Profile info displays
const infoPlatform = document.getElementById('info-platform');
const infoScreen = document.getElementById('info-screen');
const infoGpu = document.getElementById('info-gpu');
const infoCores = document.getElementById('info-cores');

// Detection risk
const detectionRisk = document.getElementById('detection-risk');
const riskIndicator = document.getElementById('risk-indicator');
const riskText = document.getElementById('risk-text');

// State
let state = {
  enabled: true,
  similarity: 0.85,
  autoEvolve: true,
  canvasProtect: true,
  webglProtect: true,
  audioProtect: true,
  navigatorProtect: true,
  webrtcProtect: true,
  batteryProtect: true,
  bluetoothProtect: true,
  permissionsProtect: true,
  storageProtect: true,
  aiMode: false,
  wasmReady: false,
  evolving: false,
  profile: null,
  osType: 0,
  hwType: 1,
  gpuType: 1,
  activeProfileId: null,
  activePreset: 'balanced'
};

// Saved profiles
let savedProfiles = [];

// Profile icons and colors
const PROFILE_ICONS = ['🔴', '🟠', '🟡', '🟢', '🔵', '🟣', '⚫', '🔶'];
const OS_LABELS = ['Windows 10', 'Windows 11', 'macOS', 'Linux'];
const HW_LABELS = ['Intel i5', 'Intel i7', 'Intel i9', 'Ryzen 5', 'Ryzen 7', 'Ryzen 9', 'Apple M1', 'Apple M2', 'Apple M3'];

// Protection presets
const PRESETS = {
  paranoid: {
    name: 'Paranoid',
    description: 'Maximum protection - may break some sites',
    canvasProtect: true,
    webglProtect: true,
    audioProtect: true,
    navigatorProtect: true,
    webrtcProtect: true,
    batteryProtect: true,
    bluetoothProtect: true,
    permissionsProtect: true,
    storageProtect: true,
    autoEvolve: true
  },
  balanced: {
    name: 'Balanced',
    description: 'Recommended settings for most users',
    canvasProtect: true,
    webglProtect: true,
    audioProtect: true,
    navigatorProtect: true,
    webrtcProtect: true,
    batteryProtect: true,
    bluetoothProtect: true,
    permissionsProtect: false,
    storageProtect: false,
    autoEvolve: true
  },
  minimal: {
    name: 'Minimal',
    description: 'Basic protection - maximum compatibility',
    canvasProtect: true,
    webglProtect: true,
    audioProtect: false,
    navigatorProtect: true,
    webrtcProtect: false,
    batteryProtect: false,
    bluetoothProtect: false,
    permissionsProtect: false,
    storageProtect: false,
    autoEvolve: false
  }
};

// Preset elements
const presetParanoid = document.getElementById('preset-paranoid');
const presetBalanced = document.getElementById('preset-balanced');
const presetMinimal = document.getElementById('preset-minimal');
const presetDescription = document.getElementById('preset-description');

// Load state from storage
async function loadState() {
  try {
    const result = await chrome.storage.local.get(['neodetectState', 'savedProfiles']);
    if (result.neodetectState) {
      state = { ...state, ...result.neodetectState };
    }
    if (result.savedProfiles) {
      savedProfiles = result.savedProfiles;
    }
    
    // Get WASM status from background
    const response = await chrome.runtime.sendMessage({ action: 'getState' });
    if (response) {
      state.wasmReady = response.wasmReady;
      state.profile = response.profile;
      state.similarity = response.similarity || state.similarity;
    }
    
    updateUI();
    renderProfileList();
    
    // Detect and show current preset
    const currentPreset = state.activePreset || detectCurrentPreset() || 'balanced';
    updatePresetButtons(currentPreset);
  } catch (e) {
    console.error('Failed to load state:', e);
  }
}

// Save profiles to storage
async function saveProfiles() {
  await chrome.storage.local.set({ savedProfiles });
}

// Generate unique ID
function generateId() {
  return Date.now().toString(36) + Math.random().toString(36).substr(2, 5);
}

// Render profile list
function renderProfileList() {
  if (!profileList) return;
  
  // Update count
  if (profileCount) {
    profileCount.textContent = `(${savedProfiles.length})`;
  }
  
  // Show empty state or list
  if (savedProfiles.length === 0) {
    if (profileEmpty) profileEmpty.style.display = 'block';
    profileList.innerHTML = '';
    profileList.appendChild(profileEmpty);
    return;
  }
  
  if (profileEmpty) profileEmpty.style.display = 'none';
  
  // Sort by last used
  const sorted = [...savedProfiles].sort((a, b) => (b.lastUsed || 0) - (a.lastUsed || 0));
  
  profileList.innerHTML = sorted.map(profile => {
    const isActive = profile.id === state.activeProfileId;
    const osLabel = OS_LABELS[profile.osType] || 'Unknown';
    const hwLabel = HW_LABELS[profile.hwType] || 'Unknown';
    const icon = profile.icon || PROFILE_ICONS[savedProfiles.indexOf(profile) % PROFILE_ICONS.length];
    
    return `
      <div class="profile-item ${isActive ? 'active' : ''}" data-id="${profile.id}">
        <span class="profile-icon">${icon}</span>
        <div class="profile-details">
          <div class="profile-name">${escapeHtml(profile.name)}</div>
          <div class="profile-meta">${osLabel} • ${hwLabel}</div>
        </div>
        <button class="profile-delete" data-id="${profile.id}" title="Delete">✕</button>
      </div>
    `;
  }).join('');
  
  // Add click handlers
  profileList.querySelectorAll('.profile-item').forEach(item => {
    item.addEventListener('click', (e) => {
      if (!e.target.classList.contains('profile-delete')) {
        loadProfile(item.dataset.id);
      }
    });
  });
  
  profileList.querySelectorAll('.profile-delete').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      deleteProfile(btn.dataset.id);
    });
  });
}

// Escape HTML
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Save current profile
async function saveCurrentProfile(name) {
  const profile = {
    id: generateId(),
    name: name || `Profile ${savedProfiles.length + 1}`,
    createdAt: Date.now(),
    lastUsed: Date.now(),
    osType: state.osType,
    hwType: state.hwType,
    gpuType: state.gpuType,
    seed: state.profile?.seed || Date.now(),
    similarity: state.similarity,
    icon: PROFILE_ICONS[savedProfiles.length % PROFILE_ICONS.length]
  };
  
  savedProfiles.push(profile);
  state.activeProfileId = profile.id;
  
  await saveProfiles();
  await saveState();
  renderProfileList();
}

// Load profile
async function loadProfile(id) {
  const profile = savedProfiles.find(p => p.id === id);
  if (!profile) return;
  
  // Update last used
  profile.lastUsed = Date.now();
  
  // Apply profile settings
  state.osType = profile.osType;
  state.hwType = profile.hwType;
  state.gpuType = profile.gpuType;
  state.activeProfileId = profile.id;
  
  // Update selectors
  if (osSelect) osSelect.value = profile.osType;
  if (hwSelect) hwSelect.value = profile.hwType;
  if (gpuSelect) gpuSelect.value = profile.gpuType;
  
  // Create new fingerprint with profile settings
  await chrome.runtime.sendMessage({
    action: 'reset',
    osType: profile.osType,
    hwType: profile.hwType,
    gpuType: profile.gpuType,
    seed: profile.seed
  });
  
  await saveProfiles();
  await saveState();
  
  // Reload state to get new profile
  await loadState();
}

// Delete profile
async function deleteProfile(id) {
  const index = savedProfiles.findIndex(p => p.id === id);
  if (index === -1) return;
  
  savedProfiles.splice(index, 1);
  
  if (state.activeProfileId === id) {
    state.activeProfileId = null;
  }
  
  await saveProfiles();
  await saveState();
  renderProfileList();
}

// Export profiles
function exportProfiles() {
  if (savedProfiles.length === 0) {
    alert('No profiles to export');
    return;
  }
  
  const exportData = {
    version: 1,
    exportedAt: Date.now(),
    profiles: savedProfiles
  };
  
  const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  
  const a = document.createElement('a');
  a.href = url;
  a.download = `neodetect-profiles-${new Date().toISOString().split('T')[0]}.json`;
  a.click();
  
  URL.revokeObjectURL(url);
}

// Import profiles
async function importProfiles(file) {
  try {
    const text = await file.text();
    const data = JSON.parse(text);
    
    if (!data.profiles || !Array.isArray(data.profiles)) {
      alert('Invalid profile file format');
      return;
    }
    
    // Add imported profiles with new IDs
    let imported = 0;
    for (const profile of data.profiles) {
      // Check for duplicate names
      const existingName = savedProfiles.find(p => p.name === profile.name);
      if (existingName) {
        profile.name = `${profile.name} (imported)`;
      }
      
      profile.id = generateId();
      profile.lastUsed = Date.now();
      savedProfiles.push(profile);
      imported++;
    }
    
    await saveProfiles();
    renderProfileList();
    
    alert(`Imported ${imported} profile(s)`);
  } catch (e) {
    alert('Failed to import profiles: ' + e.message);
  }
}

// Save state to storage
async function saveState() {
  try {
    await chrome.storage.local.set({ neodetectState: state });
    // Notify background
    await chrome.runtime.sendMessage({ action: 'setState', state });
  } catch (e) {
    console.error('Failed to save state:', e);
  }
}

// Update UI based on state
function updateUI() {
  // Protection status
  if (state.enabled) {
    protectionStatus.textContent = state.wasmReady ? 'Active (WASM)' : 'Active';
    protectionStatus.className = 'status-value active';
  } else {
    protectionStatus.textContent = 'Inactive';
    protectionStatus.className = 'status-value inactive';
  }
  
  // Similarity
  similarityValue.textContent = state.similarity.toFixed(2);
  similarityBar.style.width = `${state.similarity * 100}%`;
  
  // Detection risk
  updateDetectionRisk(state.similarity);
  
  // Core protection toggles
  if (autoEvolve) autoEvolve.checked = state.autoEvolve;
  if (canvasProtect) canvasProtect.checked = state.canvasProtect;
  if (webglProtect) webglProtect.checked = state.webglProtect;
  if (audioProtect) audioProtect.checked = state.audioProtect;
  if (navigatorProtect) navigatorProtect.checked = state.navigatorProtect;
  
  // Advanced protection toggles
  if (webrtcProtect) webrtcProtect.checked = state.webrtcProtect;
  if (batteryProtect) batteryProtect.checked = state.batteryProtect;
  if (bluetoothProtect) bluetoothProtect.checked = state.bluetoothProtect;
  if (permissionsProtect) permissionsProtect.checked = state.permissionsProtect;
  if (storageProtect) storageProtect.checked = state.storageProtect;
  
  if (aiMode) aiMode.checked = state.aiMode;
  
  // Profile config selectors
  if (osSelect) osSelect.value = state.osType;
  if (hwSelect) hwSelect.value = state.hwType;
  if (gpuSelect) gpuSelect.value = state.gpuType;
  
  // WASM badge
  if (wasmBadge) {
    if (state.wasmReady) {
      wasmBadge.innerHTML = '<span>●</span> WASM Ready';
      wasmBadge.className = 'wasm-badge';
    } else {
      wasmBadge.innerHTML = '<span>●</span> JS Fallback';
      wasmBadge.className = 'wasm-badge fallback';
    }
  }
  
  // AI Evolve button
  if (aiEvolveBtn) {
    aiEvolveBtn.disabled = !state.aiMode || state.evolving;
  }
  
  // Evolve button
  if (evolveBtn) {
    evolveBtn.disabled = state.evolving;
    evolveBtn.textContent = state.evolving ? '🧬 ...' : '🧬 Evolve';
  }
  
  // Show profile info if available
  if (state.profile) {
    showProfileInfo(state.profile);
  }
}

// Update detection risk indicator
function updateDetectionRisk(similarity) {
  if (!detectionRisk || !riskIndicator || !riskText) return;
  
  let riskLevel, riskMessage;
  
  if (similarity >= 0.85) {
    riskLevel = 'low';
    riskMessage = 'Low detection risk';
  } else if (similarity >= 0.70) {
    riskLevel = 'medium';
    riskMessage = 'Medium detection risk';
  } else {
    riskLevel = 'high';
    riskMessage = 'High detection risk - Evolve recommended';
  }
  
  detectionRisk.className = `detection-risk ${riskLevel}`;
  riskIndicator.className = `risk-indicator ${riskLevel}`;
  riskText.textContent = riskMessage;
}

// Show profile information
function showProfileInfo(profile) {
  if (infoPlatform) {
    infoPlatform.textContent = profile.platform || 'N/A';
  }
  if (infoScreen) {
    infoScreen.textContent = `${profile.screenWidth || '?'}x${profile.screenHeight || '?'}`;
  }
  if (infoGpu) {
    // Shorten GPU name for display
    const gpu = profile.gpuRenderer || 'N/A';
    infoGpu.textContent = gpu.replace('NVIDIA GeForce ', '').replace('/PCIe/SSE2', '');
  }
  if (infoCores) {
    infoCores.textContent = profile.hardwareConcurrency || '?';
  }
}

// Evolve fingerprint
async function evolveFingerprint() {
  if (state.evolving) return;
  
  state.evolving = true;
  updateUI();
  
  try {
    const response = await chrome.runtime.sendMessage({ 
      action: 'evolve',
      targetSimilarity: 0.85,
      useAI: state.aiMode
    });
    
    if (response && response.similarity) {
      state.similarity = response.similarity;
      state.profile = response.profile;
    }
  } catch (e) {
    console.error('Evolution failed:', e);
  }
  
  state.evolving = false;
  await saveState();
  updateUI();
}

// Reset fingerprint
async function resetFingerprint() {
  try {
    const response = await chrome.runtime.sendMessage({ 
      action: 'reset',
      osType: state.osType,
      hwType: state.hwType,
      gpuType: state.gpuType
    });
    
    if (response) {
      state.similarity = response.similarity || 0.7;
      state.profile = response.profile;
    }
  } catch (e) {
    console.error('Reset failed:', e);
  }
  
  await saveState();
  updateUI();
}

// Event listeners
if (evolveBtn) {
  evolveBtn.addEventListener('click', evolveFingerprint);
}

if (resetBtn) {
  resetBtn.addEventListener('click', resetFingerprint);
}

if (autoEvolve) {
  autoEvolve.addEventListener('change', async (e) => {
    state.autoEvolve = e.target.checked;
    await saveState();
  });
}

if (canvasProtect) {
  canvasProtect.addEventListener('change', async (e) => {
    state.canvasProtect = e.target.checked;
    state.activePreset = null; // Custom settings
    updatePresetButtons(detectCurrentPreset());
    await saveState();
    notifyContentScripts();
  });
}

// Helper to handle toggle changes
async function handleToggleChange(property, value) {
  state[property] = value;
  state.activePreset = null;
  updatePresetButtons(detectCurrentPreset());
  await saveState();
  notifyContentScripts();
}

if (webglProtect) {
  webglProtect.addEventListener('change', (e) => handleToggleChange('webglProtect', e.target.checked));
}

if (audioProtect) {
  audioProtect.addEventListener('change', (e) => handleToggleChange('audioProtect', e.target.checked));
}

if (navigatorProtect) {
  navigatorProtect.addEventListener('change', (e) => handleToggleChange('navigatorProtect', e.target.checked));
}

// Advanced protection toggles
if (webrtcProtect) {
  webrtcProtect.addEventListener('change', (e) => handleToggleChange('webrtcProtect', e.target.checked));
}

if (batteryProtect) {
  batteryProtect.addEventListener('change', (e) => handleToggleChange('batteryProtect', e.target.checked));
}

if (bluetoothProtect) {
  bluetoothProtect.addEventListener('change', (e) => handleToggleChange('bluetoothProtect', e.target.checked));
}

if (permissionsProtect) {
  permissionsProtect.addEventListener('change', (e) => handleToggleChange('permissionsProtect', e.target.checked));
}

if (storageProtect) {
  storageProtect.addEventListener('change', (e) => handleToggleChange('storageProtect', e.target.checked));
}

// AI Mode toggle
if (aiMode) {
  aiMode.addEventListener('change', async (e) => {
    state.aiMode = e.target.checked;
    
    if (state.aiMode) {
      // Initialize AI model
      await chrome.runtime.sendMessage({ action: 'initAI' });
    }
    
    await saveState();
    updateUI();
  });
}

// AI-powered evolution
if (aiEvolveBtn) {
  aiEvolveBtn.addEventListener('click', async () => {
    if (state.evolving) return;
    
    state.evolving = true;
    updateUI();
    
    try {
      const response = await chrome.runtime.sendMessage({ 
        action: 'aiEvolve',
        targetSimilarity: 0.90
      });
      
      if (response && response.similarity) {
        state.similarity = response.similarity;
        state.profile = response.profile;
      }
    } catch (e) {
      console.error('AI evolution failed:', e);
    }
    
    state.evolving = false;
    await saveState();
    updateUI();
  });
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
          webglProtect: state.webglProtect,
          audioProtect: state.audioProtect,
          navigatorProtect: state.navigatorProtect,
          webrtcProtect: state.webrtcProtect,
          batteryProtect: state.batteryProtect,
          bluetoothProtect: state.bluetoothProtect,
          permissionsProtect: state.permissionsProtect,
          storageProtect: state.storageProtect,
          profile: state.profile,
          wasmReady: state.wasmReady
        }
      });
    }
  } catch (e) {
    // Tab might not have content script
  }
}

// Check for update notification
async function checkUpdateNotification() {
  try {
    const result = await chrome.storage.local.get(['neodetectState']);
    if (result.neodetectState?.updateAvailable) {
      const header = document.querySelector('.header');
      if (header) {
        const updateBanner = document.createElement('div');
        updateBanner.style.cssText = `
          background: linear-gradient(135deg, #f39c12, #e67e22);
          color: #000;
          padding: 8px 12px;
          border-radius: 6px;
          margin-bottom: 12px;
          font-size: 12px;
          text-align: center;
          cursor: pointer;
        `;
        updateBanner.innerHTML = `🔥 Update available: v${result.neodetectState.updateAvailable} <u>Download</u>`;
        updateBanner.onclick = () => {
          chrome.tabs.create({ url: result.neodetectState.updateUrl || 'https://github.com/gHashTag/trinity/releases' });
        };
        header.after(updateBanner);
      }
    }
  } catch (e) {
    console.log('Update check failed:', e);
  }
}

// OS/Hardware selector event listeners
if (osSelect) {
  osSelect.addEventListener('change', async (e) => {
    state.osType = parseInt(e.target.value);
    await saveState();
    // Auto-create new profile with selected OS
    await resetFingerprint();
  });
}

if (hwSelect) {
  hwSelect.addEventListener('change', async (e) => {
    state.hwType = parseInt(e.target.value);
    await saveState();
    await resetFingerprint();
  });
}

if (gpuSelect) {
  gpuSelect.addEventListener('change', async (e) => {
    state.gpuType = parseInt(e.target.value);
    await saveState();
    await resetFingerprint();
  });
}

// Apply preset
async function applyPreset(presetName) {
  const preset = PRESETS[presetName];
  if (!preset) return;
  
  // Apply all protection settings from preset
  state.canvasProtect = preset.canvasProtect;
  state.webglProtect = preset.webglProtect;
  state.audioProtect = preset.audioProtect;
  state.navigatorProtect = preset.navigatorProtect;
  state.webrtcProtect = preset.webrtcProtect;
  state.batteryProtect = preset.batteryProtect;
  state.bluetoothProtect = preset.bluetoothProtect;
  state.permissionsProtect = preset.permissionsProtect;
  state.storageProtect = preset.storageProtect;
  state.autoEvolve = preset.autoEvolve;
  state.activePreset = presetName;
  
  // Update UI
  updateUI();
  updatePresetButtons(presetName);
  
  // Save and notify
  await saveState();
  notifyContentScripts();
}

// Update preset button states
function updatePresetButtons(activePreset) {
  const presets = [
    { el: presetParanoid, name: 'paranoid' },
    { el: presetBalanced, name: 'balanced' },
    { el: presetMinimal, name: 'minimal' }
  ];
  
  presets.forEach(({ el, name }) => {
    if (el) {
      if (name === activePreset) {
        el.classList.add('active');
      } else {
        el.classList.remove('active');
      }
    }
  });
  
  // Update description
  if (presetDescription && PRESETS[activePreset]) {
    presetDescription.textContent = PRESETS[activePreset].description;
  }
}

// Detect current preset based on settings
function detectCurrentPreset() {
  for (const [name, preset] of Object.entries(PRESETS)) {
    const matches = 
      state.canvasProtect === preset.canvasProtect &&
      state.webglProtect === preset.webglProtect &&
      state.audioProtect === preset.audioProtect &&
      state.navigatorProtect === preset.navigatorProtect &&
      state.webrtcProtect === preset.webrtcProtect &&
      state.batteryProtect === preset.batteryProtect &&
      state.bluetoothProtect === preset.bluetoothProtect &&
      state.permissionsProtect === preset.permissionsProtect &&
      state.storageProtect === preset.storageProtect;
    
    if (matches) {
      return name;
    }
  }
  return null; // Custom settings
}

// Preset event listeners
if (presetParanoid) {
  presetParanoid.addEventListener('click', () => applyPreset('paranoid'));
}

if (presetBalanced) {
  presetBalanced.addEventListener('click', () => applyPreset('balanced'));
}

if (presetMinimal) {
  presetMinimal.addEventListener('click', () => applyPreset('minimal'));
}

// Profile management event listeners
if (saveProfileBtn) {
  saveProfileBtn.addEventListener('click', () => {
    if (saveModal) {
      saveModal.classList.add('show');
      if (profileNameInput) {
        profileNameInput.value = '';
        profileNameInput.focus();
      }
    }
  });
}

if (modalCancel) {
  modalCancel.addEventListener('click', () => {
    if (saveModal) saveModal.classList.remove('show');
  });
}

if (modalSave) {
  modalSave.addEventListener('click', async () => {
    const name = profileNameInput?.value.trim();
    if (name) {
      await saveCurrentProfile(name);
      if (saveModal) saveModal.classList.remove('show');
    }
  });
}

if (profileNameInput) {
  profileNameInput.addEventListener('keypress', async (e) => {
    if (e.key === 'Enter') {
      const name = profileNameInput.value.trim();
      if (name) {
        await saveCurrentProfile(name);
        if (saveModal) saveModal.classList.remove('show');
      }
    }
  });
}

if (exportBtn) {
  exportBtn.addEventListener('click', exportProfiles);
}

if (importBtn) {
  importBtn.addEventListener('click', () => {
    if (importFile) importFile.click();
  });
}

if (importFile) {
  importFile.addEventListener('change', async (e) => {
    const file = e.target.files[0];
    if (file) {
      await importProfiles(file);
      importFile.value = '';
    }
  });
}

// Close modal on overlay click
if (saveModal) {
  saveModal.addEventListener('click', (e) => {
    if (e.target === saveModal) {
      saveModal.classList.remove('show');
    }
  });
}

// Initialize
loadState();
checkUpdateNotification();
