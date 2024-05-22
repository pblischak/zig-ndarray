# N-Dimensional Arrays in Zig



## Installation

```zon
.{
    .name = "my_project",
    .version = "0.1.0",
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "README.md",
        "LICENSE",
        "src",
    },
    .dependencies = .{
        // This will link to tagged v0.1.0 release.
        // Change the url and hash to link to a specific commit.
        .ndarray = {
            .url = "",
            .hash = "",
        }
    },
}
```

Then, in the `build.zig` file, add the following lines within the `build` function to include
`ndarray` as a module:

```zig
pub fn build(b: *std.Build) void {
    // exe setup...

    const ndarray_dep = b.dependency("ndarray", .{
            .target = target,
            .optimize = optimize,
    });

    const ndarray_module = ndarray_dep.module("ndarray");
    exe.root_module.addImport("ndarray", ndarray_module);

    // additional build steps...
}
```

Check out the build files in the [examples/](https://github.com/pblischak/ndarray/tree/main/examples)
folder for some demos of complete sample code projects.

## Getting Started

```zig
const std = @import("std");
const NDArray = @import("ndarray").NDArray;
const Allocator = std.mem.allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        std.testing.expect(status == .ok) catch {
            @panic("Memory leak!");
        };
    }

    const arr = try NDArray(f32, 3).init(.{10, 10, 2}, allocator);
    defer arr.deinit();
}
```

### Acknowledgements

The `ndarray` module modifies the code from [this gist](https://gist.github.com/AssortedFantasy/f57ebe9c2b5c71081db345a7372d6a38)
by AssortedFantasy by adding within-struct allocation and by making things more compatible with the
Zig package management system. Many thanks to AssortedFantasy for the initial implementation of a
multidimensional array structure in Zig.
