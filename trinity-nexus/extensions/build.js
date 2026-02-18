#!/usr/bin/env node
/**
 * NeoDetect Extension Build Script
 * Builds Chrome and Firefox extensions from shared source
 * 
 * Usage:
 *   node build.js          - Build all (wasm + chrome + firefox)
 *   node build.js chrome   - Build Chrome extension only
 *   node build.js firefox  - Build Firefox extension only
 *   node build.js wasm     - Build WASM module only
 *   node build.js all      - Build everything
 *   node build.js clean    - Clean build artifacts
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = __dirname;
const CHROME_DIR = path.join(ROOT, 'chrome');
const FIREFOX_DIR = path.join(ROOT, 'firefox');
const WASM_SRC = path.join(ROOT, '..', 'src', 'firebird', 'neodetect_wasm.zig');
const VERSION = require('./package.json').version;

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m'
};

function log(msg, color = 'reset') {
  console.log(`${colors[color]}${msg}${colors.reset}`);
}

function logStep(step) {
  log(`\n▶ ${step}`, 'cyan');
}

function logSuccess(msg) {
  log(`  ✅ ${msg}`, 'green');
}

function logError(msg) {
  log(`  ❌ ${msg}`, 'red');
}

// Build WASM module
function buildWasm() {
  logStep('Building WASM module...');
  
  if (!fs.existsSync(WASM_SRC)) {
    logError(`WASM source not found: ${WASM_SRC}`);
    return false;
  }
  
  const wasmOutChrome = path.join(CHROME_DIR, 'wasm', 'neodetect.wasm');
  const wasmOutFirefox = path.join(FIREFOX_DIR, 'wasm', 'neodetect.wasm');
  
  // Ensure directories exist
  fs.mkdirSync(path.dirname(wasmOutChrome), { recursive: true });
  fs.mkdirSync(path.dirname(wasmOutFirefox), { recursive: true });
  
  try {
    execSync(`zig build-exe ${WASM_SRC} -target wasm32-freestanding -O ReleaseFast -fno-entry -rdynamic -femit-bin=${wasmOutChrome}`, {
      stdio: 'pipe',
      cwd: path.join(ROOT, '..')
    });
    
    // Copy to Firefox
    fs.copyFileSync(wasmOutChrome, wasmOutFirefox);
    
    const size = fs.statSync(wasmOutChrome).size;
    logSuccess(`WASM built: ${(size / 1024).toFixed(1)}KB`);
    return true;
  } catch (e) {
    logError(`WASM build failed: ${e.message}`);
    return false;
  }
}

// Sync shared files from Chrome to Firefox
function syncFirefoxFiles() {
  logStep('Syncing shared files to Firefox...');
  
  const sharedFiles = [
    ['icons/icon16.png', 'icons/icon16.png'],
    ['icons/icon48.png', 'icons/icon48.png'],
    ['icons/icon128.png', 'icons/icon128.png'],
    ['wasm/neodetect-loader.js', 'wasm/neodetect-loader.js'],
    ['popup/popup.html', 'popup/popup.html']
  ];
  
  for (const [src, dest] of sharedFiles) {
    const srcPath = path.join(CHROME_DIR, src);
    const destPath = path.join(FIREFOX_DIR, dest);
    
    if (fs.existsSync(srcPath)) {
      fs.mkdirSync(path.dirname(destPath), { recursive: true });
      fs.copyFileSync(srcPath, destPath);
    }
  }
  
  // Copy and transform popup.js (chrome.* -> browser.*)
  const popupJsSrc = path.join(CHROME_DIR, 'popup', 'popup.js');
  const popupJsDest = path.join(FIREFOX_DIR, 'popup', 'popup.js');
  if (fs.existsSync(popupJsSrc)) {
    let content = fs.readFileSync(popupJsSrc, 'utf8');
    content = content.replace(/chrome\./g, 'browser.');
    fs.writeFileSync(popupJsDest, content);
  }
  
  // Copy and transform content.js
  const contentJsSrc = path.join(CHROME_DIR, 'content', 'content.js');
  const contentJsDest = path.join(FIREFOX_DIR, 'content', 'content.js');
  if (fs.existsSync(contentJsSrc)) {
    let content = fs.readFileSync(contentJsSrc, 'utf8');
    content = content.replace(/chrome\./g, 'browser.');
    fs.writeFileSync(contentJsDest, content);
  }
  
  logSuccess('Shared files synced');
}

// Create ZIP package
function createPackage(browser) {
  logStep(`Packaging ${browser} extension...`);
  
  const dir = browser === 'chrome' ? CHROME_DIR : FIREFOX_DIR;
  const zipName = `neodetect-${browser}-v${VERSION}.zip`;
  const zipPath = path.join(ROOT, zipName);
  
  // Remove old zip
  if (fs.existsSync(zipPath)) {
    fs.unlinkSync(zipPath);
  }
  
  try {
    execSync(`cd "${dir}" && zip -r "${zipPath}" . -x "*.DS_Store" -x "__MACOSX/*" -x "screenshots/*" -x "promo/*" -x "*.md"`, {
      stdio: 'pipe'
    });
    
    const size = fs.statSync(zipPath).size;
    logSuccess(`${zipName} created: ${(size / 1024).toFixed(1)}KB`);
    return true;
  } catch (e) {
    logError(`Packaging failed: ${e.message}`);
    return false;
  }
}

// Build Chrome extension
function buildChrome() {
  logStep('Building Chrome extension...');
  
  // Update manifest version
  const manifestPath = path.join(CHROME_DIR, 'manifest.json');
  if (fs.existsSync(manifestPath)) {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    manifest.version = VERSION;
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
    logSuccess(`Chrome manifest updated to v${VERSION}`);
  }
  
  return createPackage('chrome');
}

// Build Firefox extension
function buildFirefox() {
  logStep('Building Firefox extension...');
  
  // Sync files first
  syncFirefoxFiles();
  
  // Update manifest version
  const manifestPath = path.join(FIREFOX_DIR, 'manifest.json');
  if (fs.existsSync(manifestPath)) {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    manifest.version = VERSION;
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
    logSuccess(`Firefox manifest updated to v${VERSION}`);
  }
  
  return createPackage('firefox');
}

// Clean build artifacts
function clean() {
  logStep('Cleaning build artifacts...');
  
  const patterns = [
    'neodetect-chrome-*.zip',
    'neodetect-firefox-*.zip',
    'neodetect-v*.zip'
  ];
  
  let cleaned = 0;
  for (const pattern of patterns) {
    const files = fs.readdirSync(ROOT).filter(f => {
      if (pattern.includes('*')) {
        const regex = new RegExp(pattern.replace('*', '.*'));
        return regex.test(f);
      }
      return f === pattern;
    });
    
    for (const file of files) {
      fs.unlinkSync(path.join(ROOT, file));
      cleaned++;
    }
  }
  
  // Clean .wasm.o files
  const wasmOFiles = [
    path.join(CHROME_DIR, 'wasm', 'neodetect.wasm.o'),
    path.join(FIREFOX_DIR, 'wasm', 'neodetect.wasm.o')
  ];
  
  for (const file of wasmOFiles) {
    if (fs.existsSync(file)) {
      fs.unlinkSync(file);
      cleaned++;
    }
  }
  
  logSuccess(`Cleaned ${cleaned} files`);
}

// Main
function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'all';
  
  console.log('═'.repeat(50));
  log('NeoDetect Extension Build', 'cyan');
  log(`Version: ${VERSION}`, 'yellow');
  console.log('═'.repeat(50));
  
  let success = true;
  
  switch (command) {
    case 'wasm':
      success = buildWasm();
      break;
    
    case 'chrome':
      success = buildChrome();
      break;
    
    case 'firefox':
      success = buildFirefox();
      break;
    
    case 'all':
      success = buildWasm() && buildChrome() && buildFirefox();
      break;
    
    case 'clean':
      clean();
      break;
    
    default:
      log(`Unknown command: ${command}`, 'red');
      log('Usage: node build.js [wasm|chrome|firefox|all|clean]', 'yellow');
      process.exit(1);
  }
  
  console.log('\n' + '═'.repeat(50));
  if (success) {
    log('Build completed successfully!', 'green');
  } else {
    log('Build failed!', 'red');
    process.exit(1);
  }
  console.log('═'.repeat(50));
}

main();
