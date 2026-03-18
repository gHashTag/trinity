# W1 Worker Task: NEXUS Source Migration

## Branch: ralph/nexus-src

## Tasks
- NEXUS-011: Migrate remaining core/ files
- NEXUS-012: Migrate remaining lang/ files  
- NEXUS-013: Migrate remaining symb/ files
- NEXUS-014: Verify all tests pass

## Instructions
1. Checkout or create branch: ralph/nexus-src
2. Review files in /Users/playra/trinity/src/ that need migration
3. Move appropriate files to trinity-nexus module structure
4. Update imports
5. Run: zig build test
6. Commit with: "NEXUS-0XX: Migrate [component]"
7. Push: git push -u origin ralph/nexus-src
8. Create .ralph/DONE_W1 when complete

## Done When
All tasks complete, tests passing, commits pushed.
