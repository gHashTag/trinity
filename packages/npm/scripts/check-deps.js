#!/usr/bin/env node

/**
 * TRI CLI — Pre-install dependency check
 * Ensures Zig is available or user is on supported platform
 * φ² + 1/φ² = 3 = TRINITY
 */

const { execSync } = require('child_process');
const os = require('os');

console.log('TRI CLI v' + require('../package.json').version);
console.log('Platform:', os.platform(), os.arch());

// Check if Zig is needed (will download prebuilt if available)
const platform = process.platform;
const arch = process.arch;

const hasPrebuilt = ['darwin', 'linux'].includes(platform) &&
                    ['x64', 'arm64'].includes(arch);

if (hasPrebuilt) {
  console.log('✅ Prebuilt binary available - installation will download it');
} else {
  console.log('⚠️  No prebuilt binary - building from source');

  try {
    const version = execSync('zig version', { encoding: 'utf-8' }).trim();
    console.log('✅ Zig found:', version);

    if (!version.startsWith('0.15')) {
      console.warn('⚠️  Warning: Zig 0.15.x is recommended, you have:', version);
    }
  } catch {
    console.error('❌ Error: Zig not found');
    console.error('Please install Zig 0.15.x from https://ziglang.org/download/');
    process.exit(1);
  }
}

console.log('Installation checks passed ✓');
