## Data Collection (shared module)

### Usage in SKILL.md
Reference this module for common system state queries:
> For system state collection, follow `.claude/skills/_shared/data_collection.md`.

### Build Health
```bash
# Build check (exit code + errors)
cd /Users/playra/trinity-w1 && zig build --summary none 2>&1

# Test suite
cd /Users/playra/trinity-w1 && zig build test 2>&1
```

### Git State
```bash
# Working tree status
git -C /Users/playra/trinity-w1 status --porcelain

# Recent commits
git -C /Users/playra/trinity-w1 log --oneline -5

# Current branch
git -C /Users/playra/trinity-w1 branch --show-current

# Dirty file count
git -C /Users/playra/trinity-w1 status --porcelain | wc -l
```

### Agent Processes
```bash
# Check all Trinity processes
pgrep -la ralph-agent 2>/dev/null || echo "ralph-agent: DOWN"
pgrep -la tri-bot 2>/dev/null || echo "tri-bot: DOWN"
pgrep -la trinity-mcp 2>/dev/null || echo "trinity-mcp: DOWN"
```

### Binary Check
```bash
# Verify all 6 binaries exist
for bin in trinity-mcp ralph-agent ralph-hook tri-bot tri-api hslm-entrypoint; do
  if [ -f /Users/playra/trinity-w1/zig-out/bin/$bin ]; then
    echo "✅ $bin"
  else
    echo "❌ $bin MISSING"
  fi
done
```

### Evolution State
```bash
# Read evolution leaderboard
cat /Users/playra/trinity-w1/.trinity/evolution_state.json 2>/dev/null | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin)
  gen=d.get('generation',0)
  pop=d.get('population',[])
  print(f'Generation: {gen}, Population: {len(pop)}')
  for p in sorted(pop, key=lambda x: x.get('fitness',0), reverse=True)[:5]:
    print(f'  {p.get(\"name\",\"?\")}: fitness={p.get(\"fitness\",0):.3f}')
except: print('No evolution data')
" 2>/dev/null || echo "No evolution state"
```

### Railway Farm Status
```bash
# Query Railway API for service status
source /Users/playra/trinity-w1/.env 2>/dev/null
curl -s -X POST "https://backboard.railway.com/graphql/v2" \
  -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"query($id:String!){project(id:$id){services{edges{node{id name deployments(first:1){edges{node{status}}}}}}}}","variables":{"id":"aa0efa7f-95e6-4466-8de6-43945a031365"}}' 2>/dev/null
```

### Skill Count
```bash
# Count available skills
ls -d /Users/playra/trinity-w1/.claude/skills/*/SKILL.md 2>/dev/null | wc -l
```
