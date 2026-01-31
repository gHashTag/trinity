---
sidebar_position: 2
---

# Installation

## Requirements

- Zig 0.11.0 or later

## Using Zig Package Manager

Add Trinity to your `build.zig.zon`:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .trinity = .{
            .url = "https://github.com/gHashTag/trinity/archive/refs/tags/v0.1.0.tar.gz",
            .hash = "...", // Will be provided after first fetch
        },
    },
}
```

Then in your `build.zig`:

```zig
const trinity = b.dependency("trinity", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("trinity", trinity.module("trinity"));
```

## Manual Installation

Clone the repository:

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
```

Build and test:

```bash
zig build test
```

Run benchmarks:

```bash
zig build bench
```

## Verify Installation

Create a test file `test.zig`:

```zig
const std = @import("std");
const trinity = @import("trinity");

pub fn main() !void {
    var v = trinity.randomVector(256, 12345);
    std.debug.print("Trinity works! Vector length: {}\n", .{v.trit_len});
}
```

Run it:

```bash
zig run test.zig
```
