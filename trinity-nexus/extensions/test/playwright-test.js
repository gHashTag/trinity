/**
 * NeoDetect Playwright Tests
 * Headless fingerprint validation without extension (baseline)
 */

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const SCREENSHOTS_DIR = path.resolve(__dirname, '../chrome/screenshots');

if (!fs.existsSync(SCREENSHOTS_DIR)) {
  fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });
}

const fingerprintCode = `
() => {
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
    fp.canvas = canvas.toDataURL().substring(22, 72);
  } catch (e) {
    fp.canvas = 'error: ' + e.message;
  }
  
  // WebGL fingerprint
  try {
    const canvas = document.createElement('canvas');
    const gl = canvas.getContext('webgl');
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
  
  // Navigator
  fp.platform = navigator.platform;
  fp.userAgent = navigator.userAgent.substring(0, 60);
  fp.hardwareConcurrency = navigator.hardwareConcurrency;
  fp.deviceMemory = navigator.deviceMemory || 'N/A';
  fp.language = navigator.language;
  
  // Screen
  fp.screenWidth = screen.width;
  fp.screenHeight = screen.height;
  fp.colorDepth = screen.colorDepth;
  fp.pixelRatio = window.devicePixelRatio;
  
  return fp;
}
`;

async function runTests() {
  console.log('='.repeat(60));
  console.log('NeoDetect Playwright Fingerprint Tests');
  console.log('='.repeat(60));
  
  const browser = await chromium.launch({ headless: true });
  
  try {
    const context = await browser.newContext({
      viewport: { width: 1280, height: 800 }
    });
    const page = await context.newPage();
    
    // Navigate to blank page
    await page.goto('about:blank');
    
    // Collect baseline fingerprint
    console.log('\nCollecting baseline fingerprint...');
    const baseline = await page.evaluate(fingerprintCode);
    
    console.log('\n--- Baseline Fingerprint ---');
    for (const [key, value] of Object.entries(baseline)) {
      console.log(`  ${key}: ${value}`);
    }
    
    // Navigate to test HTML page
    const testPagePath = path.resolve(__dirname, 'fingerprint-test.html');
    if (fs.existsSync(testPagePath)) {
      console.log('\nLoading local test page...');
      await page.goto(`file://${testPagePath}`);
      await page.waitForTimeout(1000);
      
      // Take screenshot
      await page.screenshot({
        path: path.join(SCREENSHOTS_DIR, 'baseline-test.png'),
        fullPage: false
      });
      console.log('Screenshot saved: baseline-test.png');
    }
    
    // Save results
    const resultsPath = path.join(__dirname, 'baseline-fingerprint.json');
    fs.writeFileSync(resultsPath, JSON.stringify({
      fingerprint: baseline,
      timestamp: new Date().toISOString(),
      note: 'Baseline without extension - compare with protected fingerprint'
    }, null, 2));
    
    console.log(`\nResults saved to: ${resultsPath}`);
    
    console.log('\n' + '='.repeat(60));
    console.log('Baseline collection complete!');
    console.log('');
    console.log('To test with extension:');
    console.log('1. Load extension in Chrome manually');
    console.log('2. Open extension/test/fingerprint-test.html');
    console.log('3. Compare results with baseline-fingerprint.json');
    console.log('='.repeat(60));
    
  } finally {
    await browser.close();
  }
}

runTests().catch(console.error);
