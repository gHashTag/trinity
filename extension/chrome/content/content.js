// NeoDetect Content Script - Fingerprint Injection
// Uses WASM module for antidetect functionality
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
  
  // Message listener
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
    
    // Get noise value from profile or fallback
    function getNoiseValue(index, range = 2) {
      if (state.profile?.canvasNoise) {
        // Use WASM-generated noise pattern
        const noiseIdx = index % state.profile.canvasNoise.length;
        return state.profile.canvasNoise[noiseIdx] * range / 2;
      }
      // Fallback: deterministic noise based on profile hash
      if (state.profile?.canvasHash) {
        try {
          const hash = BigInt(state.profile.canvasHash);
          const seed = Number((hash >> BigInt(index % 64)) & BigInt(0xFF));
          return ((seed / 255) - 0.5) * range;
        } catch (e) {
          // BigInt conversion failed, use simple hash
        }
      }
      // Final fallback: use similarity as seed for deterministic noise
      const seed = (state.similarity || 0.85) * 1000000;
      const noise = Math.sin(seed + index * 0.1) * range;
      return noise;
    }
    
    // Canvas fingerprint protection
    if (state.canvasProtect) {
      const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
      const originalGetImageData = CanvasRenderingContext2D.prototype.getImageData;
      const originalToBlob = HTMLCanvasElement.prototype.toBlob;
      
      HTMLCanvasElement.prototype.toDataURL = function(...args) {
        const ctx = this.getContext('2d');
        if (ctx && this.width > 0 && this.height > 0) {
          try {
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
          } catch (e) {
            // Canvas might be tainted
          }
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
        if (ctx && this.width > 0 && this.height > 0) {
          try {
            const imageData = originalGetImageData.call(ctx, 0, 0, this.width, this.height);
            const data = imageData.data;
            
            for (let i = 0; i < data.length; i += 4) {
              const noise = getNoiseValue(i, 2);
              data[i] = Math.max(0, Math.min(255, data[i] + noise));
              data[i+1] = Math.max(0, Math.min(255, data[i+1] + noise));
              data[i+2] = Math.max(0, Math.min(255, data[i+2] + noise));
            }
            
            ctx.putImageData(imageData, 0, 0);
          } catch (e) {
            // Canvas might be tainted
          }
        }
        return originalToBlob.call(this, callback, ...args);
      };
    }
    
    // WebGL fingerprint protection
    if (state.webglProtect && state.profile) {
      const getParameterProxied = new WeakSet();
      
      // WEBGL_debug_renderer_info constants
      const UNMASKED_VENDOR_WEBGL = 0x9245;
      const UNMASKED_RENDERER_WEBGL = 0x9246;
      
      function hookGetParameter(proto) {
        const original = proto.getParameter;
        
        proto.getParameter = function(param) {
          const result = original.call(this, param);
          
          // Spoof vendor (both regular and debug extension)
          if ((param === 0x1F00 || param === UNMASKED_VENDOR_WEBGL) && state.profile.gpuVendor) {
            return state.profile.gpuVendor;
          }
          // Spoof renderer (both regular and debug extension)
          if ((param === 0x1F01 || param === UNMASKED_RENDERER_WEBGL) && state.profile.gpuRenderer) {
            return state.profile.gpuRenderer;
          }
          
          return result;
        };
      }
      
      // Hook WebGL contexts
      const originalGetContext = HTMLCanvasElement.prototype.getContext;
      HTMLCanvasElement.prototype.getContext = function(type, ...args) {
        const ctx = originalGetContext.call(this, type, ...args);
        
        if (ctx && (type === 'webgl' || type === 'webgl2' || type === 'experimental-webgl')) {
          const proto = Object.getPrototypeOf(ctx);
          if (!getParameterProxied.has(proto)) {
            hookGetParameter(proto);
            getParameterProxied.add(proto);
          }
        }
        
        return ctx;
      };
    }
    
    // Audio fingerprint protection
    if (state.audioProtect) {
      const originalCreateAnalyser = AudioContext.prototype.createAnalyser;
      AudioContext.prototype.createAnalyser = function() {
        const analyser = originalCreateAnalyser.call(this);
        const originalGetFloatFrequencyData = analyser.getFloatFrequencyData.bind(analyser);
        const originalGetByteFrequencyData = analyser.getByteFrequencyData.bind(analyser);
        
        analyser.getFloatFrequencyData = function(array) {
          originalGetFloatFrequencyData(array);
          for (let i = 0; i < array.length; i++) {
            array[i] += getNoiseValue(i, 0.1);
          }
        };
        
        analyser.getByteFrequencyData = function(array) {
          originalGetByteFrequencyData(array);
          for (let i = 0; i < array.length; i++) {
            const noise = Math.floor(getNoiseValue(i, 2));
            array[i] = Math.max(0, Math.min(255, array[i] + noise));
          }
        };
        
        return analyser;
      };
    }
    
    // Navigator properties spoofing
    if (state.navigatorProtect && state.profile) {
      const props = {
        platform: state.profile.platform,
        userAgent: state.profile.userAgent,
        hardwareConcurrency: state.profile.hardwareConcurrency,
        deviceMemory: state.profile.deviceMemory,
        language: state.profile.language,
        languages: state.profile.languages || [state.profile.language]
      };
      
      for (const [prop, value] of Object.entries(props)) {
        if (value !== undefined) {
          try {
            Object.defineProperty(Navigator.prototype, prop, {
              get: () => value,
              configurable: true
            });
          } catch (e) {
            // Property might not be configurable
          }
        }
      }
      
      // Screen properties
      if (state.profile.screenWidth && state.profile.screenHeight) {
        try {
          Object.defineProperty(Screen.prototype, 'width', {
            get: () => state.profile.screenWidth,
            configurable: true
          });
          Object.defineProperty(Screen.prototype, 'height', {
            get: () => state.profile.screenHeight,
            configurable: true
          });
          Object.defineProperty(Screen.prototype, 'availWidth', {
            get: () => state.profile.screenWidth,
            configurable: true
          });
          Object.defineProperty(Screen.prototype, 'availHeight', {
            get: () => state.profile.screenHeight - 40,
            configurable: true
          });
          Object.defineProperty(Screen.prototype, 'colorDepth', {
            get: () => state.profile.colorDepth || 24,
            configurable: true
          });
          Object.defineProperty(Screen.prototype, 'pixelDepth', {
            get: () => state.profile.colorDepth || 24,
            configurable: true
          });
        } catch (e) {
          // Properties might not be configurable
        }
      }
      
      // Device pixel ratio
      if (state.profile.pixelRatio) {
        try {
          Object.defineProperty(window, 'devicePixelRatio', {
            get: () => state.profile.pixelRatio,
            configurable: true
          });
        } catch (e) {}
      }
      
      // Timezone
      if (state.profile.timezoneOffset !== undefined) {
        const originalGetTimezoneOffset = Date.prototype.getTimezoneOffset;
        Date.prototype.getTimezoneOffset = function() {
          return state.profile.timezoneOffset;
        };
      }
    }
    
    // WebRTC IP Leak Protection
    if (state.webrtcProtect !== false) {
      const originalRTCPeerConnection = window.RTCPeerConnection || window.webkitRTCPeerConnection;
      
      if (originalRTCPeerConnection) {
        // IP address patterns to filter
        const localIPPattern = /^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)/;
        const ipv6LocalPattern = /^(fe80:|::1|fd[0-9a-f]{2}:)/i;
        
        window.RTCPeerConnection = function(config, constraints) {
          // Modify ICE servers to prevent leaks
          if (config && config.iceServers) {
            config.iceServers = config.iceServers.filter(server => {
              // Allow only TURN servers (they don't leak local IP)
              const urls = Array.isArray(server.urls) ? server.urls : [server.urls];
              return urls.some(url => url && url.startsWith('turn:'));
            });
          }
          
          const pc = new originalRTCPeerConnection(config, constraints);
          
          // Intercept ICE candidate events
          const originalAddEventListener = pc.addEventListener.bind(pc);
          pc.addEventListener = function(type, listener, options) {
            if (type === 'icecandidate') {
              const wrappedListener = function(event) {
                if (event.candidate && event.candidate.candidate) {
                  const candidate = event.candidate.candidate;
                  // Filter local IP addresses
                  if (localIPPattern.test(candidate) || ipv6LocalPattern.test(candidate)) {
                    return; // Block this candidate
                  }
                }
                listener.call(this, event);
              };
              return originalAddEventListener(type, wrappedListener, options);
            }
            return originalAddEventListener(type, listener, options);
          };
          
          // Also intercept onicecandidate setter
          let userHandler = null;
          Object.defineProperty(pc, 'onicecandidate', {
            get: () => userHandler,
            set: (handler) => {
              userHandler = handler;
              pc.addEventListener('icecandidate', handler);
            }
          });
          
          return pc;
        };
        
        window.RTCPeerConnection.prototype = originalRTCPeerConnection.prototype;
        
        if (window.webkitRTCPeerConnection) {
          window.webkitRTCPeerConnection = window.RTCPeerConnection;
        }
      }
    }
    
    // Battery Status API Spoofing
    if (state.batteryProtect !== false && navigator.getBattery) {
      const fakeBattery = {
        charging: true,
        chargingTime: Infinity,
        dischargingTime: Infinity,
        level: 1.0,
        addEventListener: function() {},
        removeEventListener: function() {},
        dispatchEvent: function() { return true; }
      };
      
      // Freeze to prevent detection
      Object.freeze(fakeBattery);
      
      navigator.getBattery = function() {
        return Promise.resolve(fakeBattery);
      };
    }
    
    // Bluetooth API Protection
    if (state.bluetoothProtect !== false && navigator.bluetooth) {
      navigator.bluetooth.requestDevice = function() {
        return Promise.reject(new DOMException('User cancelled the requestDevice() chooser.', 'NotFoundError'));
      };
      
      navigator.bluetooth.getAvailability = function() {
        return Promise.resolve(false);
      };
      
      if (navigator.bluetooth.getDevices) {
        navigator.bluetooth.getDevices = function() {
          return Promise.resolve([]);
        };
      }
    }
    
    // Permissions API Spoofing
    if (state.permissionsProtect !== false && navigator.permissions) {
      const permissionStates = {
        'geolocation': 'prompt',
        'notifications': 'denied',
        'push': 'denied',
        'camera': 'prompt',
        'microphone': 'prompt',
        'midi': 'denied',
        'bluetooth': 'denied',
        'persistent-storage': 'granted',
        'ambient-light-sensor': 'denied',
        'accelerometer': 'denied',
        'gyroscope': 'denied',
        'magnetometer': 'denied',
        'clipboard-read': 'prompt',
        'clipboard-write': 'granted'
      };
      
      const originalQuery = navigator.permissions.query.bind(navigator.permissions);
      
      navigator.permissions.query = function(descriptor) {
        const name = descriptor.name;
        const configuredState = permissionStates[name] || 'prompt';
        
        return Promise.resolve({
          state: configuredState,
          name: name,
          onchange: null,
          addEventListener: function() {},
          removeEventListener: function() {},
          dispatchEvent: function() { return true; }
        });
      };
    }
    
    // User-Agent Client Hints Spoofing
    if (state.navigatorProtect && state.profile) {
      const platform = state.profile.platform === 'Win32' ? 'Windows' : 
                       state.profile.platform === 'MacIntel' ? 'macOS' : 'Linux';
      
      const spoofedUserAgentData = {
        brands: [
          { brand: 'Chromium', version: '125' },
          { brand: 'Google Chrome', version: '125' },
          { brand: 'Not-A.Brand', version: '24' }
        ],
        mobile: false,
        platform: platform,
        
        getHighEntropyValues: function(hints) {
          return Promise.resolve({
            brands: this.brands,
            mobile: false,
            platform: platform,
            platformVersion: platform === 'Windows' ? '10.0.0' : platform === 'macOS' ? '14.0.0' : '6.5.0',
            architecture: 'x86',
            bitness: '64',
            model: '',
            uaFullVersion: '125.0.0.0',
            fullVersionList: this.brands
          });
        },
        
        toJSON: function() {
          return {
            brands: this.brands,
            mobile: false,
            platform: platform
          };
        }
      };
      
      try {
        Object.defineProperty(Navigator.prototype, 'userAgentData', {
          get: () => spoofedUserAgentData,
          configurable: true
        });
      } catch (e) {}
    }
    
    // Storage API Spoofing
    if (state.storageProtect !== false && navigator.storage && navigator.storage.estimate) {
      const originalEstimate = navigator.storage.estimate.bind(navigator.storage);
      
      navigator.storage.estimate = function() {
        return Promise.resolve({
          quota: 1073741824,  // 1GB - common value
          usage: 52428800,    // 50MB - reasonable usage
          usageDetails: {
            indexedDB: 10485760,
            caches: 20971520,
            serviceWorkerRegistrations: 1048576
          }
        });
      };
    }
    
    // Log protection status
    const protections = [];
    if (state.canvasProtect) protections.push('Canvas');
    if (state.webglProtect) protections.push('WebGL');
    if (state.audioProtect) protections.push('Audio');
    if (state.navigatorProtect) protections.push('Navigator');
    if (state.webrtcProtect !== false) protections.push('WebRTC');
    if (state.batteryProtect !== false) protections.push('Battery');
    if (state.bluetoothProtect !== false) protections.push('Bluetooth');
    if (state.permissionsProtect !== false) protections.push('Permissions');
    
    console.log(
      `🔥 NeoDetect active | Similarity: ${state.similarity?.toFixed(2) || 'N/A'} | ` +
      `Protections: ${protections.join(', ')} | ` +
      `WASM: ${state.wasmReady ? 'Ready' : 'Fallback'}`
    );
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
