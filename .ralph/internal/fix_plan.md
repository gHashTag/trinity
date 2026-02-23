# W1 — Phase 1: NEXUS Source Migration

## Overview
Migrate remaining source files to trinity-nexus module structure.

## Tasks
- NEXUS-011: Migrate remaining core/ files
- NEXUS-012: Migrate remaining lang/ files  
- NEXUS-013: Migrate remaining symb/ files
- NEXUS-014: Verify all tests pass

## Branch
Work on branch: `ralph/nexus-src`

## Instructions
1. Create branch: git checkout -b ralph/nexus-src
2. Review files that need migration
3. Move appropriate files to trinity-nexus module structure
4. Update imports in moved files
5. Run tests: zig build test
6. Commit with message: "NEXUS-0XX: Migrate [component]"
7. Push: git push -u origin ralph/nexus-src

## Done When
All tasks complete, tests passing, commits pushed.
Create .ralph/internal/DONE file when finished.
