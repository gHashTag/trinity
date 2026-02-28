#!/usr/bin/env node

/**
 * TRI CLI — Node.js wrapper
 * Forwards commands to native TRI binary
 * φ² + 1/φ² = 3 = TRINITY
 */

const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

// Platform detection
const platform = process.platform;
const arch = process.arch;

// Binary naming conventions
const binaryName = platform === 'win32' ? 'tri.exe' : 'tri';
let binPath;

// Check if we're in development or production
const isDev = __dirname.includes('node_modules');

if (isDev) {
  // Development: use zig-out/bin
  const projectRoot = path.resolve(__dirname, '../../..');
  binPath = path.join(projectRoot, 'zig-out', 'bin', binaryName);
} else {
  // Production: use installed binary
  binPath = path.join(__dirname, 'bin', platform, arch, binaryName);
}

// Fallback to system PATH if bundled binary not found
if (!fs.existsSync(binPath)) {
  binPath = binaryName;
}

// Forward all arguments to native binary
const args = process.argv.slice(2);
const tri = spawn(binPath, args, {
  stdio: 'inherit',
  env: {
    ...process.env,
    TRI_NODE_VERSION: process.version,
    TRI_NPM_WRAPPER: 'true'
  }
});

tri.on('exit', (code) => {
  process.exit(code ?? 0);
});

tri.on('error', (err) => {
  console.error('Failed to launch TRI binary:', err.message);
  console.error('\nPlease ensure Zig 0.15.x is installed:');
  console.error('  brew install zig   # macOS');
  console.error('  pacman -S zig      # Arch Linux');
  console.error('  OR build from source:');
  console.error('  git clone https://github.com/gHashTag/trinity.git');
  console.error('  cd trinity && zig build tri');
  process.exit(1);
});
