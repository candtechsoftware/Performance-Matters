const std = @import("std");
const SiteBuilder = @import("SiteBuilder.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var builder = try SiteBuilder.init(arena.allocator());
    defer builder.deinit();

    try builder.build();
}
