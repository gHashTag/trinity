#!/usr/bin/env node
/**
 * Test Bridge with Real Browser
 * Direct API test without stdin/stdout
 * φ² + 1/φ² = 3 = TRINITY
 */

const bridge = require('./playwright_bridge.js');

async function testBridge() {
    console.log('\n🔥 FIREBIRD Bridge Real Test');
    console.log('═══════════════════════════════════════════════════════════════════\n');
    
    const results = {
        connect: false,
        navigate: false,
        getState: false,
        screenshot: false,
        accessibilityTree: false,
        disconnect: false
    };
    
    try {
        // Test 1: Connect
        console.log('[1/6] Testing connect...');
        const connectResult = await bridge.handleRequest({
            jsonrpc: '2.0',
            id: 1,
            method: 'connect',
            params: { headless: true, stealth: true }
        });
        results.connect = connectResult.result && !connectResult.result.mock;
        console.log(`  Result: ${JSON.stringify(connectResult.result).slice(0, 100)}`);
        console.log(`  Real browser: ${!connectResult.result?.mock}`);
        
        // Test 2: Navigate
        console.log('[2/6] Testing navigate...');
        const navResult = await bridge.handleRequest({
            jsonrpc: '2.0',
            id: 2,
            method: 'navigate',
            params: { url: 'https://example.com' }
        });
        results.navigate = navResult.result && navResult.result.success;
        console.log(`  URL: ${navResult.result?.url}`);
        console.log(`  Title: ${navResult.result?.title}`);
        
        // Test 3: Get State
        console.log('[3/6] Testing getState...');
        const stateResult = await bridge.handleRequest({
            jsonrpc: '2.0',
            id: 3,
            method: 'getState'
        });
        results.getState = stateResult.result && stateResult.result.url;
        console.log(`  URL: ${stateResult.result?.url}`);
        console.log(`  Elements: ${stateResult.result?.elementsCount}`);
        
        // Test 4: Screenshot
        console.log('[4/6] Testing screenshot...');
        const screenshotResult = await bridge.handleRequest({
            jsonrpc: '2.0',
            id: 4,
            method: 'screenshot'
        });
        results.screenshot = screenshotResult.result && screenshotResult.result.data?.length > 100;
        console.log(`  Size: ${screenshotResult.result?.data?.length || 0} bytes`);
        
        // Test 5: Accessibility Tree
        console.log('[5/6] Testing getAccessibilityTree...');
        const treeResult = await bridge.handleRequest({
            jsonrpc: '2.0',
            id: 5,
            method: 'getAccessibilityTree'
        });
        results.accessibilityTree = treeResult.result && treeResult.result.tree?.length > 0;
        console.log(`  Elements: ${treeResult.result?.tree?.length || 0}`);
        
        // Test 6: Disconnect
        console.log('[6/6] Testing disconnect...');
        const disconnectResult = await bridge.handleRequest({
            jsonrpc: '2.0',
            id: 6,
            method: 'disconnect'
        });
        results.disconnect = disconnectResult.result && disconnectResult.result.success;
        console.log(`  Success: ${disconnectResult.result?.success}`);
        
    } catch (error) {
        console.error(`Error: ${error.message}`);
    }
    
    // Summary
    const passed = Object.values(results).filter(v => v).length;
    const total = Object.keys(results).length;
    
    console.log('\n');
    console.log('┌─────────────────────────────────────────────────────────────────┐');
    console.log('│                 BRIDGE REAL TEST SUMMARY                        │');
    console.log('├─────────────────────────────────────────────────────────────────┤');
    console.log(`│ Connect:           ${results.connect ? '✅ PASS (REAL)' : '❌ FAIL/MOCK'}                                │`);
    console.log(`│ Navigate:          ${results.navigate ? '✅ PASS' : '❌ FAIL'}                                       │`);
    console.log(`│ Get State:         ${results.getState ? '✅ PASS' : '❌ FAIL'}                                       │`);
    console.log(`│ Screenshot:        ${results.screenshot ? '✅ PASS' : '❌ FAIL'}                                       │`);
    console.log(`│ Accessibility:     ${results.accessibilityTree ? '✅ PASS' : '❌ FAIL'}                                       │`);
    console.log(`│ Disconnect:        ${results.disconnect ? '✅ PASS' : '❌ FAIL'}                                       │`);
    console.log('├─────────────────────────────────────────────────────────────────┤');
    console.log(`│ TOTAL: ${passed}/${total} tests passed                                       │`);
    console.log(`│ STATUS: ${passed === total ? '✅ ALL TESTS PASS - REAL BROWSER!' : '⚠️  SOME TESTS FAILED'}                │`);
    console.log('└─────────────────────────────────────────────────────────────────┘');
    console.log('\nφ² + 1/φ² = 3 = TRINITY\n');
    
    return passed === total;
}

testBridge()
    .then(success => process.exit(success ? 0 : 1))
    .catch(err => {
        console.error('Fatal error:', err);
        process.exit(1);
    });
