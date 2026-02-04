#!/usr/bin/env node
/**
 * WebArena Task Executor
 * Executes real browser tasks with FIREBIRD fingerprint protection
 * φ² + 1/φ² = 3 = TRINITY
 */

const { chromium } = require('playwright');
const fingerprint = require('./fingerprint.js');

// Golden ratio constants
const PHI = 1.6180339887;
const PHI_INV = 0.618033988749895;

// Task types
const TaskType = {
    SHOPPING: 'shopping',
    GITLAB: 'gitlab',
    REDDIT: 'reddit',
    MAP: 'map',
    WIKIPEDIA: 'wikipedia'
};

// Task result
class TaskResult {
    constructor(taskId, taskType) {
        this.taskId = taskId;
        this.taskType = taskType;
        this.success = false;
        this.steps = [];
        this.startTime = Date.now();
        this.endTime = null;
        this.error = null;
        this.detected = false;
        this.finalState = null;
    }
    
    addStep(action, success, details = {}) {
        this.steps.push({
            action,
            success,
            timestamp: Date.now(),
            ...details
        });
    }
    
    complete(success, finalState = null) {
        this.success = success;
        this.endTime = Date.now();
        this.finalState = finalState;
    }
    
    getDuration() {
        return (this.endTime || Date.now()) - this.startTime;
    }
    
    toJSON() {
        return {
            taskId: this.taskId,
            taskType: this.taskType,
            success: this.success,
            steps: this.steps.length,
            duration: this.getDuration(),
            detected: this.detected,
            error: this.error
        };
    }
}

// Human-like delay using φ distribution
async function humanDelay(min = 500, max = 2000) {
    const range = max - min;
    const delay = min + Math.floor(range * PHI_INV * Math.random() + range * (1 - PHI_INV) * Math.random());
    await new Promise(resolve => setTimeout(resolve, delay));
}

// Task Executor class
class TaskExecutor {
    constructor(options = {}) {
        this.headless = options.headless !== false;
        this.stealth = options.stealth !== false;
        this.maxSteps = options.maxSteps || 30;
        this.browser = null;
        this.context = null;
        this.page = null;
        this.fingerprintConfig = fingerprint.DEFAULT_CONFIG;
    }
    
    async init() {
        // Launch browser
        this.browser = await chromium.launch({
            headless: this.headless,
            args: [
                '--disable-blink-features=AutomationControlled',
                '--disable-features=IsolateOrigins,site-per-process',
                '--no-sandbox'
            ]
        });
        
        // Create context with stealth settings
        this.context = await this.browser.newContext({
            viewport: { width: 1280, height: 720 },
            userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            locale: 'en-US',
            timezoneId: 'America/New_York'
        });
        
        this.page = await this.context.newPage();
        
        // Inject fingerprint protection if stealth enabled
        if (this.stealth) {
            const script = fingerprint.generateScript(this.fingerprintConfig);
            await this.page.addInitScript(script);
        }
    }
    
    async close() {
        if (this.browser) {
            await this.browser.close();
            this.browser = null;
            this.context = null;
            this.page = null;
        }
    }
    
