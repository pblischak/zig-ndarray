const std = @import("std");
const NDArray = @import("ndarray").NDArray;

const Point = struct {
    x: f64,
    y: f64,
    z: f64,

    fn add(lhs: Point, rhs: Point) Point {
        return Point{
            .x = lhs.x + rhs.x,
            .y = lhs.y + rhs.y,
            .z = lhs.z + rhs.z,
        };
    }

    fn addMut(lhs: *Point, rhs: Point) void {
        lhs.*.x += rhs.x;
        lhs.*.y += rhs.y;
        lhs.*.z += rhs.z;
    }
};

pub fn main() !void {}

test "NDArray of Points" {
    const allocator = std.testing.allocator;
    var arr1 = try NDArray(Point, 2).initWithValue(
        .{ 10, 10 },
        Point{ .x = 1.0, .y = 2.0, .z = 3.0 },
        allocator,
    );
    defer arr1.deinit();
    var arr2 = try NDArray(Point, 2).initWithValue(
        .{ 10, 10 },
        Point{ .x = 10.0, .y = 20.0, .z = 30.0 },
        allocator,
    );
    defer arr2.deinit();

    var arr3 = try arr1.applyFn(arr2, Point.add);
    defer arr3.deinit();

    std.debug.print("{}\n", .{arr3.at(.{ 5, 5 })});

    try arr1.applyFnMut(arr3, Point.addMut);

    std.debug.print("{}\n", .{arr1.at(.{ 5, 5 })});
}
