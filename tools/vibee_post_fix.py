#!/usr/bin/env python3
"""
VIBEE Post-Generation Type Fix
Automatically corrects VIBEE-generated Zig code type mappings.
"""

import re
import sys
import os
import shutil
from pathlib import Path

# Fix rules (pattern, replacement, description)
FIX_RULES = [
    (r'\bUInt\b', 'usize', 'UInt → usize'),
    (r'\bInt8\b', 'i8', 'Int8 → i8'),
    (r'\bInt16\b', 'i16', 'Int16 → i16'),
    (r'\bInt32\b', 'i32', 'Int32 → i32'),
    (r'\bInt64\b', 'i64', 'Int64 → i64'),
    (r'\bUInt8\b', 'u8', 'UInt8 → u8'),
    (r'\bUInt16\b', 'u16', 'UInt16 → u16'),
    (r'\bUInt32\b', 'u32', 'UInt32 → u32'),
    (r'\bUInt64\b', 'u64', 'UInt64 → u64'),
    (r'\bBool\b', 'bool', 'Bool → bool'),
    (r'\bString\b', '[]const u8', 'String → []const u8'),
    (r'Array\[([^\]]+)\]\[(\d+)\]', r'[\2]\1', 'Array[T][N] → [N]T'),
    (r'Option<([^>]+)>', r'?\1', 'Option<T> → ?T'),
    (r'List<([^>]+)>', r'[]const \1', 'List<T> → []const T'),
    (r'const (CMD_\w+): f64 = (\d+)', r'const \1: u8 = \2', 'CMD: f64 → u8'),
]

def fix_file(filepath: str, backup: bool = True) -> dict:
    """Apply fix rules to a single file."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    fixes_applied = 0
    fixes_detail = []

    for pattern, replacement, desc in FIX_RULES:
        matches = len(re.findall(pattern, content))
        if matches > 0:
            content = re.sub(pattern, replacement, content)
            fixes_applied += matches
            fixes_detail.append(f"  {desc}: {matches} occurrences")

    if content == original:
        return {'file': filepath, 'fixes_applied': 0, 'lines_changed': 0}

    # Create backup
    if backup:
        backup_path = filepath + '.backup'
        shutil.copy2(filepath, backup_path)

    # Write fixed content
    with open(filepath, 'w') as f:
        f.write(content)

    return {
        'file': filepath,
        'fixes_applied': fixes_applied,
        'lines_changed': content.count('\n'),
        'details': fixes_detail,
        'backup': backup_path if backup else None
    }

def fix_directory(directory: str, pattern: str = '*.zig') -> list:
    """Apply fixes to all matching files in directory."""
    results = []
    path = Path(directory)
    
    for filepath in path.glob(pattern):
        result = fix_file(str(filepath))
        if result['fixes_applied'] > 0:
            results.append(result)
            print(f"Fixed: {filepath}")
            for detail in result.get('details', []):
                print(detail)
    
    return results

def main():
    if len(sys.argv) < 2:
        print("Usage: vibee_post_fix.py <file_or_directory> [pattern]")
        print("Examples:")
        print("  vibee_post_fix.py trinity-nexus/output/lang/zig/file.zig")
        print("  vibee_post_fix.py trinity-nexus/output/lang/zig/")
        sys.exit(1)

    target = sys.argv[1]
    pattern = sys.argv[2] if len(sys.argv) > 2 else '*.zig'

    if os.path.isfile(target):
        result = fix_file(target)
        print(f"\nFixed: {result['file']}")
        print(f"Fixes applied: {result['fixes_applied']}")
        if result.get('details'):
            for detail in result['details']:
                print(detail)
    elif os.path.isdir(target):
        results = fix_directory(target, pattern)
        print(f"\n{'='*50}")
        print(f"Total files fixed: {len(results)}")
        print(f"Total fixes: {sum(r['fixes_applied'] for r in results)}")
    else:
        print(f"Error: {target} is not a valid file or directory")
        sys.exit(1)

if __name__ == '__main__':
    main()
