const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const DOC_GLOBAL_SCOPE = "global";
const NULL_INDEX = -1;

const State = enum { start, in_tag, in_var, in_tmpl };

const MAX_STRING_BUFFER = 1024 * 1024; // 1MB string buffer
pub const ARENA_SIZE = 1024 * 1024 * 10; // 10MB arena

pub const NodeType = enum { 
    text,
    element,
    loop,
    conditional,
    template,
};

pub const Node = struct {
    type: NodeType,
    parent: ?*Node,
    children: std.ArrayList(*Node),
    
    data: union(NodeType) {
        text: struct { content: []const u8 },
        element: struct { 
            tag: []const u8,
            attrs: std.ArrayList(Attr),
        },
        loop: struct { 
            iterator: []const u8,
            collection: []const u8,
            scope: *Scope,
        },
        conditional: struct {
            condition: []const u8,
            scope: *Scope,
        },
        template: struct { name: []const u8 },
    },

    pub fn init(allocator: Allocator, node_type: NodeType) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .type = node_type,
            .parent = null,
            .children = std.ArrayList(*Node).init(allocator),
            .data = undefined,
        };
        return node;
    }

    pub fn deinit(self: *Node) void {
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();
        // Data-specific cleanup would go here
    }
};

pub const Attr = struct {
    key: []const u8,
    value: []const u8,
};

pub const Variable = struct {
    name: []const u8,
    source: ?struct {  // null if not a loop variable
        collection: []const u8,
        loop_node: *Node,
    },
};

pub const Scope = struct {
    variables: std.ArrayList(Variable),
    parent: ?*Scope,
    children: std.ArrayList(*Scope),
    depth: u32,

    pub fn init(allocator: Allocator) !*Scope {
        const scope = try allocator.create(Scope);
        scope.* = .{
            .variables = std.ArrayList(Variable).init(allocator),
            .parent = null,
            .children = std.ArrayList(*Scope).init(allocator),
            .depth = 0,
        };
        return scope;
    }

    pub fn addVariable(self: *Scope, name: []const u8, collection: ?[]const u8, loop_node: ?*Node) !void {
        try self.variables.append(.{
            .name = name,
            .source = if (collection != null and loop_node != null) .{
                .collection = collection.?,
                .loop_node = loop_node.?,
            } else null,
        });
    }

    pub fn print(self: *const Scope, depth: usize) void {
        // Print indentation
        for (0..depth) |_| {
            std.debug.print("  ", .{});
        }
        std.debug.print("Scope:\n", .{});

        // Print variables
        for (self.variables.items) |var_| {
            for (0..depth + 1) |_| {
                std.debug.print("  ", .{});
            }
            if (var_.source) |src| {
                std.debug.print("Loop var: {s} from collection: {s}\n", .{ var_.name, src.collection });
            } else {
                std.debug.print("Var: {s}\n", .{var_.name});
            }
        }

        // Print child scopes
        for (self.children.items) |child| {
            child.print(depth + 1);
        }
    }
};

pub const ParseResult = struct {
    arena: ArenaAllocator,
    root: *Node,
    global_scope: *Scope,

    pub fn deinit(self: *ParseResult) void {
        self.root.deinit();
        self.arena.deinit();
    }

    pub fn print(self: *const ParseResult) void {
        std.debug.print("\nParse Result:\n============\n", .{});
        self.printNode(self.root, 0);
        std.debug.print("\nScopes:\n=======\n", .{});
        self.global_scope.print(0);
    }

    fn printNode(self: *const ParseResult, node: *Node, depth: usize) void {
        // Print indentation
        for (0..depth) |_| {
            std.debug.print("  ", .{});
        }

        // Print node info
        switch (node.type) {
            .text => std.debug.print("Text: \"{s}\"\n", .{node.data.text.content}),
            .element => {
                std.debug.print("Element: <{s}>\n", .{node.data.element.tag});
                for (node.data.element.attrs.items) |attr| {
                    for (0..depth + 1) |_| {
                        std.debug.print("  ", .{});
                    }
                    std.debug.print("Attr: {s}=\"{s}\"\n", .{ attr.key, attr.value });
                }
            },
            .loop => std.debug.print("Loop: {s} in {s}\n", .{ 
                node.data.loop.iterator, 
                node.data.loop.collection 
            }),
            .conditional => std.debug.print("If: {s}\n", .{node.data.conditional.condition}),
            .template => std.debug.print("Template: {s}\n", .{node.data.template.name}),
        }

        // Print children
        for (node.children.items) |child| {
            self.printNode(child, depth + 1);
        }
    }
};

