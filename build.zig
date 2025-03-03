const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
       .name = "site",
       .root_source_file = b.path("src/main.zig"), 
       .optimize =  optimize,
       .target =  target,
    });

    b.installArtifact(exe);

   // const exe_check = b.addExecutable(.{
   //     .name = "site",
   //     .root_source_file = b.path("src/main.zig"), 
   //     .optimize =  optimize,
   //     .target =  target,
   // });

   // const check = b.step("check", "Check to see if exe compiles for zls");
   // check.dependOn(&exe_check.step);
}
