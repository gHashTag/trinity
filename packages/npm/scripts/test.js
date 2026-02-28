#!/usr/bin/env node

/**
 * TRI CLI — Test script
 * Validates installation
 * φ² + 1/phi² = 3 = TRINITY
 */

const { execSync } = require('child_process');

console.log('Testing TRI CLI installation...');

try {
  // Test version command
  const version = execSync('tri version', { encoding: 'utf-8' });
  console.log('Version:', version.trim());

  // Test sacred constants
  const constants = execSync('tri constants', { encoding: 'utf-8' });
  if (!constants.includes('φ')) {
    throw new Error('Constants command failed');
  }
  console.log('✅ Constants check passed');

  // Test help
  const help = execSync('tri help', { encoding: 'utf-8' });
  console.log('✅ Help command works');

  console.log('\n✅ All tests passed!');
} catch (err) {
  console.error('❌ Test failed:', err.message);
  process.exit(1);
}