pub const DocParser = struct {
    allocator: Allocator,
    root: *Node,
    current_node: *Node,
    current_scope: *Scope,
    global_scope: *Scope,
    attr_buffer: std.ArrayList(Attr),

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        // Create root node
        const root = try Node.init(allocator, .element);
        root.data = .{ .element = .{
            .tag = "root",
            .attrs = std.ArrayList(Attr).init(allocator),
        }};

        // Create global scope
        const global_scope = try Scope.init(allocator);

        return Self{
            .allocator = allocator,
            .root = root,
            .current_node = root,
            .current_scope = global_scope,
            .global_scope = global_scope,
            .attr_buffer = std.ArrayList(Attr).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.root.deinit();
        self.attr_buffer.deinit();
    }

    pub fn reset(self: *Self) void {
        self.current_node = self.root;
        self.current_scope = self.global_scope;
        self.attr_buffer.clearRetainingCapacity();
    }

    fn addNode(self: *Self, node: *Node, parent: *Node) !void {
        _ = self; // Mark self as used
        node.parent = parent;
        try parent.children.append(node);
    }

    fn addElementNode(self: *Self, tag: []const u8) !*Node {
        const element_node = try Node.init(self.allocator, .element);
        element_node.data = .{ .element = .{
            .tag = tag,
            .attrs = std.ArrayList(Attr).init(self.allocator),
        }};
        
        // Move attributes from buffer to node
        try element_node.data.element.attrs.appendSlice(self.attr_buffer.items);
        self.attr_buffer.clearRetainingCapacity();
        
        try self.addNode(element_node, self.current_node);
        return element_node;
    }

    fn addScope(self: *Self, parent: *Scope) !*Scope {
        const depth = if (parent != self.global_scope)
            parent.depth + 1
        else
            0;

        const new_scope = try Scope.init(self.allocator);
        new_scope.depth = depth;
        new_scope.parent = parent;
        try parent.children.append(new_scope);
        return new_scope;
    }

    fn addVariable(self: *Self, scope: *Scope, name: []const u8, collection: ?[]const u8, loop_node: ?*Node) !void {
        _ = self; // Mark self as used
        try scope.addVariable(name, collection, loop_node);
    }

    fn flushText(self: *Self, start: usize, end: usize, input: []const u8) !void {
        if (start < end) {
            const text_content = input[start..end];
            const text_node = try Node.init(self.allocator, .text);
            text_node.data = .{ .text = .{ 
                .content = text_content 
            }};
            try self.addNode(text_node, self.current_node);
        }
    }

    fn checkPattern(self: *Self, input: []const u8, pos: usize, pat: []const u8) bool {
        _ = self;
        return pos + pat.len <= input.len and
            std.mem.eql(u8, input[pos .. pos + pat.len], pat);
    }
};

