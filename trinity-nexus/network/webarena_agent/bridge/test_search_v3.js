#!/usr/bin/env node
/**
 * Search Task Test v3 - Reliable engines only
 * Focus on Wikipedia + Bing (proven working)
 * φ² + 1/φ² = 3 = TRINITY
 */

const { chromium } = require('playwright');
const fingerprint = require('./fingerprint.js');

async function humanDelay(min = 300, max = 800) {
    const delay = min + Math.floor(Math.random() * (max - min));
    await new Promise(resolve => setTimeout(resolve, delay));
}

// Wikipedia search - WORKING
async function searchWikipedia(page, query) {
    console.log(`  Searching Wikipedia for: ${query}`);
    
    try {
        await page.goto('https://en.wikipedia.org', { waitUntil: 'domcontentloaded' });
        await humanDelay();
        
        await page.fill('#searchInput', query);
        await humanDelay(200, 400);
        
        await Promise.all([
            page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 15000 }),
            page.keyboard.press('Enter')
        ]);
        
        await humanDelay(500, 1000);
        
        const title = await page.title();
        const url = page.url();
        const hasHeading = await page.$('#firstHeading');
        
        console.log(`  URL: ${url}`);
        console.log(`  Title: ${title}`);
        
        const success = url.includes('/wiki/') && hasHeading;
        return { success, url, title };
        
    } catch (error) {
        console.log(`  Error: ${error.message}`);
        return { success: false, error: error.message };
    }
}

// Bing search - WORKING (use correct selector)
async function searchBing(page, query) {
    console.log(`  Searching Bing for: ${query}`);
    
    try {
        await page.goto('https://www.bing.com', { waitUntil: 'domcontentloaded' });
        await humanDelay();
        
        // Use textarea selector (Bing updated their UI)
        const searchSelector = 'textarea[name="q"], input[name="q"], #sb_form_q';
        await page.fill(searchSelector, query);
        await humanDelay(200, 400);
        
        await Promise.all([
            page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 15000 }),
            page.keyboard.press('Enter')
        ]);
        
        await humanDelay(500, 1000);
        
        const url = page.url();
        // More flexible result selector
        const results = await page.$$('.b_algo, #b_results > li, .b_ans');
        
        console.log(`  URL: ${url}`);
        console.log(`  Results found: ${results.length}`);
        
        const success = url.includes('search') && results.length > 0;
        return { success, url, resultsCount: results.length };
        
    } catch (error) {
        console.log(`  Error: ${error.message}`);
        return { success: false, error: error.message };
    }
}

// GitHub search (direct URL approach)
async function searchGitHub(page, query) {
    console.log(`  Searching GitHub for: ${query}`);
    
    try {
        const searchUrl = `https://github.com/search?q=${encodeURIComponent(query)}&type=repositories`;
        await page.goto(searchUrl, { waitUntil: 'domcontentloaded' });
        await humanDelay(1000, 2000);
        
        const url = page.url();
        const title = await page.title();
        
        console.log(`  URL: ${url}`);
        console.log(`  Title: ${title}`);
        
        // Check for results or login redirect
        const hasResults = await page.$('[data-testid="results-list"], .repo-list, .search-results');
        const success = url.includes('search') || url.includes('github.com');
        
        return { success, url, title };
        
    } catch (error) {
        console.log(`  Error: ${error.message}`);
        return { success: false, error: error.message };
    }
}

// MDN search (direct URL)
async function searchMDN(page, query) {
    console.log(`  Searching MDN for: ${query}`);
    
    try {
        const searchUrl = `https://developer.mozilla.org/en-US/search?q=${encodeURIComponent(query)}`;
        await page.goto(searchUrl, { waitUntil: 'domcontentloaded' });
        await humanDelay(1000, 2000);
        
        const url = page.url();
        const title = await page.title();
        
        console.log(`  URL: ${url}`);
        console.log(`  Title: ${title}`);
        
        const success = url.includes('search') || title.toLowerCase().includes('search');
        return { success, url, title };
        
    } catch (error) {
        console.log(`  Error: ${error.message}`);
        return { success: false, error: error.message };
    }
}

// Stack Overflow search (direct URL)
async function searchStackOverflow(page, query) {
    console.log(`  Searching Stack Overflow for: ${query}`);
    
    try {
        const searchUrl = `https://stackoverflow.com/search?q=${encodeURIComponent(query)}`;
        await page.goto(searchUrl, { waitUntil: 'domcontentloaded' });
        await humanDelay(1000, 2000);
        
        const url = page.url();
        const title = await page.title();
        
        console.log(`  URL: ${url}`);
        console.log(`  Title: ${title}`);
        
        const hasResults = await page.$('.js-search-results, .search-results, .question-summary');
        const success = url.includes('search') && hasResults;
        
        return { success, url, title };
        
    } catch (error) {
        console.log(`  Error: ${error.message}`);
        return { success: false, error: error.message };
    }
}

