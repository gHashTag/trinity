/**
 * NeoDetect Extension E2E Tests
 * Tests fingerprint protection effectiveness using Puppeteer
 */

const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const EXTENSION_PATH = path.resolve(__dirname, '../chrome');
const SCREENSHOTS_DIR = path.resolve(__dirname, '../chrome/screenshots');

// Ensure screenshots directory exists
if (!fs.existsSync(SCREENSHOTS_DIR)) {
  fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });
}

async function launchBrowserWithExtension() {
  const browser = await puppeteer.launch({
    headless: false, // Extensions require non-headless mode
    args: [
      `--disable-extensions-except=${EXTENSION_PATH}`,
      `--load-extension=${EXTENSION_PATH}`,
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--window-size=1280,800'
    ]
  });
  return browser;
}

async function getExtensionId(browser) {
  // Wait for extension to load
  await new Promise(r => setTimeout(r, 2000));
  
  const targets = await browser.targets();
  const extensionTarget = targets.find(target => 
    target.type() === 'service_worker' && 
    target.url().includes('chrome-extension://')
  );
  
  if (!extensionTarget) {
    throw new Error('Extension not found');
  }
  
  const extensionUrl = extensionTarget.url();
  const extensionId = extensionUrl.split('/')[2];
  return extensionId;
}

async function testCanvasFingerprint(page) {
  console.log('Testing Canvas Fingerprint...');
  
  const result = await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 200;
    canvas.height = 50;
    const ctx = canvas.getContext('2d');
    
    // Draw test pattern
    ctx.fillStyle = '#f60';
    ctx.fillRect(0, 0, 200, 50);
    ctx.fillStyle = '#069';
    ctx.font = '14px Arial';
    ctx.fillText('NeoDetect Test', 10, 30);
    
    return canvas.toDataURL();
  });
  
  console.log(`  Canvas hash length: ${result.length}`);
  return result;
}

async function testWebGLFingerprint(page) {
  console.log('Testing WebGL Fingerprint...');
  
  const result = await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
    
    if (!gl) return { vendor: 'N/A', renderer: 'N/A' };
    
    const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
    if (!debugInfo) return { vendor: 'N/A', renderer: 'N/A' };
    
    return {
      vendor: gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL),
      renderer: gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL)
    };
  });
  
  console.log(`  WebGL Vendor: ${result.vendor}`);
  console.log(`  WebGL Renderer: ${result.renderer}`);
  return result;
}

async function testNavigatorProperties(page) {
  console.log('Testing Navigator Properties...');
  
  const result = await page.evaluate(() => {
    return {
      platform: navigator.platform,
      userAgent: navigator.userAgent,
      hardwareConcurrency: navigator.hardwareConcurrency,
      deviceMemory: navigator.deviceMemory,
      language: navigator.language,
      languages: navigator.languages,
      maxTouchPoints: navigator.maxTouchPoints
    };
  });
  
  console.log(`  Platform: ${result.platform}`);
  console.log(`  Hardware Concurrency: ${result.hardwareConcurrency}`);
  console.log(`  Device Memory: ${result.deviceMemory}GB`);
  return result;
}

async function testScreenProperties(page) {
  console.log('Testing Screen Properties...');
  
  const result = await page.evaluate(() => {
    return {
      width: screen.width,
      height: screen.height,
      colorDepth: screen.colorDepth,
      pixelRatio: window.devicePixelRatio
    };
  });
  
  console.log(`  Screen: ${result.width}x${result.height}`);
  console.log(`  Color Depth: ${result.colorDepth}`);
  console.log(`  Pixel Ratio: ${result.pixelRatio}`);
  return result;
}

async function testAudioFingerprint(page) {
  console.log('Testing Audio Fingerprint...');
  
  const result = await page.evaluate(async () => {
    try {
      const audioContext = new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = audioContext.createOscillator();
      const analyser = audioContext.createAnalyser();
      const gain = audioContext.createGain();
      const processor = audioContext.createScriptProcessor(4096, 1, 1);
      
      gain.gain.value = 0;
      oscillator.type = 'triangle';
      oscillator.frequency.value = 10000;
      
      oscillator.connect(analyser);
      analyser.connect(processor);
      processor.connect(gain);
      gain.connect(audioContext.destination);
      
      oscillator.start(0);
      
      return new Promise(resolve => {
        processor.onaudioprocess = (e) => {
          const data = e.inputBuffer.getChannelData(0);
          let sum = 0;
          for (let i = 0; i < data.length; i++) {
            sum += Math.abs(data[i]);
          }
          oscillator.stop();
          audioContext.close();
          resolve({ sum: sum, sampleRate: audioContext.sampleRate });
        };
      });
    } catch (e) {
      return { error: e.message };
    }
  });
  
  console.log(`  Audio result: ${JSON.stringify(result)}`);
  return result;
}

async function runTests() {
  console.log('='.repeat(60));
  console.log('NeoDetect Extension E2E Tests');
  console.log('='.repeat(60));
  
  let browser;
  try {
    browser = await launchBrowserWithExtension();
    const extensionId = await getExtensionId(browser);
    console.log(`Extension ID: ${extensionId}`);
    
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 800 });
    
    // Navigate to test page
    await page.goto('about:blank');
    await new Promise(r => setTimeout(r, 1000));
    
    // Run fingerprint tests
    console.log('\n--- Fingerprint Tests ---\n');
    
    const results = {
      canvas: await testCanvasFingerprint(page),
      webgl: await testWebGLFingerprint(page),
      navigator: await testNavigatorProperties(page),
      screen: await testScreenProperties(page),
      audio: await testAudioFingerprint(page)
    };
    
    // Save results
    fs.writeFileSync(
      path.join(__dirname, 'test-results.json'),
      JSON.stringify(results, null, 2)
    );
    
    console.log('\n--- Test Results Saved ---');
    console.log('Results saved to: test-results.json');
    
    // Open extension popup for screenshot
    const popupUrl = `chrome-extension://${extensionId}/popup/popup.html`;
    await page.goto(popupUrl);
    await new Promise(r => setTimeout(r, 2000));
    
    // Take screenshot of popup
    await page.screenshot({
      path: path.join(SCREENSHOTS_DIR, '01-popup-main.png'),
      clip: { x: 0, y: 0, width: 400, height: 600 }
    });
    console.log('Screenshot saved: 01-popup-main.png');
    
    console.log('\n' + '='.repeat(60));
    console.log('Tests completed successfully!');
    console.log('='.repeat(60));
    
  } catch (error) {
    console.error('Test failed:', error.message);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

runTests();
