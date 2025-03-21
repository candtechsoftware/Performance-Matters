const std = @import("std");
const TemplateParser = @import("parser.zig").TemplateParser;
const Template = @import("parser.zig").Template;

const Self = @This();

allocator: std.mem.Allocator,
templates: std.ArrayList(Template),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .templates = std.ArrayList(Template).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn build(self: *Self) !void {
    // TODO(Alex): after getting this work benchmark it and then make it concurrent benchmark again
    // also all these functions do the same work generally so we could combine them
    // but a future state of this, I think should be we should parse and do other
    // processing in seperate threads so I will leave this like this for now?
    try self.readAllTemplates();
    try self.readAllArticles();
    try self.readAllPages();
}

pub fn readAllPages(self: *Self) !void {
    var dir = try std.fs.cwd().openDir("content/pages", .{ .iterate = true });
    var iter = dir.iterate();

    while (try iter.next()) |it| {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{
            "content/pages",
            it.name,
        });
        const data = try std.fs.cwd().readFileAlloc(self.allocator, path, 1024 * 1024);
        var parser: TemplateParser = .{ .data = data };
        const template = try parser.parse(self.allocator, it.name);
        template.print();
        try self.templates.append(template); 

    }
}

pub fn readAllArticles(self: *Self) !void {
    var dir = try std.fs.cwd().openDir("content/articles", .{ .iterate = true });
    var iter = dir.iterate();

    while (try iter.next()) |it| {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{
            "content/articles",
            it.name,
        });
        _ = try std.fs.cwd().readFileAlloc(self.allocator, path, 1024 * 1024);
    }
}

pub fn readAllTemplates(self: *Self) !void {
    var dir = try std.fs.cwd().openDir("content/templates", .{ .iterate = true });
    var iter = dir.iterate();

    while (try iter.next()) |it| {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{
            "content/templates",
            it.name,
        });
        _ = try std.fs.cwd().readFileAlloc(self.allocator, path, 1024 * 1024);
    }
}
