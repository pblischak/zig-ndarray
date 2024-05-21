const std = @import("std");

pub fn build(b: *std.Build) void {
    const root_source_file = b.path("src/ndarray.zig");

    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    var module = b.addModule(
        "ndarray",
        .{ .root_source_file = root_source_file },
    );

    const zprob_dep = b.dependency("zprob", .{
        .target = target,
        .optimize = optimize,
    });

    module.addImport("zprob", zprob_dep.module("zprob"));

    const main_tests = b.addTest(.{
        .root_source_file = root_source_file,
        .optimize = optimize,
        .target = target,
    });
    main_tests.root_module.addImport("zprob", zprob_dep.module("zprob"));
    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_main_tests.step);

    const ndarray_lib = b.addStaticLibrary(.{
        .name = "ndarray",
        .root_source_file = root_source_file,
        .target = target,
        .optimize = optimize,
    });
    const docs_step = b.step("docs", "Emit docs");
    const docs_install = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = ndarray_lib.getEmittedDocs(),
    });
    docs_step.dependOn(&docs_install.step);
    b.default_step.dependOn(docs_step);
}
