const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const server_exe = b.addExecutable(.{
       .name = "server",
       .root_source_file = b.path("src/server.zig"), 
       .optimize =  optimize,
       .target =  target,
    });

    const template_exe = b.addExecutable(.{
       .name = "template",
       .root_source_file = b.path("src/template.zig"), 
       .optimize =  optimize,
       .target =  target,
    });

    b.installArtifact(server_exe);
    b.installArtifact(template_exe);

    const server_check = b.addExecutable(.{
        .name = "server",
        .root_source_file = b.path("src/server.zig"), 
        .optimize =  optimize,
        .target =  target,
    });

    const tempalate_check = b.addExecutable(.{
        .name = "template",
        .root_source_file = b.path("src/template.zig"), 
        .optimize =  optimize,
        .target =  target,
    });

    const check = b.step("check", "Check to see if exe compiles for zls");
    check.dependOn(&server_check.step);
    check.dependOn(&tempalate_check.step);
}
