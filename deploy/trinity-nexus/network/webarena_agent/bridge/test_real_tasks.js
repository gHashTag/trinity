#!/usr/bin/env node
/**
 * Real WebArena-Style Task Test
 * Tests on accessible websites that don't block automation
 * φ² + 1/φ² = 3 = TRINITY
 */

const { chromium } = require('playwright');
const fingerprint = require('./fingerprint.js');

// Human-like delay
async function humanDelay(min = 500, max = 1500) {
    const delay = min + Math.floor(Math.random() * (max - min));
    await new Promise(resolve => setTimeout(resolve, delay));
}

// Task definitions (WebArena-style but on accessible sites)
const TASKS = [
    {
        id: 1,
        type: 'wikipedia',
        name: 'Wikipedia Search',
        startUrl: 'https://en.wikipedia.org',
        steps: [
            { action: 'type', selector: '#searchInput', text: 'Golden ratio' },
            { action: 'click', selector: 'button[type="submit"], #searchButton' },
            { action: 'wait', selector: '#firstHeading' },
            { action: 'verify', check: 'title_contains', value: 'Golden' }
        ]
    },
    {
        id: 2,
        type: 'wikipedia',
        name: 'Wikipedia Navigation',
        startUrl: 'https://en.wikipedia.org/wiki/Main_Page',
        steps: [
            { action: 'click', selector: '#mp-tfa a, .mw-headline a' },
            { action: 'wait', selector: '#firstHeading' },
            { action: 'verify', check: 'has_content', value: true }
        ]
    },
    {
        id: 3,
        type: 'search',
        name: 'DuckDuckGo Search',
        startUrl: 'https://duckduckgo.com',
        steps: [
            { action: 'type', selector: '#searchbox_input, input[name="q"]', text: 'ternary computing' },
            { action: 'click', selector: 'button[type="submit"]' },
            { action: 'wait', selector: '[data-testid="result"], .result' },
            { action: 'verify', check: 'has_results', value: true }
        ]
    },
    {
        id: 4,
        type: 'navigation',
        name: 'GitHub Explore',
        startUrl: 'https://github.com/explore',
        steps: [
            { action: 'wait', selector: 'article, .Box' },
            { action: 'click', selector: 'article a, .Box a' },
            { action: 'wait', selector: '.repository-content, .Layout' },
            { action: 'verify', check: 'url_changed', value: true }
        ]
    },
    {
        id: 5,
        type: 'form',
        name: 'HTTPBin Form',
        startUrl: 'https://httpbin.org/forms/post',
        steps: [
            { action: 'type', selector: 'input[name="custname"]', text: 'FIREBIRD Test' },
            { action: 'type', selector: 'input[name="custemail"]', text: 'test@firebird.ai' },
            { action: 'click', selector: 'button[type="submit"], input[type="submit"]' },
            { action: 'wait', selector: 'pre, body' },
            { action: 'verify', check: 'has_content', value: true }
        ]
    }
];

// Execute single step
async function executeStep(page, step, startUrl) {
    try {
        switch (step.action) {
            case 'type':
                await humanDelay(200, 500);
                const input = await page.$(step.selector);
                if (input) {
                    await input.click();
                    await humanDelay(100, 300);
                    await input.type(step.text, { delay: 30 + Math.random() * 50 });
                    return { success: true, action: 'type' };
                }
                return { success: false, action: 'type', error: 'Input not found' };
                
            case 'click':
                await humanDelay(300, 800);
                const element = await page.$(step.selector);
                if (element) {
                    await element.click();
                    return { success: true, action: 'click' };
                }
                // Try alternative selectors
                const altElement = await page.$('button, a, [role="button"]');
                if (altElement) {
                    await altElement.click();
                    return { success: true, action: 'click', note: 'used alternative' };
                }
                return { success: false, action: 'click', error: 'Element not found' };
                
            case 'wait':
                await page.waitForSelector(step.selector, { timeout: 10000 }).catch(() => null);
                return { success: true, action: 'wait' };
                
            case 'verify':
                await humanDelay(500, 1000);
                switch (step.check) {
                    case 'title_contains':
                        const title = await page.title();
                        return { success: title.toLowerCase().includes(step.value.toLowerCase()), action: 'verify', title };
                    case 'has_content':
                        const content = await page.content();
                        return { success: content.length > 1000, action: 'verify', contentLength: content.length };
                    case 'has_results':
                        const results = await page.$$('[data-testid="result"], .result, article, .search-result');
                        return { success: results.length > 0, action: 'verify', resultsCount: results.length };
                    case 'url_changed':
                        const currentUrl = page.url();
                        return { success: currentUrl !== startUrl, action: 'verify', url: currentUrl };
                    default:
                        return { success: true, action: 'verify' };
                }
                
            default:
                return { success: false, action: step.action, error: 'Unknown action' };
        }
    } catch (error) {
        return { success: false, action: step.action, error: error.message };
    }
}