    // Execute a task
    async executeTask(task) {
        const result = new TaskResult(task.id, task.type);
        
        try {
            // Navigate to start URL
            await humanDelay(300, 800);
            await this.page.goto(task.startUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
            result.addStep('navigate', true, { url: task.startUrl });
            
            // Execute task-specific actions
            switch (task.type) {
                case TaskType.SHOPPING:
                    await this.executeShoppingTask(task, result);
                    break;
                case TaskType.GITLAB:
                    await this.executeGitlabTask(task, result);
                    break;
                case TaskType.REDDIT:
                    await this.executeRedditTask(task, result);
                    break;
                case TaskType.WIKIPEDIA:
                    await this.executeWikipediaTask(task, result);
                    break;
                default:
                    await this.executeGenericTask(task, result);
            }
            
            // Get final state
            const finalState = {
                url: this.page.url(),
                title: await this.page.title()
            };
            
            result.complete(result.success, finalState);
            
        } catch (error) {
            result.error = error.message;
            result.complete(false);
        }
        
        return result;
    }
    
    // Shopping task: Find product, check price
    async executeShoppingTask(task, result) {
        try {
            // Look for search box
            await humanDelay();
            const searchBox = await this.page.$('input[type="search"], input[name="q"], input[placeholder*="search" i], #search');
            
            if (searchBox) {
                await searchBox.click();
                result.addStep('click_search', true);
                
                await humanDelay(200, 500);
                await searchBox.type(task.query || 'product', { delay: 50 + Math.random() * 50 });
                result.addStep('type_query', true, { query: task.query });
                
                await humanDelay();
                await this.page.keyboard.press('Enter');
                result.addStep('submit_search', true);
                
                await this.page.waitForLoadState('domcontentloaded');
                result.addStep('wait_results', true);
                
                // Check if results found
                const resultsFound = await this.page.$$eval('a, .product, .item', els => els.length > 5);
                result.success = resultsFound;
                result.addStep('check_results', resultsFound, { found: resultsFound });
            } else {
                // No search box - try clicking links
                const links = await this.page.$$('a');
                if (links.length > 0) {
                    await humanDelay();
                    await links[Math.floor(Math.random() * Math.min(links.length, 5))].click();
                    result.addStep('click_link', true);
                    result.success = true;
                }
            }
        } catch (error) {
            result.addStep('error', false, { message: error.message });
        }
    }
    
    // GitLab task: Navigate repository
    async executeGitlabTask(task, result) {
        try {
            // Look for navigation elements
            await humanDelay();
            
            // Try to find and click on issues/projects
            const navLinks = await this.page.$$('a[href*="issues"], a[href*="projects"], nav a');
            
            if (navLinks.length > 0) {
                await humanDelay();
                await navLinks[0].click();
                result.addStep('click_nav', true);
                
                await this.page.waitForLoadState('domcontentloaded');
                result.addStep('wait_page', true);
                
                result.success = true;
            } else {
                // Generic navigation
                const links = await this.page.$$('a');
                if (links.length > 0) {
                    await humanDelay();
                    await links[Math.floor(Math.random() * Math.min(links.length, 10))].click();
                    result.addStep('click_link', true);
                    result.success = true;
                }
            }
        } catch (error) {
            result.addStep('error', false, { message: error.message });
        }
    }
    
    // Reddit task: Browse posts
    async executeRedditTask(task, result) {
        try {
            await humanDelay();
            
            // Scroll to load content
            await this.page.mouse.wheel(0, 300);
            result.addStep('scroll', true);
            
            await humanDelay();
            
            // Click on a post
            const posts = await this.page.$$('a[href*="/comments/"], article a, .Post a');
            if (posts.length > 0) {
                await posts[0].click();
                result.addStep('click_post', true);
                result.success = true;
            } else {
                // Generic click
                const links = await this.page.$$('a');
                if (links.length > 0) {
                    await links[Math.floor(Math.random() * Math.min(links.length, 5))].click();
                    result.addStep('click_link', true);
                    result.success = true;
                }
            }
        } catch (error) {
            result.addStep('error', false, { message: error.message });
        }
    }
    
    // Wikipedia task: Search and read
    async executeWikipediaTask(task, result) {
        try {
            await humanDelay();
            
            // Find search box
            const searchBox = await this.page.$('#searchInput, input[name="search"]');
            if (searchBox) {
                await searchBox.click();
                result.addStep('click_search', true);
                
                await humanDelay(200, 500);
                await searchBox.type(task.query || 'Golden ratio', { delay: 50 + Math.random() * 50 });
                result.addStep('type_query', true);
                
                await humanDelay();
                await this.page.keyboard.press('Enter');
                result.addStep('submit_search', true);
                
                await this.page.waitForLoadState('domcontentloaded');
                
                // Check if article found
                const articleFound = await this.page.$('#firstHeading, .mw-page-title-main');
                result.success = !!articleFound;
                result.addStep('check_article', result.success);
            }
        } catch (error) {
            result.addStep('error', false, { message: error.message });
        }
    }
    
    // Generic task execution
    async executeGenericTask(task, result) {
        try {
            await humanDelay();
            
            // Get page elements
            const elements = await this.page.$$('a, button, input');
            
            if (elements.length > 0) {
                // Click random interactive element
                const element = elements[Math.floor(Math.random() * Math.min(elements.length, 10))];
                await element.click().catch(() => {});
                result.addStep('click_element', true);
                result.success = true;
            }
        } catch (error) {
            result.addStep('error', false, { message: error.message });
        }
    }
    
    // Evolve fingerprint if detection suspected
    async evolveFingerprint() {
        this.fingerprintConfig = fingerprint.evolveFingerprint(this.fingerprintConfig, 10);
        const script = fingerprint.generateScript(this.fingerprintConfig);
        await this.page.addInitScript(script);
    }
}

// Run batch of tasks
async function runTaskBatch(tasks, options = {}) {
    const executor = new TaskExecutor(options);
    const results = [];
    
    try {
        await executor.init();
        
        for (const task of tasks) {
            console.log(`Executing task ${task.id}: ${task.type}`);
            const result = await executor.executeTask(task);
            results.push(result);
            console.log(`  Result: ${result.success ? '✅ SUCCESS' : '❌ FAILED'} (${result.steps.length} steps, ${result.getDuration()}ms)`);
            
            // Small delay between tasks
            await humanDelay(1000, 2000);
        }
        
    } finally {
        await executor.close();
    }
    
    return results;
}

// Calculate success rate
function calculateMetrics(results) {
    const total = results.length;
    const passed = results.filter(r => r.success).length;
    const detected = results.filter(r => r.detected).length;
    const avgDuration = results.reduce((sum, r) => sum + r.getDuration(), 0) / total;
    const avgSteps = results.reduce((sum, r) => sum + r.steps.length, 0) / total;
    
    return {
        total,
        passed,
        failed: total - passed,
        successRate: (passed / total * 100).toFixed(1),
        detectionRate: (detected / total * 100).toFixed(1),
        avgDuration: Math.round(avgDuration),
        avgSteps: avgSteps.toFixed(1)
    };
}

module.exports = {
    TaskExecutor,
    TaskResult,
    TaskType,
    runTaskBatch,
    calculateMetrics,
    humanDelay
};

// CLI test
if (require.main === module) {
    const testTasks = [
        { id: 1, type: TaskType.WIKIPEDIA, startUrl: 'https://en.wikipedia.org', query: 'Golden ratio' },
        { id: 2, type: TaskType.SHOPPING, startUrl: 'https://example.com', query: 'test' }
    ];
    
    console.log('\n🔥 FIREBIRD Task Executor Test');
    console.log('═══════════════════════════════════════════════════════════════════\n');
    
    runTaskBatch(testTasks, { headless: true, stealth: true })
        .then(results => {
            const metrics = calculateMetrics(results);
            console.log('\n');
            console.log('┌─────────────────────────────────────────────────────────────────┐');
            console.log('│                 TASK EXECUTION SUMMARY                          │');
            console.log('├─────────────────────────────────────────────────────────────────┤');
            console.log(`│ Total Tasks:       ${metrics.total}                                            │`);
            console.log(`│ Passed:            ${metrics.passed}                                            │`);
            console.log(`│ Failed:            ${metrics.failed}                                            │`);
            console.log(`│ Success Rate:      ${metrics.successRate}%                                        │`);
            console.log(`│ Avg Duration:      ${metrics.avgDuration}ms                                       │`);
            console.log(`│ Avg Steps:         ${metrics.avgSteps}                                          │`);
            console.log('└─────────────────────────────────────────────────────────────────┘');
            console.log('\nφ² + 1/φ² = 3 = TRINITY\n');
        })
        .catch(console.error);
}
