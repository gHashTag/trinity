# ⛓️ GOLDEN CHAIN - GITHUB COPILOT INSTRUCTIONS

## ⛔ FORBIDDEN TO CREATE:
- *.html (except runtime/runtime.html)
- *.css
- *.js  
- *.ts
- *.jsx
- *.tsx
- *.zig in var/trinity/output/ (GENERATED ONLY!)
- *.py (GENERATED ONLY!)

## ✅ THE ONLY WAY TO WRITE CODE:

1. Create .vibee specification in specs/tri/
2. Run: ./bin/vibee gen specs/tri/feature.vibee
3. Test: zig test var/trinity/output/feature.zig
4. Write TOXIC VERDICT (self-criticism)
5. Propose 3 options from TECH TREE

## 📝 .vibee FORMAT:

```yaml
name: module_name
version: "1.0.0"
language: zig
module: module_name

types:
  TypeName:
    fields:
      field1: String
      field2: Int

behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Result
```

## 🔥 AFTER EVERY TASK:

### TOXIC VERDICT (mandatory!):
- What was done
- What failed  
- Metrics (before/after)
- Harsh self-criticism
- Score X/10

### TECH TREE SELECT (mandatory!):
Propose 3 options for next research:
- [A] Name, complexity ★☆☆☆☆, potential +X%
- [B] Name, complexity ★★☆☆☆, potential +X%
- [C] Name, complexity ★★★☆☆, potential +X%
- Recommendation: [A/B/C] because...

## 🚫 NEVER DO:
- Don't write .zig code directly
- Don't edit var/trinity/output/*
- Don't create legacy files
- Don't skip toxic verdict
- Don't skip tech tree select

## φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