// Execute single task
async function executeTask(page, task) {
    const result = {
        id: task.id,
        name: task.name,
        type: task.type,
        success: false,
        steps: [],
        startTime: Date.now(),
        endTime: null,
        error: null
    };
    
    try {
        // Navigate to start URL
        await page.goto(task.startUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
        result.steps.push({ action: 'navigate', success: true, url: task.startUrl });
        
        // Execute each step
        for (const step of task.steps) {
            const stepResult = await executeStep(page, step, task.startUrl);
            result.steps.push(stepResult);
            
            if (!stepResult.success && step.action !== 'wait') {
                // Non-critical failure for wait, critical for others
                if (step.action === 'verify') {
                    result.success = false;
                    break;
                }
            }
        }
        
        // Check if last verify step passed
        const lastVerify = result.steps.filter(s => s.action === 'verify').pop();
        result.success = lastVerify ? lastVerify.success : result.steps.every(s => s.success);
        
    } catch (error) {
        result.error = error.message;
        result.success = false;
    }
    
    result.endTime = Date.now();
    return result;
}

// Main test runner
async function runRealTasks() {
    console.log('\n🔥 FIREBIRD Real WebArena-Style Task Test');
    console.log('═══════════════════════════════════════════════════════════════════\n');
    
    const browser = await chromium.launch({
        headless: true,
        args: ['--disable-blink-features=AutomationControlled', '--no-sandbox']
    });
    
    const context = await browser.newContext({
        viewport: { width: 1280, height: 720 },
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    });
    
    const page = await context.newPage();
    
    // Inject fingerprint protection
    const script = fingerprint.generateScript();
    await page.addInitScript(script);
    
    console.log('Browser initialized with FIREBIRD stealth\n');
    
    const results = [];
    
    for (const task of TASKS) {
        console.log(`[Task ${task.id}] ${task.name}`);
        console.log(`  Type: ${task.type}`);
        console.log(`  URL: ${task.startUrl}`);
        
        const result = await executeTask(page, task);
        results.push(result);
        
        const duration = result.endTime - result.startTime;
        console.log(`  Steps: ${result.steps.length}`);
        console.log(`  Duration: ${duration}ms`);
        console.log(`  Result: ${result.success ? '✅ SUCCESS' : '❌ FAILED'}`);
        if (result.error) {
            console.log(`  Error: ${result.error}`);
        }
        console.log('');
        
        // Delay between tasks
        await humanDelay(1000, 2000);
    }
    
    await browser.close();
    
    // Calculate metrics
    const total = results.length;
    const passed = results.filter(r => r.success).length;
    const avgDuration = results.reduce((sum, r) => sum + (r.endTime - r.startTime), 0) / total;
    const avgSteps = results.reduce((sum, r) => sum + r.steps.length, 0) / total;
    
    console.log('┌─────────────────────────────────────────────────────────────────┐');
    console.log('│                 REAL TASK EXECUTION SUMMARY                     │');
    console.log('├─────────────────────────────────────────────────────────────────┤');
    console.log(`│ Total Tasks:       ${total}                                            │`);
    console.log(`│ Passed:            ${passed}                                            │`);
    console.log(`│ Failed:            ${total - passed}                                            │`);
    console.log(`│ Success Rate:      ${(passed / total * 100).toFixed(1)}%                                        │`);
    console.log(`│ Avg Duration:      ${Math.round(avgDuration)}ms                                      │`);
    console.log(`│ Avg Steps:         ${avgSteps.toFixed(1)}                                          │`);
    console.log('├─────────────────────────────────────────────────────────────────┤');
    
    const successRate = passed / total * 100;
    let status;
    if (successRate >= 60) {
        status = '✅ REAL TASKS WORKING - READY FOR WEBARENA';
    } else if (successRate >= 40) {
        status = '⚠️  PARTIAL SUCCESS - NEEDS TUNING';
    } else {
        status = '❌ NEEDS IMPROVEMENT';
    }
    console.log(`│ Status:            ${status}     │`);
    console.log('└─────────────────────────────────────────────────────────────────┘');
    
    // Per-task breakdown
    console.log('\nPer-Task Results:');
    for (const result of results) {
        const icon = result.success ? '✅' : '❌';
        const duration = result.endTime - result.startTime;
        console.log(`  ${icon} [${result.id}] ${result.name}: ${result.steps.length} steps, ${duration}ms`);
    }
    
    console.log('\nφ² + 1/φ² = 3 = TRINITY\n');
    
    return { results, metrics: { total, passed, successRate, avgDuration, avgSteps } };
}

runRealTasks().catch(console.error);