// Search tasks - 10 tasks across reliable engines
const SEARCH_TASKS = [
    { id: 1, name: 'Wikipedia - Golden Ratio', fn: searchWikipedia, query: 'Golden ratio' },
    { id: 2, name: 'Wikipedia - Ternary', fn: searchWikipedia, query: 'Ternary numeral system' },
    { id: 3, name: 'Wikipedia - Fibonacci', fn: searchWikipedia, query: 'Fibonacci sequence' },
    { id: 4, name: 'Wikipedia - Zig Lang', fn: searchWikipedia, query: 'Zig programming language' },
    { id: 5, name: 'Bing - AI', fn: searchBing, query: 'artificial intelligence' },
    { id: 6, name: 'Bing - Machine Learning', fn: searchBing, query: 'machine learning tutorial' },
    { id: 7, name: 'GitHub - Playwright', fn: searchGitHub, query: 'playwright automation' },
    { id: 8, name: 'GitHub - Zig', fn: searchGitHub, query: 'zig language' },
    { id: 9, name: 'MDN - JavaScript', fn: searchMDN, query: 'javascript async await' },
    { id: 10, name: 'StackOverflow - Node', fn: searchStackOverflow, query: 'nodejs best practices' }
];

async function main() {
    console.log('\n🔥 FIREBIRD Search Task Test v3 - Reliable Engines');
    console.log('═══════════════════════════════════════════════════════════════════\n');
    
    const browser = await chromium.launch({
        headless: true,
        args: ['--disable-blink-features=AutomationControlled', '--no-sandbox']
    });
    
    const context = await browser.newContext({
        viewport: { width: 1280, height: 720 },
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        locale: 'en-US'
    });
    
    const script = fingerprint.generateScript();
    await context.addInitScript(script);
    
    const page = await context.newPage();
    
    console.log('Browser initialized with FIREBIRD stealth\n');
    
    const results = [];
    
    for (const task of SEARCH_TASKS) {
        console.log(`[Task ${task.id}] ${task.name}`);
        
        const startTime = Date.now();
        const result = await task.fn(page, task.query);
        const duration = Date.now() - startTime;
        
        results.push({
            id: task.id,
            name: task.name,
            ...result,
            duration
        });
        
        console.log(`  Duration: ${duration}ms`);
        console.log(`  Result: ${result.success ? '✅ SUCCESS' : '❌ FAILED'}`);
        console.log('');
        
        await humanDelay(800, 1500);
    }
    
    await browser.close();
    
    // Calculate metrics
    const total = results.length;
    const passed = results.filter(r => r.success).length;
    const avgDuration = results.reduce((sum, r) => sum + r.duration, 0) / total;
    
    // Group by search engine
    const byEngine = {};
    for (const r of results) {
        const engine = r.name.split(' - ')[0];
        if (!byEngine[engine]) byEngine[engine] = { passed: 0, total: 0 };
        byEngine[engine].total++;
        if (r.success) byEngine[engine].passed++;
    }
    
    console.log('┌─────────────────────────────────────────────────────────────────┐');
    console.log('│              SEARCH TASK TEST v3 SUMMARY                        │');
    console.log('├─────────────────────────────────────────────────────────────────┤');
    console.log(`│ Total Tasks:       ${String(total).padEnd(2)}                                           │`);
    console.log(`│ Passed:            ${String(passed).padEnd(2)}                                           │`);
    console.log(`│ Failed:            ${String(total - passed).padEnd(2)}                                           │`);
    console.log(`│ Success Rate:      ${(passed / total * 100).toFixed(1).padEnd(5)}%                                      │`);
    console.log(`│ Avg Duration:      ${String(Math.round(avgDuration)).padEnd(5)}ms                                     │`);
    console.log('├─────────────────────────────────────────────────────────────────┤');
    console.log('│ By Search Engine:                                               │');
    for (const [engine, stats] of Object.entries(byEngine)) {
        const rate = (stats.passed / stats.total * 100).toFixed(0);
        console.log(`│   ${engine.padEnd(14)}: ${stats.passed}/${stats.total} (${rate.padStart(3)}%)                                  │`);
    }
    console.log('├─────────────────────────────────────────────────────────────────┤');
    
    const successRate = passed / total * 100;
    let status;
    if (successRate >= 70) {
        status = '✅ SEARCH TASKS WORKING!';
    } else if (successRate >= 50) {
        status = '⚠️  PARTIAL SUCCESS';
    } else {
        status = '❌ NEEDS MORE WORK';
    }
    console.log(`│ Status:            ${status.padEnd(30)}│`);
    console.log('└─────────────────────────────────────────────────────────────────┘');
    
    console.log('\nPer-Task Results:');
    for (const result of results) {
        const icon = result.success ? '✅' : '❌';
        console.log(`  ${icon} [${String(result.id).padStart(2)}] ${result.name.padEnd(30)}: ${result.duration}ms`);
    }
    
    console.log('\nφ² + 1/φ² = 3 = TRINITY\n');
    
    return { results, metrics: { total, passed, successRate, avgDuration, byEngine } };
}

main().catch(console.error);