pub fn parseDocument(allocator: Allocator, input: []const u8) !ParseResult {
    var arena = ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    
    var parser = try DocParser.init(allocator);
    errdefer parser.deinit();
    
    var state: State = .start;
    var cursor: usize = 0;
    var text_start: usize = 0;
    var current_tag_start: usize = 0;

    while (cursor < input.len) : (cursor += 1) {
        const c = input[cursor];
        switch (state) {
            .start => switch (c) {
                '{' => {
                    if (parser.checkPattern(input, cursor, "{{>")) {
                        try parser.flushText(text_start, cursor, input);
                        state = .in_tmpl;
                        cursor += 2;
                        text_start = cursor + 1;
                    } else if (parser.checkPattern(input, cursor, "{{")) {
                        try parser.flushText(text_start, cursor, input);
                        state = .in_var;
                        cursor += 1;
                        text_start = cursor + 1;
                    }
                },
                '<' => {
                    try parser.flushText(text_start, cursor, input);
                    state = .in_tag;
                    current_tag_start = cursor + 1;
                },
                else => continue,
            },
            .in_tag => switch (c) {
                '>' => {
                    if (input[current_tag_start] == '/') {
                        // Handle closing tag
                        if (parser.current_node != parser.root) {
                            const parent = parser.current_node.parent.?;
                            switch (parent.type) {
                                .loop, .conditional => {
                                    parser.current_scope = parser.current_scope.parent.?;
                                },
                                else => {},
                            }
                            parser.current_node = parent;
                        }
                    } else {
                        const tag = input[current_tag_start..cursor];
                        const elem_node = try parser.addElementNode(tag);
                        parser.current_node = elem_node;
                    }
                    state = .start;
                    text_start = cursor + 1;
                },
                '*' => {
                    if (parser.checkPattern(input, cursor, "**")) {
                        cursor += 1;
                        const attr_start = cursor + 1;
                        while (cursor < input.len and input[cursor] != '=') : (cursor += 1) {}
                        const key = input[attr_start..cursor];
                        cursor += 2; // Skip ="
                        const value_start = cursor;
                        while (cursor < input.len and input[cursor] != '"') : (cursor += 1) {}
                        const value = input[value_start..cursor];
                        try parser.attr_buffer.append(.{ .key = key, .value = value });

                        if (std.mem.eql(u8, key, "if")) {
                            const new_scope = try parser.addScope(parser.current_scope);
                            const cond_node = try Node.init(parser.allocator, .conditional);
                            cond_node.data = .{ .conditional = .{
                                .condition = value,
                                .scope = new_scope,
                            } };
                            try parser.addNode(cond_node, parser.current_node);
                            parser.current_node = cond_node;
                            parser.current_scope = new_scope;
                        } else if (std.mem.eql(u8, key, "for")) {
                            var parts = std.mem.splitSequence(u8, value, " ");
                            _ = parts.next(); // Skip 'var'/'let'
                            const iter = parts.next().?;
                            _ = parts.next(); // Skip 'in'
                            const collection = parts.next().?;

                            const new_scope = try parser.addScope(parser.current_scope);
                            const loop_node = try Node.init(parser.allocator, .loop);
                            loop_node.data = .{ .loop = .{
                                .iterator = iter,
                                .collection = collection,
                                .scope = new_scope,
                            }};
                            try parser.addNode(loop_node, parser.current_node);
                            
                            try parser.addVariable(new_scope, iter, collection, loop_node);
                            
                            parser.current_node = loop_node;
                            parser.current_scope = new_scope;
                        }
                    }
                },
                else => continue,
            },
            .in_var => {
                if (parser.checkPattern(input, cursor, "}}")) {
                    const var_name = input[text_start..cursor];
                    try parser.addVariable(parser.current_scope, var_name, null, null);
                    state = .start;
                    text_start = cursor + 2;
                    cursor += 1;
                }
            },
            .in_tmpl => {
                if (parser.checkPattern(input, cursor, "}}")) {
                    const tmpl_name = input[text_start..cursor];
                    const tmpl_node = try Node.init(parser.allocator, .template);
                    tmpl_node.data = .{ .template = .{ 
                        .name = tmpl_name 
                    }};
                    try parser.addNode(tmpl_node, parser.current_node);
                    state = .start;
                    text_start = cursor + 2;
                    cursor += 1;
                }
            },
        }
    }
    try parser.flushText(text_start, cursor, input);

    return ParseResult{
        .arena = arena,
        .root = parser.root,
        .global_scope = parser.global_scope,
    };
}

