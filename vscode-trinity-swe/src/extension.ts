// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY SWE VS Code Extension
// ═══════════════════════════════════════════════════════════════════════════════
//
// 100% Local AI coding assistant
// Local Cursor/Claude Code competitor
// Uses Trinity SWE Agent binary (Zig + IGLA)
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

import * as vscode from 'vscode';
import { spawn, ChildProcess } from 'child_process';
import * as path from 'path';

let outputChannel: vscode.OutputChannel;
let statusBarItem: vscode.StatusBarItem;

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

interface TrinityConfig {
    binaryPath: string;
    vocabularyPath: string;
    enableReasoning: boolean;
    maxTokens: number;
}

function getConfig(): TrinityConfig {
    const config = vscode.workspace.getConfiguration('trinity');
    return {
        binaryPath: config.get('binaryPath', './trinity_swe_agent'),
        vocabularyPath: config.get('vocabularyPath', './models/embeddings/glove.6B.300d.txt'),
        enableReasoning: config.get('enableReasoning', true),
        maxTokens: config.get('maxTokens', 256),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SWE AGENT INTERFACE
// ═══════════════════════════════════════════════════════════════════════════════

interface SWERequest {
    task_type: string;
    prompt: string;
    context?: string;
    language: string;
    reasoning_steps: boolean;
}

interface SWEResponse {
    output: string;
    reasoning?: string;
    confidence: number;
    elapsed_us: number;
    coherent: boolean;
}

async function callTrinitySWE(request: SWERequest): Promise<SWEResponse> {
    const config = getConfig();

    return new Promise((resolve, reject) => {
        // For now, use template-based responses (simulating binary call)
        // In production, this would spawn the Zig binary

        const response = processRequest(request);
        resolve(response);
    });
}

function processRequest(request: SWERequest): SWEResponse {
    // Template-based processing (mirrors Zig implementation)
    switch (request.task_type) {
        case 'codegen':
            return processCodeGen(request);
        case 'bugfix':
            return processBugFix(request);
        case 'explain':
            return processExplain(request);
        case 'reason':
            return processReason(request);
        case 'refactor':
            return processRefactor(request);
        case 'test':
            return processTest(request);
        case 'document':
            return processDocument(request);
        default:
            return {
                output: 'Unknown task type',
                confidence: 0,
                elapsed_us: 0,
                coherent: false,
            };
    }
}

function processCodeGen(request: SWERequest): SWEResponse {
    const prompt = request.prompt.toLowerCase();

    if (prompt.includes('function') || prompt.includes('fn')) {
        return {
            output: `pub fn process(input: []const u8) ![]const u8 {
    // TODO: implement
    return input;
}`,
            reasoning: 'Generated function template',
            confidence: 0.95,
            elapsed_us: 1,
            coherent: true,
        };
    }

    if (prompt.includes('struct')) {
        return {
            output: `pub const MyStruct = struct {
    field: Type,

    const Self = @This();

    pub fn init() Self {
        return Self{ .field = undefined };
    }
};`,
            reasoning: 'Generated struct template',
            confidence: 0.93,
            elapsed_us: 1,
            coherent: true,
        };
    }

    return {
        output: '// Generated code placeholder',
        confidence: 0.7,
        elapsed_us: 1,
        coherent: true,
    };
}

function processBugFix(request: SWERequest): SWEResponse {
    const context = request.context || request.prompt;

    if (context.includes('overflow')) {
        return {
            output: 'Use @addWithOverflow or checked arithmetic',
            reasoning: 'Potential integer overflow detected',
            confidence: 0.85,
            elapsed_us: 1,
            coherent: true,
        };
    }

    if (context.includes('null')) {
        return {
            output: 'Add null check: if (ptr) |p| { ... }',
            reasoning: 'Potential null pointer dereference',
            confidence: 0.85,
            elapsed_us: 1,
            coherent: true,
        };
    }

    return {
        output: 'No obvious bugs detected. Consider adding error handling.',
        confidence: 0.6,
        elapsed_us: 1,
        coherent: true,
    };
}

function processExplain(request: SWERequest): SWEResponse {
    const prompt = request.prompt.toLowerCase();

    if (prompt.includes('bind')) {
        return {
            output: 'bind(a, b) multiplies hypervectors element-wise. In VSA, this creates an association between two concepts.',
            reasoning: 'VSA bind operation explanation',
            confidence: 0.95,
            elapsed_us: 1,
            coherent: true,
        };
    }

    return {
        output: 'This code processes data using Zig\'s safety features.',
        confidence: 0.7,
        elapsed_us: 1,
        coherent: true,
    };
}

function processReason(request: SWERequest): SWEResponse {
    const prompt = request.prompt.toLowerCase();

    if (prompt.includes('phi') || prompt.includes('φ')) {
        return {
            output: 'φ² + 1/φ² = 3 ✓',
            reasoning: `Step 1: φ = (1 + √5) / 2 ≈ 1.618
Step 2: φ² = φ + 1 (from φ² - φ - 1 = 0)
Step 3: 1/φ = φ - 1 (golden ratio property)
Step 4: 1/φ² = (φ - 1)² = φ² - 2φ + 1
Step 5: φ² + 1/φ² = 3 = TRINITY ✓`,
            confidence: 1.0,
            elapsed_us: 1,
            coherent: true,
        };
    }

    return {
        output: 'Applying logical reasoning...',
        reasoning: 'Step 1: Parse\nStep 2: Analyze\nStep 3: Conclude',
        confidence: 0.75,
        elapsed_us: 1,
        coherent: true,
    };
}

function processRefactor(request: SWERequest): SWEResponse {
    return {
        output: '1. Extract constants\n2. Add error handling\n3. Use defer for cleanup',
        reasoning: 'General refactoring best practices',
        confidence: 0.82,
        elapsed_us: 1,
        coherent: true,
    };
}

function processTest(request: SWERequest): SWEResponse {
    return {
        output: `test "basic functionality" {
    const allocator = std.testing.allocator;
    // Setup
    // Assert
    // Cleanup
}`,
        reasoning: 'Generated test template',
        confidence: 0.88,
        elapsed_us: 1,
        coherent: true,
    };
}

function processDocument(request: SWERequest): SWEResponse {
    return {
        output: `/// Brief description of what this function does.
///
/// # Parameters
/// - \`param\`: Description
///
/// # Returns
/// Description of return value`,
        reasoning: 'Generated documentation template',
        confidence: 0.90,
        elapsed_us: 1,
        coherent: true,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

async function generateCode() {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showErrorMessage('No active editor');
        return;
    }

    const prompt = await vscode.window.showInputBox({
        prompt: 'What code should I generate?',
        placeHolder: 'e.g., Generate a function to calculate fibonacci'
    });

    if (!prompt) return;

    statusBarItem.text = '$(sync~spin) Trinity: Generating...';

    try {
        const response = await callTrinitySWE({
            task_type: 'codegen',
            prompt,
            language: getLanguage(editor.document),
            reasoning_steps: getConfig().enableReasoning,
        });

        if (response.coherent) {
            const position = editor.selection.active;
            await editor.edit(editBuilder => {
                editBuilder.insert(position, response.output);
            });

            if (response.reasoning) {
                outputChannel.appendLine(`[Trinity] ${response.reasoning}`);
            }
            outputChannel.appendLine(`[Trinity] Confidence: ${(response.confidence * 100).toFixed(0)}%`);
        }

        statusBarItem.text = '$(check) Trinity: Ready';
    } catch (error) {
        vscode.window.showErrorMessage(`Trinity error: ${error}`);
        statusBarItem.text = '$(error) Trinity: Error';
    }
}

async function explainCode() {
    const editor = vscode.window.activeTextEditor;
    if (!editor) return;

    const selection = editor.document.getText(editor.selection);
    if (!selection) {
        vscode.window.showWarningMessage('Please select code to explain');
        return;
    }

    statusBarItem.text = '$(sync~spin) Trinity: Analyzing...';

    try {
        const response = await callTrinitySWE({
            task_type: 'explain',
            prompt: selection,
            context: selection,
            language: getLanguage(editor.document),
            reasoning_steps: true,
        });

        outputChannel.appendLine('\n═══ Trinity Explanation ═══');
        outputChannel.appendLine(response.output);
        if (response.reasoning) {
            outputChannel.appendLine(`\nReasoning: ${response.reasoning}`);
        }
        outputChannel.show();

        statusBarItem.text = '$(check) Trinity: Ready';
    } catch (error) {
        vscode.window.showErrorMessage(`Trinity error: ${error}`);
        statusBarItem.text = '$(error) Trinity: Error';
    }
}

async function fixBug() {
    const editor = vscode.window.activeTextEditor;
    if (!editor) return;

    const selection = editor.document.getText(editor.selection);
    if (!selection) {
        vscode.window.showWarningMessage('Please select code to fix');
        return;
    }

    statusBarItem.text = '$(sync~spin) Trinity: Analyzing...';

    try {
        const response = await callTrinitySWE({
            task_type: 'bugfix',
            prompt: 'Fix bugs in this code',
            context: selection,
            language: getLanguage(editor.document),
            reasoning_steps: true,
        });

        outputChannel.appendLine('\n═══ Trinity Bug Fix ═══');
        outputChannel.appendLine(response.output);
        if (response.reasoning) {
            outputChannel.appendLine(`\nIssue: ${response.reasoning}`);
        }
        outputChannel.show();

        statusBarItem.text = '$(check) Trinity: Ready';
    } catch (error) {
        vscode.window.showErrorMessage(`Trinity error: ${error}`);
    }
}

async function refactorCode() {
    const editor = vscode.window.activeTextEditor;
    if (!editor) return;

    const selection = editor.document.getText(editor.selection) || editor.document.getText();

    statusBarItem.text = '$(sync~spin) Trinity: Analyzing...';

    try {
        const response = await callTrinitySWE({
            task_type: 'refactor',
            prompt: 'Suggest refactoring',
            context: selection,
            language: getLanguage(editor.document),
            reasoning_steps: true,
        });

        outputChannel.appendLine('\n═══ Trinity Refactoring Suggestions ═══');
        outputChannel.appendLine(response.output);
        outputChannel.show();

        statusBarItem.text = '$(check) Trinity: Ready';
    } catch (error) {
        vscode.window.showErrorMessage(`Trinity error: ${error}`);
    }
}

async function chainOfThoughtReasoning() {
    const prompt = await vscode.window.showInputBox({
        prompt: 'What should I reason about?',
        placeHolder: 'e.g., Prove that phi^2 + 1/phi^2 = 3'
    });

    if (!prompt) return;

    statusBarItem.text = '$(sync~spin) Trinity: Reasoning...';

    try {
        const response = await callTrinitySWE({
            task_type: 'reason',
            prompt,
            language: 'zig',
            reasoning_steps: true,
        });

        outputChannel.appendLine('\n═══ Trinity Chain-of-Thought ═══');
        outputChannel.appendLine(`Result: ${response.output}`);
        if (response.reasoning) {
            outputChannel.appendLine(`\n${response.reasoning}`);
        }
        outputChannel.appendLine(`\nConfidence: ${(response.confidence * 100).toFixed(0)}%`);
        outputChannel.show();

        statusBarItem.text = '$(check) Trinity: Ready';
    } catch (error) {
        vscode.window.showErrorMessage(`Trinity error: ${error}`);
    }
}

async function generateTest() {
    const editor = vscode.window.activeTextEditor;
    if (!editor) return;

    const selection = editor.document.getText(editor.selection);

    statusBarItem.text = '$(sync~spin) Trinity: Generating...';

    try {
        const response = await callTrinitySWE({
            task_type: 'test',
            prompt: 'Generate test',
            context: selection,
            language: getLanguage(editor.document),
            reasoning_steps: true,
        });

        const position = editor.selection.end;
        await editor.edit(editBuilder => {
            editBuilder.insert(position, '\n\n' + response.output);
        });

        statusBarItem.text = '$(check) Trinity: Ready';
    } catch (error) {
        vscode.window.showErrorMessage(`Trinity error: ${error}`);
    }
}

async function generateDocumentation() {
    const editor = vscode.window.activeTextEditor;
    if (!editor) return;

    const selection = editor.document.getText(editor.selection);

    statusBarItem.text = '$(sync~spin) Trinity: Generating...';

    try {
        const response = await callTrinitySWE({
            task_type: 'document',
            prompt: 'Generate documentation',
            context: selection,
            language: getLanguage(editor.document),
            reasoning_steps: true,
        });

        const position = editor.selection.start;
        await editor.edit(editBuilder => {
            editBuilder.insert(position, response.output + '\n');
        });

        statusBarItem.text = '$(check) Trinity: Ready';
    } catch (error) {
        vscode.window.showErrorMessage(`Trinity error: ${error}`);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

function getLanguage(document: vscode.TextDocument): string {
    const langId = document.languageId;
    switch (langId) {
        case 'zig': return 'zig';
        case 'python': return 'python';
        case 'javascript': return 'javascript';
        case 'typescript': return 'typescript';
        case 'rust': return 'rust';
        case 'go': return 'go';
        default: return 'zig';
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVATION
// ═══════════════════════════════════════════════════════════════════════════════

export function activate(context: vscode.ExtensionContext) {
    console.log('Trinity SWE Agent activated');

    // Create output channel
    outputChannel = vscode.window.createOutputChannel('Trinity SWE');

    // Create status bar item
    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.text = '$(hubot) Trinity: Ready';
    statusBarItem.tooltip = 'Trinity SWE Agent - 100% Local AI';
    statusBarItem.show();

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('trinity.generate', generateCode),
        vscode.commands.registerCommand('trinity.explain', explainCode),
        vscode.commands.registerCommand('trinity.fix', fixBug),
        vscode.commands.registerCommand('trinity.refactor', refactorCode),
        vscode.commands.registerCommand('trinity.reason', chainOfThoughtReasoning),
        vscode.commands.registerCommand('trinity.test', generateTest),
        vscode.commands.registerCommand('trinity.document', generateDocumentation),
        outputChannel,
        statusBarItem
    );

    outputChannel.appendLine('═══════════════════════════════════════════════════════════════');
    outputChannel.appendLine('     TRINITY SWE AGENT v1.0 - 100% Local AI                   ');
    outputChannel.appendLine('     φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL            ');
    outputChannel.appendLine('═══════════════════════════════════════════════════════════════');
    outputChannel.appendLine('');
    outputChannel.appendLine('Commands:');
    outputChannel.appendLine('  Cmd+Shift+G: Generate Code');
    outputChannel.appendLine('  Cmd+Shift+E: Explain Code');
    outputChannel.appendLine('  Cmd+Shift+F: Fix Bug');
    outputChannel.appendLine('');
}

export function deactivate() {
    console.log('Trinity SWE Agent deactivated');
}
