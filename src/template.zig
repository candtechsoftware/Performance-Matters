const std = @import("std");
const SiteBuilder = @import("SiteBuilder.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var builder = SiteBuilder.init(arena.allocator()); 

    try builder.build(); 
}
