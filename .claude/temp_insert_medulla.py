#!/usr/bin/env python3
import re

with open('/Users/playra/trinity-w1/src/tri/queen_dlpfc.zig', 'r') as f:
    content = f.read()

# Find the position where we need to insert (after defer candidates.deinit();)
    pattern = r'    defer candidates\.deinit\(\);'
    match = re.search(pattern, content)

    if match:
        # Insert Medulla integration section
        insert_pos = match.start()

        new_section = '''\
    // ═════════════════════════════════════════════\
    // MEDULLA INTEGRATION — Heartbeat at cycle start\
    _ = medulla.heartbeatPing(ctx.allocator) catch |err| {\
        std.debug.print("Medulla heartbeat failed: {}\\n", .{@errorName(err)});\
    };\
\
    // ═════════════════════════════════\
    // RULE 0: NIGHT GUARD — Block destructive actions during protected hours\
'''

        # Write back
        with open('/Users/playra/trinity-w1/src/tri/queen_dlpfc.zig', 'w') as f:
            f.write(content[:insert_pos] + new_section + content[insert_pos:])
        print(f"Inserted Medulla section at line {insert_pos}")
    else:
        print("Pattern not found")
EOF
