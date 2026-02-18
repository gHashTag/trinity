#!/usr/bin/env node
/**
 * Shopping Task Test
 * Tests real browser shopping-style navigation
 * φ² + 1/φ² = 3 = TRINITY
 */

const { TaskExecutor, TaskType, calculateMetrics } = require('./task_executor.js');

async function testShoppingTasks() {
    console.log('\n🔥 FIREBIRD Shopping Task Test');
    console.log('═══════════════════════════════════════════════════════════════════\n');
    
    // Shopping-style tasks on real websites
    const tasks = [
        {
            id: 1,
            type: TaskType.SHOPPING,
            startUrl: 'https://www.amazon.com',
            query: 'laptop',
            description: 'Search for laptop on Amazon'
        },
        {
            id: 2,
            type: TaskType.SHOPPING,
            startUrl: 'https://www.ebay.com',
            query: 'phone',
            description: 'Search for phone on eBay'
        },
        {
            id: 3,
            type: TaskType.SHOPPING,
            startUrl: 'https://www.etsy.com',
            query: 'handmade',
            description: 'Search for handmade on Etsy'
        }
    ];
    
    const executor = new TaskExecutor({ headless: true, stealth: true });
    const results = [];
    
    try {
        await executor.init();
        console.log('Browser initialized with FIREBIRD stealth\n');
        
        for (const task of tasks) {
            console.log(`[Task ${task.id}] ${task.description}`);
            console.log(`  URL: ${task.startUrl}`);
            
            const result = await executor.executeTask(task);
            results.push(result);
            
            console.log(`  Steps: ${result.steps.length}`);
            console.log(`  Duration: ${result.getDuration()}ms`);
            console.log(`  Result: ${result.success ? '✅ SUCCESS' : '❌ FAILED'}`);
            if (result.error) {
                console.log(`  Error: ${result.error}`);
            }
            console.log('');
        }
        
    } catch (error) {
        console.error('Executor error:', error.message);
    } finally {
        await executor.close();
    }
    
    // Calculate metrics
    const metrics = calculateMetrics(results);
    
    console.log('┌─────────────────────────────────────────────────────────────────┐');
    console.log('│                 SHOPPING TASK SUMMARY                           │');
    console.log('├─────────────────────────────────────────────────────────────────┤');
    console.log(`│ Total Tasks:       ${metrics.total}                                            │`);
    console.log(`│ Passed:            ${metrics.passed}                                            │`);
    console.log(`│ Failed:            ${metrics.failed}                                            │`);
    console.log(`│ Success Rate:      ${metrics.successRate}%                                        │`);
    console.log(`│ Detection Rate:    ${metrics.detectionRate}%                                         │`);
    console.log(`│ Avg Duration:      ${metrics.avgDuration}ms                                      │`);
    console.log(`│ Avg Steps:         ${metrics.avgSteps}                                          │`);
    console.log('├─────────────────────────────────────────────────────────────────┤');
    
    const status = parseFloat(metrics.successRate) >= 50 ? '✅ SHOPPING TASKS WORKING' : '⚠️  NEEDS IMPROVEMENT';
    console.log(`│ Status:            ${status}                    │`);
    console.log('└─────────────────────────────────────────────────────────────────┘');
    console.log('\nφ² + 1/φ² = 3 = TRINITY\n');
    
    return results;
}

testShoppingTasks().catch(console.error);
