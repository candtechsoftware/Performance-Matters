const std = @import("std");
const parser = @import("parser.zig");
const ParseResult = parser.ParseResult;
const MarkdownParser = @import("markdown.zig").MarkdownParser;

const Self = @This();

allocator: std.mem.Allocator,
pages: std.ArrayList(*ParseResult),
templates: std.ArrayList(*ParseResult),

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .allocator = allocator,
        .templates = std.ArrayList(*ParseResult).init(allocator),
        .pages = std.ArrayList(*ParseResult).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    for (self.pages.items) |page| {
        page.deinit();
        self.allocator.destroy(page);
    }
    for (self.templates.items) |template| {
        template.deinit();
        self.allocator.destroy(template);
    }
    self.pages.deinit();
    self.templates.deinit();
}

pub fn build(self: *Self) !void {
    // TODO(Alex): after getting this work benchmark it and then make it concurrent benchmark again
    // also all these functions do the same work generally so we could combine them
    // but a future state of this, I think should be we should parse and do other
    // processing in seperate threads so I will leave this like this for now?
    //std.debug.print("\nTemplates:: \n========\n", .{});
    //try self.readAllTemplates();
    std.debug.print("\nArticles:: \n========\n", .{});
    try self.readAllArticles();
    //std.debug.print("Pages:: \n========\n", .{});
    //try self.readAllPages();
}

pub fn readAllPages(self: *Self) !void {
    var dir = try std.fs.cwd().openDir("content/pages", .{ .iterate = true });
    var iter = dir.iterate();

    while (try iter.next()) |it| {
        std.debug.print("\nProcessing page: {s}\n", .{it.name});
        
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{
            "content/pages",
            it.name,
        });
        defer self.allocator.free(path);
        
        const data = try std.fs.cwd().readFileAlloc(self.allocator, path, 1024 * 1024);
        defer self.allocator.free(data);
        
        const result_ptr = try self.allocator.create(ParseResult);
        errdefer self.allocator.destroy(result_ptr);
        
        result_ptr.* = try parser.parseDocument(self.allocator, data);
        try self.pages.append(result_ptr);

        // Print the parsed page
        result_ptr.print();
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
        const data = try std.fs.cwd().readFileAlloc(self.allocator, path, 1024 * 1024);
        var mkparser= MarkdownParser.init(self.allocator, data);
        try mkparser.parse();
    }
}

pub fn readAllTemplates(self: *Self) !void {
    var dir = try std.fs.cwd().openDir("content/templates", .{ .iterate = true });
    var iter = dir.iterate();

    while (try iter.next()) |it| {
        std.debug.print("\nProcessing template: {s}\n", .{it.name});
        
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{
            "content/templates",
            it.name,
        });
        defer self.allocator.free(path);
        
        const data = try std.fs.cwd().readFileAlloc(self.allocator, path, parser.ARENA_SIZE);
        defer self.allocator.free(data);
        
        const result_ptr = try self.allocator.create(ParseResult);
        errdefer self.allocator.destroy(result_ptr);
        
        result_ptr.* = try parser.parseDocument(self.allocator, data);
        try self.templates.append(result_ptr);

        // Print the parsed template
        result_ptr.print();
    }
}
