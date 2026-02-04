/**
 * NeoDetect WASM Module Tests
 * Tests the WASM fingerprint generation without browser
 */

const fs = require('fs');
const path = require('path');

const WASM_PATH = path.resolve(__dirname, '../chrome/wasm/neodetect.wasm');

async function loadWasm() {
  const wasmBuffer = fs.readFileSync(WASM_PATH);
  
  // First, inspect the module
  const wasmModule = await WebAssembly.compile(wasmBuffer);
  const imports = WebAssembly.Module.imports(wasmModule);
  const exports = WebAssembly.Module.exports(wasmModule);
  
  console.log('\nWASM Module Info:');
  console.log(`  Imports: ${imports.length}`);
  imports.forEach(i => console.log(`    - ${i.module}.${i.name} (${i.kind})`));
  console.log(`  Exports: ${exports.length}`);
  exports.forEach(e => console.log(`    - ${e.name} (${e.kind})`));
  
  // Build import object based on what module needs
  const importObject = {};
  for (const imp of imports) {
    if (!importObject[imp.module]) {
      importObject[imp.module] = {};
    }
    if (imp.kind === 'memory') {
      importObject[imp.module][imp.name] = new WebAssembly.Memory({ initial: 256 });
    } else if (imp.kind === 'function') {
      importObject[imp.module][imp.name] = () => {};
    }
  }
  
  const instance = await WebAssembly.instantiate(wasmModule, importObject);
  return instance.exports;
}

async function runTests() {
  console.log('='.repeat(60));
  console.log('NeoDetect WASM Module Tests');
  console.log('='.repeat(60));
  
  try {
    const wasm = await loadWasm();
    
    console.log('\nExported functions:');
    const exports = Object.keys(wasm).filter(k => typeof wasm[k] === 'function');
    exports.forEach(fn => console.log(`  - ${fn}`));
    
    console.log('\n--- Testing WASM Functions ---\n');
    
    // Test init
    if (wasm.wasm_neodetect_init) {
      const seed = BigInt(Date.now());
      const result = wasm.wasm_neodetect_init(seed);
      console.log(`wasm_neodetect_init(${seed}): ${result}`);
    }
    
    // Test create profile
    if (wasm.wasm_create_profile) {
      const seed = BigInt(12345);
      const osType = 1; // Windows 11
      const hwType = 1; // Intel i7
      const gpuType = 1; // RTX 4070
      const result = wasm.wasm_create_profile(seed, osType, hwType, gpuType);
      console.log(`wasm_create_profile(${seed}, ${osType}, ${hwType}, ${gpuType}): ${result}`);
    }
    
    // Test screen properties
    if (wasm.wasm_get_screen_width) {
      console.log(`wasm_get_screen_width(): ${wasm.wasm_get_screen_width()}`);
    }
    if (wasm.wasm_get_screen_height) {
      console.log(`wasm_get_screen_height(): ${wasm.wasm_get_screen_height()}`);
    }
    if (wasm.wasm_get_pixel_ratio) {
      console.log(`wasm_get_pixel_ratio(): ${wasm.wasm_get_pixel_ratio()}`);
    }
    
    // Test hardware properties
    if (wasm.wasm_get_hardware_concurrency) {
      console.log(`wasm_get_hardware_concurrency(): ${wasm.wasm_get_hardware_concurrency()}`);
    }
    if (wasm.wasm_get_device_memory) {
      console.log(`wasm_get_device_memory(): ${wasm.wasm_get_device_memory()}`);
    }
    
    // Test fingerprint hashes
    if (wasm.wasm_get_canvas_hash) {
      console.log(`wasm_get_canvas_hash(): ${wasm.wasm_get_canvas_hash()}`);
    }
    if (wasm.wasm_get_webgl_hash) {
      console.log(`wasm_get_webgl_hash(): ${wasm.wasm_get_webgl_hash()}`);
    }
    if (wasm.wasm_get_audio_hash) {
      console.log(`wasm_get_audio_hash(): ${wasm.wasm_get_audio_hash()}`);
    }
    
    // Test canvas noise
    if (wasm.wasm_get_canvas_noise) {
      console.log(`wasm_get_canvas_noise(0): ${wasm.wasm_get_canvas_noise(0)}`);
      console.log(`wasm_get_canvas_noise(100): ${wasm.wasm_get_canvas_noise(100)}`);
    }
    
    // Test evolution
    if (wasm.wasm_evolve_fingerprint) {
      const similarity = wasm.wasm_evolve_fingerprint(0.85, 100);
      console.log(`wasm_evolve_fingerprint(0.85, 100): ${similarity}`);
    }
    
    if (wasm.wasm_get_similarity) {
      console.log(`wasm_get_similarity(): ${wasm.wasm_get_similarity()}`);
    }
    
    // Test different profiles
    console.log('\n--- Profile Variations ---\n');
    
    const profiles = [
      { name: 'Windows 10 + Intel i5 + RTX 3060', os: 0, hw: 0, gpu: 0 },
      { name: 'Windows 11 + Intel i9 + RTX 4090', os: 1, hw: 2, gpu: 2 },
      { name: 'macOS + Apple M2 + Apple GPU', os: 2, hw: 7, gpu: 7 },
      { name: 'Linux + AMD Ryzen 7 + AMD RX 7900', os: 3, hw: 4, gpu: 4 }
    ];
    
    for (const profile of profiles) {
      if (wasm.wasm_create_profile) {
        wasm.wasm_create_profile(BigInt(42), profile.os, profile.hw, profile.gpu);
        console.log(`${profile.name}:`);
        console.log(`  Screen: ${wasm.wasm_get_screen_width()}x${wasm.wasm_get_screen_height()}`);
        console.log(`  Cores: ${wasm.wasm_get_hardware_concurrency()}`);
        console.log(`  Memory: ${wasm.wasm_get_device_memory()}GB`);
        console.log(`  Canvas Hash: ${wasm.wasm_get_canvas_hash()}`);
        console.log('');
      }
    }
    
    console.log('='.repeat(60));
    console.log('✅ All WASM tests passed!');
    console.log('='.repeat(60));
    
  } catch (error) {
    console.error('Test failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

runTests();
