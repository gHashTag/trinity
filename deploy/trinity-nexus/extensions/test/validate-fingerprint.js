/**
 * NeoDetect Fingerprint Validation Tests
 * Compares fingerprints with and without extension to verify protection
 */

const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const EXTENSION_PATH = path.resolve(__dirname, '../chrome');

// Fingerprint collection functions
const fingerprintCode = `
(function() {
  const fp = {};
  
  // Canvas fingerprint
  try {
    const canvas = document.createElement('canvas');
    canvas.width = 200;
    canvas.height = 50;
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#f60';
    ctx.fillRect(0, 0, 200, 50);
    ctx.fillStyle = '#069';
    ctx.font = '14px Arial';
    ctx.fillText('Fingerprint Test', 10, 30);
    ctx.strokeStyle = 'rgba(102, 204, 0, 0.7)';
    ctx.arc(75, 25, 20, 0, Math.PI * 2, true);
    ctx.stroke();
    fp.canvas = canvas.toDataURL().substring(0, 100);
  } catch (e) {
    fp.canvas = 'error';
  }
  
  // WebGL fingerprint
  try {
    const canvas = document.createElement('canvas');
    const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
    if (gl) {
      const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
      if (debugInfo) {
        fp.webglVendor = gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL);
        fp.webglRenderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);
      } else {
        fp.webglVendor = gl.getParameter(gl.VENDOR);
        fp.webglRenderer = gl.getParameter(gl.RENDERER);
      }
    }
  } catch (e) {
    fp.webglVendor = 'error';
    fp.webglRenderer = 'error';
  }
  
  // Navigator properties
  fp.platform = navigator.platform;
  fp.userAgent = navigator.userAgent.substring(0, 80);
  fp.hardwareConcurrency = navigator.hardwareConcurrency;
  fp.deviceMemory = navigator.deviceMemory;
  fp.language = navigator.language;
  fp.maxTouchPoints = navigator.maxTouchPoints;
  
  // Screen properties
  fp.screenWidth = screen.width;
  fp.screenHeight = screen.height;
  fp.colorDepth = screen.colorDepth;
  fp.pixelRatio = window.devicePixelRatio;
  
  // Timezone
  fp.timezoneOffset = new Date().getTimezoneOffset();
  
  return fp;
})();
`;

async function collectFingerprint(withExtension = false) {
  const args = [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--window-size=1280,800'
  ];
  
  if (withExtension) {
    args.push(`--disable-extensions-except=${EXTENSION_PATH}`);
    args.push(`--load-extension=${EXTENSION_PATH}`);
  }
  
  const browser = await puppeteer.launch({
    headless: !withExtension, // Extension requires non-headless
    args
  });
  
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 800 });
    
    // Navigate to blank page
    await page.goto('about:blank');
    
    if (withExtension) {
      // Wait for extension to initialize
      await new Promise(r => setTimeout(r, 3000));
    }
    
    // Collect fingerprint
    const fingerprint = await page.evaluate(fingerprintCode);
    return fingerprint;
    
  } finally {
    await browser.close();
  }
}

function compareFingerprints(baseline, protected) {
  const results = {
    differences: [],
    same: [],
    protectionScore: 0
  };
  
  const keys = new Set([...Object.keys(baseline), ...Object.keys(protected)]);
  let totalKeys = 0;
  let differentKeys = 0;
  
  for (const key of keys) {
    totalKeys++;
    const baseVal = String(baseline[key]);
    const protVal = String(protected[key]);
    
    if (baseVal !== protVal) {
      differentKeys++;
      results.differences.push({
        property: key,
        baseline: baseVal.substring(0, 50),
        protected: protVal.substring(0, 50)
      });
    } else {
      results.same.push(key);
    }
  }
  
  results.protectionScore = Math.round((differentKeys / totalKeys) * 100);
  return results;
}

async function runValidation() {
  console.log('='.repeat(60));
  console.log('NeoDetect Fingerprint Validation');
  console.log('='.repeat(60));
  
  try {
    // Collect baseline fingerprint (no extension)
    console.log('\n1. Collecting baseline fingerprint (no extension)...');
    const baseline = await collectFingerprint(false);
    console.log('   Baseline collected.');
    
    // Collect protected fingerprint (with extension)
    console.log('\n2. Collecting protected fingerprint (with extension)...');
    const protected = await collectFingerprint(true);
    console.log('   Protected fingerprint collected.');
    
    // Compare fingerprints
    console.log('\n3. Comparing fingerprints...');
    const comparison = compareFingerprints(baseline, protected);
    
    // Display results
    console.log('\n' + '='.repeat(60));
    console.log('VALIDATION RESULTS');
    console.log('='.repeat(60));
    
    console.log(`\nProtection Score: ${comparison.protectionScore}%`);
    console.log(`Properties Changed: ${comparison.differences.length}`);
    console.log(`Properties Same: ${comparison.same.length}`);
    
    if (comparison.differences.length > 0) {
      console.log('\n--- Changed Properties ---');
      for (const diff of comparison.differences) {
        console.log(`\n  ${diff.property}:`);
        console.log(`    Before: ${diff.baseline}`);
        console.log(`    After:  ${diff.protected}`);
      }
    }
    
    if (comparison.same.length > 0) {
      console.log('\n--- Unchanged Properties ---');
      console.log(`  ${comparison.same.join(', ')}`);
    }
    
    // Save results
    const resultsPath = path.join(__dirname, 'validation-results.json');
    fs.writeFileSync(resultsPath, JSON.stringify({
      baseline,
      protected,
      comparison,
      timestamp: new Date().toISOString()
    }, null, 2));
    
    console.log(`\nResults saved to: ${resultsPath}`);
    
    // Verdict
    console.log('\n' + '='.repeat(60));
    if (comparison.protectionScore >= 50) {
      console.log('✅ PASS: Extension provides significant fingerprint protection');
    } else if (comparison.protectionScore >= 25) {
      console.log('⚠️  PARTIAL: Extension provides some fingerprint protection');
    } else {
      console.log('❌ FAIL: Extension does not significantly change fingerprint');
    }
    console.log('='.repeat(60));
    
    return comparison.protectionScore;
    
  } catch (error) {
    console.error('Validation failed:', error.message);
    process.exit(1);
  }
}

runValidation();
