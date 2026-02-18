#!/usr/bin/env node
/**
 * Real Playwright Spawn Test
 * Tests actual browser launch and navigation
 * φ² + 1/φ² = 3 = TRINITY
 */

const { chromium } = require('playwright');

async function testRealSpawn() {
    console.log('\n🔥 FIREBIRD Real Playwright Spawn Test');
    console.log('═══════════════════════════════════════════════════════════════════\n');
    
    const results = {
        launch: false,
        navigate: false,
        screenshot: false,
        accessibilityTree: false,
        close: false
    };
    
    let browser = null;
    
    try {
        // Test 1: Launch browser
        console.log('[1/5] Launching Chromium (headless)...');
        browser = await chromium.launch({ 
            headless: true,
            args: ['--disable-blink-features=AutomationControlled']
        });
        results.launch = true;
        console.log('  ✅ Browser launched');
        
        // Create context with stealth settings
        const context = await browser.newContext({
            viewport: { width: 1280, height: 720 },
            userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        });
        
        const page = await context.newPage();
        
        // Test 2: Navigate to URL
        console.log('[2/5] Navigating to https://example.com...');
        await page.goto('https://example.com', { waitUntil: 'domcontentloaded' });
        const url = page.url();
        const title = await page.title();
        results.navigate = url.includes('example.com');
        console.log(`  ✅ Navigated to: ${url}`);
        console.log(`  ✅ Title: ${title}`);
        
        // Test 3: Take screenshot
        console.log('[3/5] Taking screenshot...');
        const screenshot = await page.screenshot();
        results.screenshot = screenshot.length > 1000;
        console.log(`  ✅ Screenshot: ${screenshot.length} bytes`);
        
        // Test 4: Get accessibility tree
        console.log('[4/5] Getting accessibility tree...');
        const elements = await page.evaluate(() => {
            const els = [];
            const walker = document.createTreeWalker(
                document.body,
                NodeFilter.SHOW_ELEMENT,
                null,
                false
            );
            let id = 0;
            let node;
            while ((node = walker.nextNode()) && id < 50) {
                const rect = node.getBoundingClientRect();
                if (rect.width > 0 && rect.height > 0) {
                    els.push({
                        id: id++,
                        tag: node.tagName.toLowerCase(),
                        text: (node.textContent || '').slice(0, 50).trim()
                    });
                }
            }
            return els;
        });
        results.accessibilityTree = elements.length > 0;
        console.log(`  ✅ Found ${elements.length} elements`);
        
        // Test 5: Close browser
        console.log('[5/5] Closing browser...');
        await browser.close();
        browser = null;
        results.close = true;
        console.log('  ✅ Browser closed');
        
    } catch (error) {
        console.error(`  ❌ Error: ${error.message}`);
    } finally {
        if (browser) {
            await browser.close();
        }
    }
    
    // Summary
    const passed = Object.values(results).filter(v => v).length;
    const total = Object.keys(results).length;
    
    console.log('\n');
    console.log('┌─────────────────────────────────────────────────────────────────┐');
    console.log('│                 REAL SPAWN TEST SUMMARY                         │');
    console.log('├─────────────────────────────────────────────────────────────────┤');
    console.log(`│ Launch:            ${results.launch ? '✅ PASS' : '❌ FAIL'}                                       │`);
    console.log(`│ Navigate:          ${results.navigate ? '✅ PASS' : '❌ FAIL'}                                       │`);
    console.log(`│ Screenshot:        ${results.screenshot ? '✅ PASS' : '❌ FAIL'}                                       │`);
    console.log(`│ Accessibility:     ${results.accessibilityTree ? '✅ PASS' : '❌ FAIL'}                                       │`);
    console.log(`│ Close:             ${results.close ? '✅ PASS' : '❌ FAIL'}                                       │`);
    console.log('├─────────────────────────────────────────────────────────────────┤');
    console.log(`│ TOTAL: ${passed}/${total} tests passed                                       │`);
    console.log(`│ STATUS: ${passed === total ? '✅ ALL TESTS PASS - REAL BROWSER WORKS!' : '⚠️  SOME TESTS FAILED'}              │`);
    console.log('└─────────────────────────────────────────────────────────────────┘');
    console.log('\nφ² + 1/φ² = 3 = TRINITY\n');
    
    return passed === total;
}

testRealSpawn()
    .then(success => process.exit(success ? 0 : 1))
    .catch(err => {
        console.error('Fatal error:', err);
        process.exit(1);
    });
