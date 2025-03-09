const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const all_templates = try findAllContent(arena.allocator());

    for (all_templates) |t| {
        std.debug.print("Name {s} kind {any}\n", .{ t.name, t.kind });
    }
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

pub fn findAllContent(allocator: std.mem.Allocator) ![]Content {
    var arr = std.ArrayList(Content).init(allocator);

    // TODO(Alex): after getting this work benchmark it and then make it concurrent benchmark again
    try readAllPages(allocator, arr);
    try readAllTemplates(allocator, arr);
    try readAllArticles(allocator, arr);

    return arr.toOwnedSlice();
}

pub fn readAllPages(allocator: std.mem.Allocator, content_list: std.ArrayList(Content)) !void {
    var dir = try std.fs.cwd().openDir("content/pages", .{ .iterate = true });
    var iter = dir.iterate();

    _ = content_list;
    _ = allocator;

    std.debug.print("Pages\n", .{});
    while (try iter.next()) |it| {
        std.debug.print("Name: {s} Kind: {any}\n", .{ it.name, it.kind });
    }
    std.debug.print("=============\n", .{});
}

pub fn readAllArticles(allocator: std.mem.Allocator, content_list: std.ArrayList(Content)) !void {
    var dir = try std.fs.cwd().openDir("content/articles", .{ .iterate = true });
    var iter = dir.iterate();

    _ = content_list;
    _ = allocator;

    std.debug.print("Articles\n", .{});
    while (try iter.next()) |it| {
        std.debug.print("Name: {s} Kind: {any}\n", .{ it.name, it.kind });
    }
    std.debug.print("=============\n", .{});
}

pub fn readAllTemplates(allocator: std.mem.Allocator, content_list: std.ArrayList(Content)) !void {
    var dir = try std.fs.cwd().openDir("content/templates", .{ .iterate = true });
    var iter = dir.iterate();

    _ = content_list;
    _ = allocator;

    std.debug.print("Templates\n", .{});
    while (try iter.next()) |it| {
        std.debug.print("Name: {s} Kind: {any}\n", .{ it.name, it.kind });
    }
    std.debug.print("=============\n", .{});
}
