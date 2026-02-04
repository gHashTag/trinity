// Firebird Content Script - Fingerprint Injection
// φ² + 1/φ² = 3 = TRINITY

(function() {
  'use strict';
  
  const PHI = 1.6180339887;
  
  // State
  let state = {
    enabled: true,
    similarity: 0.85,
    canvasProtect: true,
    webglProtect: true,
    fingerprint: null
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
  
  // Message listener
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.action === 'updateState') {
      state = { ...state, ...message.state };
      injectProtections();
    } else if (message.action === 'fingerprintUpdated') {
      state.fingerprint = message.fingerprint;
      state.similarity = message.similarity;
      injectProtections();
    }
    sendResponse({ success: true });
  });
  
  // Inject fingerprint protections
  function injectProtections() {
    if (!state.enabled) return;
    
    // Inject script into page context
    const script = document.createElement('script');
    script.textContent = `(${injectedCode.toString()})(${JSON.stringify(state)})`;
    (document.head || document.documentElement).appendChild(script);
    script.remove();
  }
  
  // Code to inject into page context
  function injectedCode(state) {
    const PHI = 1.6180339887;
    
    // Generate noise based on fingerprint
    function getNoiseValue(index, range = 0.01) {
      if (!state.fingerprint?.trits) {
        return (Math.random() - 0.5) * range;
      }
      const trit = state.fingerprint.trits[index % state.fingerprint.trits.length];
      return (trit / 3) * range * PHI;
    }
    
    // Canvas fingerprint protection
    if (state.canvasProtect) {
      const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
      const originalGetImageData = CanvasRenderingContext2D.prototype.getImageData;
      const originalToBlob = HTMLCanvasElement.prototype.toBlob;
      
      HTMLCanvasElement.prototype.toDataURL = function(...args) {
        const ctx = this.getContext('2d');
        if (ctx) {
          const imageData = originalGetImageData.call(ctx, 0, 0, this.width, this.height);
          const data = imageData.data;
          
          // Add ternary noise to pixels
          for (let i = 0; i < data.length; i += 4) {
            const noise = getNoiseValue(i, 2);
            data[i] = Math.max(0, Math.min(255, data[i] + noise));     // R
            data[i+1] = Math.max(0, Math.min(255, data[i+1] + noise)); // G
            data[i+2] = Math.max(0, Math.min(255, data[i+2] + noise)); // B
          }
          
          ctx.putImageData(imageData, 0, 0);
        }
        return originalToDataURL.apply(this, args);
      };
      
      CanvasRenderingContext2D.prototype.getImageData = function(...args) {
        const imageData = originalGetImageData.apply(this, args);
        const data = imageData.data;
        
        // Add ternary noise
        for (let i = 0; i < data.length; i += 4) {
          const noise = getNoiseValue(i, 2);
          data[i] = Math.max(0, Math.min(255, data[i] + noise));
          data[i+1] = Math.max(0, Math.min(255, data[i+1] + noise));
          data[i+2] = Math.max(0, Math.min(255, data[i+2] + noise));
        }
        
        return imageData;
      };
      
      HTMLCanvasElement.prototype.toBlob = function(callback, ...args) {
        const ctx = this.getContext('2d');
        if (ctx) {
          const imageData = originalGetImageData.call(ctx, 0, 0, this.width, this.height);
          const data = imageData.data;
          
          for (let i = 0; i < data.length; i += 4) {
            const noise = getNoiseValue(i, 2);
            data[i] = Math.max(0, Math.min(255, data[i] + noise));
            data[i+1] = Math.max(0, Math.min(255, data[i+1] + noise));
            data[i+2] = Math.max(0, Math.min(255, data[i+2] + noise));
          }
          
          ctx.putImageData(imageData, 0, 0);
        }
        return originalToBlob.call(this, callback, ...args);
      };
    }
    
    // WebGL fingerprint protection
    if (state.webglProtect) {
      const getParameterProxied = new Map();
      
      function hookGetParameter(proto) {
        const original = proto.getParameter;
        
        proto.getParameter = function(param) {
          const result = original.call(this, param);
          
          // Add noise to certain parameters
          const noisyParams = [
            0x1F00, // VENDOR
            0x1F01, // RENDERER
            0x1F02, // VERSION
            0x8B8C, // SHADING_LANGUAGE_VERSION
          ];
          
          if (typeof result === 'string' && noisyParams.includes(param)) {
            // Add invisible character based on fingerprint
            const noise = getNoiseValue(param, 1);
            if (noise > 0.3) {
              return result + '\u200B'; // Zero-width space
            }
          }
          
          return result;
        };
      }
      
      // Hook WebGL contexts
      const originalGetContext = HTMLCanvasElement.prototype.getContext;
      HTMLCanvasElement.prototype.getContext = function(type, ...args) {
        const ctx = originalGetContext.call(this, type, ...args);
        
        if (ctx && (type === 'webgl' || type === 'webgl2' || type === 'experimental-webgl')) {
          if (!getParameterProxied.has(ctx)) {
            hookGetParameter(Object.getPrototypeOf(ctx));
            getParameterProxied.set(ctx, true);
          }
        }
        
        return ctx;
      };
    }
    
    // Audio fingerprint protection
    const originalCreateAnalyser = AudioContext.prototype.createAnalyser;
    AudioContext.prototype.createAnalyser = function() {
      const analyser = originalCreateAnalyser.call(this);
      const originalGetFloatFrequencyData = analyser.getFloatFrequencyData.bind(analyser);
      
      analyser.getFloatFrequencyData = function(array) {
        originalGetFloatFrequencyData(array);
        for (let i = 0; i < array.length; i++) {
          array[i] += getNoiseValue(i, 0.1);
        }
      };
      
      return analyser;
    };
    
    // Navigator properties
    const navigatorProps = {
      hardwareConcurrency: () => {
        const base = navigator.hardwareConcurrency || 4;
        const noise = Math.floor(getNoiseValue(0, 2));
        return Math.max(2, Math.min(16, base + noise));
      },
      deviceMemory: () => {
        const base = navigator.deviceMemory || 8;
        const options = [2, 4, 8, 16];
        const idx = Math.abs(Math.floor(getNoiseValue(1, options.length)));
        return options[idx % options.length];
      }
    };
    
    // Override navigator properties
    for (const [prop, getter] of Object.entries(navigatorProps)) {
      try {
        Object.defineProperty(Navigator.prototype, prop, {
          get: getter,
          configurable: true
        });
      } catch (e) {
        // Property might not be configurable
      }
    }
    
    console.log('🔥 Firebird protection active | Similarity:', state.similarity?.toFixed(2) || 'N/A');
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
