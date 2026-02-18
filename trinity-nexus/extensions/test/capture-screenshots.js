/**
 * NeoDetect Screenshot Capture for Chrome Web Store
 * Captures popup screenshots at 1280x800 resolution
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
    headless: false,
    args: [
      `--disable-extensions-except=${EXTENSION_PATH}`,
      `--load-extension=${EXTENSION_PATH}`,
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--window-size=1400,900'
    ]
  });
  return browser;
}

async function getExtensionId(browser) {
  await new Promise(r => setTimeout(r, 3000));
  
  const targets = await browser.targets();
  const extensionTarget = targets.find(target => 
    target.type() === 'service_worker' && 
    target.url().includes('chrome-extension://')
  );
  
  if (!extensionTarget) {
    throw new Error('Extension service worker not found');
  }
  
  const extensionUrl = extensionTarget.url();
  const extensionId = extensionUrl.split('/')[2];
  return extensionId;
}

async function captureScreenshots() {
  console.log('='.repeat(60));
  console.log('NeoDetect Screenshot Capture');
  console.log('='.repeat(60));
  
  let browser;
  try {
    browser = await launchBrowserWithExtension();
    const extensionId = await getExtensionId(browser);
    console.log(`Extension ID: ${extensionId}`);
    
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 800 });
    
    const popupUrl = `chrome-extension://${extensionId}/popup/popup.html`;
    
    // Screenshot 1: Main popup with default settings
    console.log('\nCapturing Screenshot 1: Main Popup...');
    await page.goto(popupUrl);
    await new Promise(r => setTimeout(r, 2000));
    
    await page.screenshot({
      path: path.join(SCREENSHOTS_DIR, '01-popup-main.png'),
      fullPage: false
    });
    console.log('  Saved: 01-popup-main.png');
    
    // Screenshot 2: Change OS/Hardware settings
    console.log('\nCapturing Screenshot 2: OS/Hardware Selection...');
    
    // Try to interact with dropdowns if they exist
    try {
      // Select Windows 11
      await page.select('#os-select', '1');
      await new Promise(r => setTimeout(r, 500));
      
      // Select Intel i7
      await page.select('#hw-select', '1');
      await new Promise(r => setTimeout(r, 500));
      
      // Select NVIDIA RTX 4070
      await page.select('#gpu-select', '1');
      await new Promise(r => setTimeout(r, 500));
    } catch (e) {
      console.log('  Note: Could not interact with dropdowns');
    }
    
    await page.screenshot({
      path: path.join(SCREENSHOTS_DIR, '02-settings.png'),
      fullPage: false
    });
    console.log('  Saved: 02-settings.png');
    
    // Screenshot 3: Navigate to fingerprint test page
    console.log('\nCapturing Screenshot 3: Fingerprint Test Page...');
    
    const testPage = await browser.newPage();
    await testPage.setViewport({ width: 1280, height: 800 });
    await testPage.goto('https://browserleaks.com/canvas', { 
      waitUntil: 'networkidle2',
      timeout: 30000 
    }).catch(() => {
      console.log('  Note: Could not load browserleaks.com, using local test');
    });
    
    await new Promise(r => setTimeout(r, 3000));
    
    await testPage.screenshot({
      path: path.join(SCREENSHOTS_DIR, '03-fingerprint-test.png'),
      fullPage: false
    });
    console.log('  Saved: 03-fingerprint-test.png');
    
    // List all screenshots
    console.log('\n' + '='.repeat(60));
    console.log('Screenshots captured:');
    const files = fs.readdirSync(SCREENSHOTS_DIR);
    files.forEach(f => {
      const stats = fs.statSync(path.join(SCREENSHOTS_DIR, f));
      console.log(`  ${f} (${Math.round(stats.size / 1024)}KB)`);
    });
    console.log('='.repeat(60));
    
  } catch (error) {
    console.error('Screenshot capture failed:', error.message);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

captureScreenshots();
