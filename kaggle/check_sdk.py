#!/usr/bin/env python3
"""Check Kaggle Benchmarks SDK structure."""

import kaggle_benchmarks as kb
print("Kaggle Benchmarks version:", kb.__version__)
print("Module contents:", [x for x in dir(kb) if not x.startswith('_')])

# Check what's in the module
if hasattr(kb, 'task'):
    print("✅ Has 'task' decorator")
if hasattr(kb, 'llm'):
    print("✅ Has 'llm' module")
if hasattr(kb, 'assertions'):
    print("✅ Has 'assertions' module")
