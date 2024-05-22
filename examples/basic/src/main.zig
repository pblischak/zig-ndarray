const std = @import("std");
const Allocator = std.mem.Allocator;
const NDArray = @import("ndarray").NDArray;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        std.testing.expect(status == .ok) catch {
            @panic("Memory leak!");
        };
    }

    var int_arr = try NDArray(i32, 4).init(.{ 10, 10, 4, 2 }, allocator);
    int_arr.setAt(.{ 8, 4, 2, 0 }, -2048);
    defer int_arr.deinit();
    std.debug.print("integer array: {}\n", .{int_arr.at(.{ 8, 4, 2, 0 })});
    var uint_arr = try NDArray(u32, 2).init(.{ 20, 40 }, allocator);
    defer uint_arr.deinit();
    uint_arr.setAt(.{ 15, 25 }, 1024);
    std.debug.print("unsigned integer array: {}\n", .{uint_arr.at(.{ 15, 25 })});
}
