//! N-Dimensional Arrays in Zig.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A general-purpose array type with dimension `N`.
///
/// **Example:**
///
/// ```zig
/// // const allocator = ...
///
/// var arr1 = try NDArray(u32, 3).init(.{ 10, 20, 4 }, allocator);
/// var arr2 = try NDArray(f64, 4).initWithValue(.{ 20, 20, 20, 20 }, 1.0, allocator);
///
/// var items = try allocator.alloc(f32, 100);
/// var arr3 = try NDArray(f32, 2).initFromSlice(.{ 20, 5 }, items, allocator);
/// ```
pub fn NDArray(comptime T: type, comptime N: usize) type {
    return struct {
        const Self = @This();

        const Error = error{
            InvalidAxis,
            UnequalAxisSize,
            UnequalBufferSize,
            UnequalShape,
        };

        items: []T,
        shape: [N]usize,
        allocator: Allocator,

        /// Initialize a new, zero-valued NDArray of type `T` with user-defined shape.
        pub fn init(shape: [N]usize, allocator: Allocator) Allocator.Error!Self {
            var size: usize = 1;
            for (shape) |s| {
                size *= s;
            }

            const items = try allocator.alloc(T, size);

            for (items) |*b| {
                b.* = std.mem.zeroes(T);
            }

            return Self{
                .items = items,
                .shape = shape,
                .allocator = allocator,
            };
        }

        /// Initialize a new NDArray of type `T` with a user-specified shape and starting value.
        pub fn initWithValue(shape: [N]usize, val: T, allocator: Allocator) Allocator.Error!Self {
            var size: usize = 1;
            for (shape) |s| {
                size *= s;
            }

            const items = try allocator.alloc(T, size);

            for (items) |*b| {
                b.* = val;
            }

            return Self{
                .items = items,
                .shape = shape,
                .allocator = allocator,
            };
        }

        /// Initialize a new NDArray of type `T` with a user-defined shape and a slice of values.
        /// The length of the slice and the computed size of the NDArray must be compatible.
        /// The values of the slice are `memcopy`'d into the `NDArray`.
        pub fn initFromSlice(shape: [N]usize, items: []const T, allocator: Allocator) Error!Self {
            var size: usize = 1;
            for (shape) |s| {
                size *= s;
            }

            if (size != items.len) {
                return Error.UnequalBufferSize;
            }

            const items_copy = try allocator.alloc(T, size);
            @memcpy(items_copy, items);

            return Self{
                .items = items_copy,
                .shape = shape,
                .allocator = allocator,
            };
        }

        /// Initialize a new NDArray of type `T` with a user-defined shape and a slice of values.
        /// The length of the slice and the computed size of the NDArray must be compatible.
        /// Note that here there is no copying of the slice values, so the lifetime of the slice
        /// may be determined outside of the lifetime of the NDArray. Calling `free` on the slice
        /// will invalidate the NDArray. Likewise, calling `NDArray(T, N).deinit()` will invalidate
        /// the original slice, so it must be ensured that the slice is only freed once.
        pub fn initFromBorrowedSlice(shape: [N]usize, items: []const T, allocator: Allocator) Error!void {
            var size: usize = 1;
            for (shape) |s| {
                size *= s;
            }

            if (size != items.len) {
                return Error.UnequalBufferSize;
            }

            return Self{
                .items = items,
                .shape = shape,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }

        pub fn at(self: *Self, index: [N]usize) T {
            const idx = self.getLinearIndex(index);
            return self.items[idx];
        }

        pub fn setAt(self: *Self, index: [N]usize, val: T) void {
            const idx = self.getLinearIndex(index);
            self.items[idx] = val;
        }

        /// Apply a function element-wise to the current NDArray and another NDArray of the
        /// same type and shape. Returns a newly allocated NDArray with the result of applying
        /// the function.
        pub fn applyFn(
            self: *Self,
            other: NDArray(T, N),
            comptime func: fn (lhs: T, rhs: T) T,
        ) !NDArray(T, N) {
            if (!self.isSameShape(other.shape)) {
                return Error.UnequalShape;
            }
            const new_arr = try Self.init(self.shape, self.allocator);
            for (self.items, other.items, new_arr.items) |s, o, *n| {
                n.* = func(s, o);
            }

            return new_arr;
        }

        /// Apply a function element-wise to the current NDArray and another NDArray of the
        /// same type and shape. Mutates the current NDArray in-place with the result of applying
        /// the function.
        pub fn applyFnMut(
            self: *Self,
            other: NDArray(T, N),
            comptime func: fn (lhs: *T, rhs: T) void,
        ) !void {
            if (!self.isSameShape(other.shape)) {
                return Error.UnequalShape;
            }
            for (self.items, other.items) |*s, o| {
                func(s, o);
            }
        }

        // pub fn applyFnOnAxis(self: *Self, otherAxis: []T, axis: usize, comptime func: fn()){}
        // pub fn applyFnOnAxisMut(){}

        /// Apply a function element-wise to the current NDArray using a scalar of the
        /// same type. Returns a newly allocated NDArray with the result of applying
        /// the function.
        pub fn applyScalarFn(
            self: *Self,
            val: T,
            comptime func: fn (lhs: T, rhs: T) T,
        ) Allocator.Error!NDArray(T, N) {
            const new_arr = try Self.init(self.shape, self.allocator);
            for (self.items, new_arr) |s, *n| {
                n.* = func(s, val);
            }
            return new_arr;
        }

        /// Apply a function element-wise to the current NDArray using a scalar value of the
        /// same type. Mutates the current NDArray in-place with the result of applying
        /// the function.
        pub fn applyScalarFnMut(
            self: *Self,
            val: T,
            comptime func: fn (lhs: *T, rhs: T) void,
        ) void {
            for (self.items) |*s| {
                func(s, val);
            }
        }

        fn getLinearIndex(self: *Self, index: [N]usize) usize {
            var linear_index = index[0];

            comptime var i = 1;
            inline while (i < N) : (i += 1) {
                linear_index = linear_index * self.shape[i] + index[i];
            }

            return linear_index;
        }

        fn isSameShape(self: *Self, other: [N]usize) bool {
            inline for (self.shape, other) |s, o| {
                if (s != o) {
                    return false;
                }
            }
            return true;
        }

        fn isValidAxis(self: *Self, axis: usize) bool {
            if (axis < self.shape.len) {
                return true;
            }
            return false;
        }

        fn isAxisCorrectSize(self: *Self, other: [N]usize, axis: usize) bool {
            if (other[axis] == self.shape[axis]) {
                return true;
            }
            return false;
        }
    };
}

/// Convenience type for a 1-dimensional `NDArray`.
///
/// **Example:**
///
/// ```zig
/// // const allocator = ...
///
/// var arr1 = try Array(f64).initWithValue(.{ 100 }, 4, allocator);
/// var arr2 = try Array(f64).initWithValue(.{ 100 }, 20, allocator);
/// try arr1.applyFnMut(arr2, NumericFns(f64).multiplyMut);
/// ```
pub fn Array(comptime T: type) type {
    return NDArray(T, 1);
}

/// Convenience type for a 2-dimensional `NDArray`.
///
/// **Example:**
///
/// ```zig
/// // const allocator = ...
///
/// var mat1 = try Matrix(f64).initWithValue(.{ 10, 10 }, 4, allocator);
/// var mat2 = try Matrix(f64).initWithValue(.{ 10, 10 }, 20, allocator);
/// try mat1.applyFnMut(mat2, NumericFns(f64).divideMut);
/// ```
pub fn Matrix(comptime T: type) type {
    return NDArray(T, 2);
}

test "NDArray" {
    const ArrayType = NDArray(f64, 3);
    var arr1 = try ArrayType.initWithValue(.{ 10, 10, 10 }, 4, std.testing.allocator);
    defer arr1.deinit();
    var arr2 = try ArrayType.initWithValue(.{ 10, 10, 10 }, 2, std.testing.allocator);
    defer arr2.deinit();
    std.debug.print("\n{any}\n", .{arr1.shape});
    try arr1.applyFnMut(arr2, NumericFns(f64).subtractMut);
    std.debug.print("Value at (1, 2, 3): {}\n", .{arr1.at(.{ 0, 1, 2 })});
}

test "Init NDArray from Slice" {}

test "Init NDArray from Borrowed Slice" {}

/// Arithmetic functions (`+`, `-`, `*`, `/`) for `NDArray`s with numeric types. Can be passed to
/// an `NDArray(T, N).apply*` function with a matching signature.
///
/// **Example:**
///
/// ```zig
/// // const allocator = ...
///
/// var arr = try NDArray(i32, 2).initWithValue(.{ 10, 10 }, 10, allocator);
/// try arr.applyScalarFnMut(2, NumericFns(i32).addMut);
/// std.debug.print("\n{any}\n", .{ arr.items });
/// ```
pub fn NumericFns(comptime T: type) type {
    if (!isNumericType(T)) {
        @compileError("Non-numeric type " ++ @typeName(T) ++ " is not supported.");
    }

    return struct {
        pub fn add(lhs: T, rhs: T) T {
            return lhs + rhs;
        }

        pub fn addMut(lhs: *T, rhs: T) void {
            lhs.* += rhs;
        }

        pub fn subtract(lhs: T, rhs: T) T {
            return lhs - rhs;
        }

        pub fn subtractMut(lhs: *T, rhs: T) void {
            lhs.* -= rhs;
        }

        pub fn multiply(lhs: T, rhs: T) T {
            return lhs * rhs;
        }

        pub fn multiplyMut(lhs: *T, rhs: T) void {
            lhs.* *= rhs;
        }

        pub fn divide(lhs: T, rhs: T) T {
            std.debug.assert(rhs != std.mem.zeroes(T));
            return lhs / rhs;
        }

        pub fn divideMut(lhs: *T, rhs: T) void {
            std.debug.assert(rhs != std.mem.zeroes(T));
            lhs.* /= rhs;
        }
    };
}

/// Comptime check that `T` is a numeric type.
fn isNumericType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Int, .ComptimeInt, .Float, .ComptimeFloat => true,
        else => false,
    };
}

