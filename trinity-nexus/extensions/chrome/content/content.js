// NeoDetect Content Script - Fingerprint Injection Loader
// Loads inject.js as external script to bypass CSP restrictions
// φ² + 1/φ² = 3 = TRINITY

(function() {
  'use strict';

  // State
  let state = {
    enabled: true,
    similarity: 0.85,
    canvasProtect: true,
    webglProtect: true,
    audioProtect: true,
    navigatorProtect: true,
    webrtcProtect: true,
    batteryProtect: true,
    bluetoothProtect: true,
    permissionsProtect: true,
    storageProtect: true,
    profile: null,
    wasmReady: false
  };

  // Load state from background
  async function loadState() {
    try {
      const response = await chrome.runtime.sendMessage({ action: 'getState' });
      if (response) {
        state = { ...state, ...response };
      }
    } catch (e) {
      // Extension context might be invalid
    }
  }

  // Message listener (return true to keep message port open for async response)
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.action === 'updateState') {
      state = { ...state, ...message.state };
      injectProtections();
    } else if (message.action === 'profileUpdated') {
      state.profile = message.profile;
      state.similarity = message.similarity;
      state.wasmReady = message.wasmReady;
      injectProtections();
    }
    sendResponse({ success: true });
    return true;
  });

  // Inject fingerprint protections via external script (CSP-safe)
  function injectProtections() {
    if (!state.enabled) return;

    const script = document.createElement('script');
    script.src = chrome.runtime.getURL('content/inject.js');
    script.dataset.state = JSON.stringify(state);
    script.onload = () => script.remove();
    script.onerror = () => script.remove();
    (document.head || document.documentElement).appendChild(script);
  }

  // Initialize
  loadState().then(() => {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', injectProtections);
    } else {
      injectProtections();
    }
  });

})();
