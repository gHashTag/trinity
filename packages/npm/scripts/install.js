#!/usr/bin/env node

/**
 * TRI CLI — Post-install script
 * Downloads prebuilt binary or builds from source
 * φ² + 1/φ² = 3 = TRINITY
 */

const https = require('https');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const os = require('os');

const version = require('../package.json').version;
const platform = process.platform;
const arch = process.arch;

// Platform-specific binary names
const platformMap = {
  darwin: 'macos',
  linux: 'linux',
  win32: 'windows'
};

const archMap = {
  x64: 'x86_64',
  arm64: 'aarch64'
};

const binaryPlatform = platformMap[platform];
const binaryArch = archMap[arch];

if (!binaryPlatform || !binaryArch) {
  console.warn(`⚠️  No prebuilt binary available for ${platform}-${arch}`);
  console.log('Building from source...');
  buildFromSource();
  process.exit(0);
}

// Download prebuilt binary
const binaryUrl = `https://github.com/gHashTag/trinity/releases/download/v${version}/tri-${binaryArch}-${binaryPlatform}.tar.gz`;
const binDir = path.join(__dirname, '../bin', platform, arch);
const binaryPath = path.join(binDir, platform === 'win32' ? 'tri.exe' : 'tri');

console.log(`Downloading TRI v${version} for ${binaryPlatform}-${binaryArch}...`);

fs.mkdirSync(binDir, { recursive: true });

const file = fs.createWriteStream(`${binaryPath}.tar.gz`);

https.get(binaryUrl, (response) => {
  if (response.statusCode === 404) {
    console.warn('⚠️  Prebuilt binary not found');
    console.log('Building from source...');
    file.close();
    fs.unlinkSync(`${binaryPath}.tar.gz`);
    buildFromSource();
    return;
  }

  if (response.statusCode !== 200) {
    console.error(`❌ Failed to download: ${response.statusCode}`);
    process.exit(1);
  }

  response.pipe(file);

  file.on('finish', () => {
    file.close();
    console.log('Extracting...');

    // Extract tar.gz
    try {
      if (platform === 'win32') {
        execSync(`cd "${binDir}" && tar -xzf "${binaryPath}.tar.gz"`);
      } else {
        execSync(`tar -xzf "${binaryPath}.tar.gz" -C "${binDir}"`);
      }

      // Clean up
      fs.unlinkSync(`${binaryPath}.tar.gz`);

      // Make executable
      if (platform !== 'win32') {
        fs.chmodSync(binaryPath, '755');
      }

      console.log('✅ TRI CLI installed successfully');
      console.log(`Run: tri --help`);
    } catch (err) {
      console.error('❌ Extraction failed:', err.message);
      buildFromSource();
    }
  });
}).on('error', (err) => {
  fs.unlinkSync(`${binaryPath}.tar.gz`);
  console.error('❌ Download failed:', err.message);
  buildFromSource();
});

function buildFromSource() {
  console.log('Building TRI CLI from source...');

  try {
    // Check if Zig is installed
    execSync('zig version', { stdio: 'ignore' });
  } catch {
    console.error('❌ Zig 0.15.x is required to build from source');
    console.error('Install from: https://ziglang.org/download/');
    process.exit(1);
  }

  try {
    // Clone and build
    const tmpDir = path.join(os.tmpdir(), 'trinity-build');
    if (fs.existsSync(tmpDir)) {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }

    console.log('Cloning repository...');
    execSync(`git clone --depth 1 --branch v${version} https://github.com/gHashTag/trinity.git "${tmpDir}"`);

    console.log('Building...');
    execSync('zig build tri', { cwd: tmpDir, stdio: 'inherit' });

    // Install binary
    fs.mkdirSync(binDir, { recursive: true });
    fs.copyFileSync(path.join(tmpDir, 'zig-out', 'bin', 'tri'), binaryPath);

    if (platform !== 'win32') {
      fs.chmodSync(binaryPath, '755');
    }

    // Cleanup
    fs.rmSync(tmpDir, { recursive: true, force: true });

    console.log('✅ TRI CLI built and installed successfully');
    console.log(`Run: tri --help`);
  } catch (err) {
    console.error('❌ Build failed:', err.message);
    process.exit(1);
  }
}