test "Numeric Functions" {
    const int_types = [_]type{ u8, u16, u32, u64, u128, i8, i16, i32, i64, i128 };
    const float_types = [_]type{ f16, f32, f64, f128 };

    inline for (int_types) |I| {
        var val: I = 4;
        try std.testing.expectEqual(NumericFns(I).add(val, 2), 6);
        NumericFns(I).addMut(&val, 2);
        try std.testing.expectEqual(val, 6);

        // val = 6
        try std.testing.expectEqual(NumericFns(I).subtract(val, 3), 3);
        NumericFns(I).subtractMut(&val, 3);
        try std.testing.expectEqual(val, 3);

        // val = 3
        try std.testing.expectEqual(NumericFns(I).multiply(val, 4), 12);
        NumericFns(I).multiplyMut(&val, 4);
        try std.testing.expectEqual(val, 12);

        // val = 12
        try std.testing.expectEqual(NumericFns(I).divide(val, 2), 6);
        NumericFns(I).divideMut(&val, 2);
        try std.testing.expectEqual(val, 6);
    }

    inline for (float_types) |F| {
        var val: F = 4.0;
        try std.testing.expectEqual(NumericFns(F).add(val, 2), 6.0);
        NumericFns(F).addMut(&val, 2.0);
        try std.testing.expectEqual(val, 6.0);

        // val = 6.0
        try std.testing.expectEqual(NumericFns(F).subtract(val, 3.0), 3.0);
        NumericFns(F).subtractMut(&val, 3.0);
        try std.testing.expectEqual(val, 3.0);

        // val = 3.0
        try std.testing.expectEqual(NumericFns(F).multiply(val, 4.0), 12.0);
        NumericFns(F).multiplyMut(&val, 4.0);
        try std.testing.expectEqual(val, 12.0);

        // val = 12.0
        try std.testing.expectEqual(NumericFns(F).divide(val, 2.0), 6.0);
        NumericFns(F).divideMut(&val, 2.0);
        try std.testing.expectEqual(val, 6.0);
    }
}
