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

pub const Content = struct {
    name: []const u8,
    kind: Kind,
    data: []const u8,

    const Kind = enum {
        template,
        markdown,
        page,
    };
};

pub const Site = struct {
    pages: []HtmlPage,

    pub fn build(self: *Site) !void {
        _ = self;
    }
};

pub const HtmlPage = struct {
    final_path: []const u8,
    name: []const u8,
    templates: []const u8, // name of templates in use
    data: []const u8,
};

pub fn parseContent(allocator: std.mem.Allocator) !Site {
    var pages = std.ArrayList(HtmlPage).init(allocator);

    // TODO(Alex) Do work here...

    return .{
        .pages = try pages.toOwnedSlice(),
    };
}

