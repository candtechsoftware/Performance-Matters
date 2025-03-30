const std = @import("std");

fn printSyntaxError(msg: []const u8, line: usize) void {
    std.log.err("[Syntax Error] line {d}: {s}\n", .{ line, msg });
}

pub const MarkdownParser = struct {
    allocator: std.mem.Allocator,
    lines_it: std.mem.SplitIterator(u8, .any),
    index: usize = 0,
    current_line: usize = 1,

    const Line = struct {
        tokens: []Token,
        data: []const u8
    };

    const State = enum {
        start_of_line,
        start_of_header,
        start_of_link,
    };

    const Token = struct {
        kind: Kind,
        data: Data,
        location: struct {
            start: usize,
            end: usize,
        },

        const Data = union {
            link: LinkData,
            text: []const u8, 
            
        };

        const LinkData = struct {
            key: []const u8,
            value: []const u8,
        };

        const Kind = enum {
            empty_line,

            header_one,
            header_two,
            header_three,
            header_four,
            header_five,
            header_six,

            link,
        };
    };

    pub fn init(allocator: std.mem.Allocator, data: []const u8) MarkdownParser {
        const it = std.mem.splitAny(u8, data, "\n");
        return .{
            .allocator = allocator,
            .lines_it = it,
        };
    }

    pub fn parse(self: *MarkdownParser) !void {
        var lines = std.ArrayList(Line).init(self.allocator);
        while (self.lines_it.next()) |line| {
            if (line.len <= 0) {
                const current_line: Line = .{ .data = try self.allocator.dupe(u8, line), .tokens = &[_]Token{} };
                try lines.append(current_line);
                std.debug.print("Line {d}: {any} \n", .{self.current_line, current_line});
            } else {
                const current_line = try self.parseLine(line);
                try lines.append(current_line);
                std.debug.print("Line {d}: {any} \n", .{self.current_line, current_line});
            }
            self.current_line += 1;
        }
    }
    pub fn parseLine(self: *MarkdownParser, line: []const u8) !Line {
        var index: usize = 0;
        var tokens = std.ArrayList(Token).init(self.allocator);
        st: switch (State.start_of_line) {
            .start_of_line => switch (line[index]) {
                '#' => {
                    index += 1;
                    continue :st .start_of_header;
                },
                '[' => {
                    index += 1;
                    continue :st .start_of_link;
                },
                else => {
                    index += 1;
                    continue :st .start_of_line;
                },
            },
            .start_of_header => {
                const start = index - 1; 
                var count: u8 = 1;
                while (line[index] == '#') {
                    count += 1;
                    index += 1;
                }


                const kind: Token.Kind = h: switch (count) {
                    1 => {
                        break :h .header_one;
                    },
                    2 => {
                        break :h .header_two;
                    },
                    3 => {
                        break :h .header_three;
                    },
                    4 => {
                        break :h .header_four;
                    },
                    5 => {
                        break :h .header_five;
                    },
                    6 => {
                        break :h .header_six;
                    },
                    else => {
                        printSyntaxError("invalid header syntax", self.current_line);
                        return error.InvalidSyntax;
                    },
                };

                const token: Token = .{
                    .kind = kind,
                    .data = .{ .text = line }, 
                    .location=  .{
                        .start = start, 
                        .end = line.len - 1, 
                    }, 

                }; 
                try tokens.append(token);
                return .{
                    .data = line, 
                    .tokens = try tokens.toOwnedSlice(), 
                };
            },

            .start_of_link => {
                const start = index - 1;
                const name_it = index;
                while (line[index] != ']') {
                    if (index >= line.len) {
                        // we need to continue as this was a text item
                        // TODO(Alex): Handles this better right now I am just trying to get all tokens
                        // we need to think of a paragraph as a token type or somthing else?
                        continue :st .start_of_line;
                    }
                    index += 1;
                }

                const name = line[name_it..index];
                std.debug.print("Name of link: {s}\n", .{name});
                var value: []const u8 = "";
                if (line[index] == '(') {
                    const value_it = index;
                    while (line[index] != ')') {
                        index += 1;
                        if (index >= line.len) {
                            // we need to continue as this was a text item
                            // TODO(Alex): Handles this better right now I am just trying to get all tokens
                            // we need to think of a paragraph as a token type or somthing else?
                            continue :st .start_of_line;
                        }
                    }
                    value = line[value_it..index];
                }
                const token: Token = .{
                    .kind = .link, 
                    .location = .{
                        .start = start, 
                        .end = index 
                    }, 
                    .data = .{
                        .link = .{
                            .key= name,
                            .value = value,
                        },
                    },
                };
                try tokens.append(token);
                index+= 1; 
            },
        }
        return .{
            .data = line, 
            .tokens = try tokens.toOwnedSlice(),
        };
    }
};
