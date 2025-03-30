const std = @import("std");

fn printSyntaxError(msg: []const u8, line: usize) void {
    std.log.err("[Syntax Error] line {d}: {s}\n", .{ line, msg });
}

pub const MarkdownParser = struct {
    allocator: std.mem.Allocator,
    lines_it: std.mem.SplitIterator(u8, .any),
    index: usize = 0,
    current_line: usize = 1,

    const State = enum {
        start_of_line,
        start_of_header,
    };

    const Token = struct {
        kind: Kind,
        line: usize,

        const Kind = enum {
            empty_line,

            header_one,
            header_two,
            header_three,
            header_four,
            header_five,
            header_six,
        };
    };

    pub fn init(allocator: std.mem.Allocator, data: []const u8) MarkdownParser {
        const it = std.mem.splitAny(u8, data, "\n");
        return .{
            .allocator = allocator,
            .lines_it = it,
        };
    }

    pub fn parse(self: *MarkdownParser) void {
        while (self.lines_it.next()) |line| {
            std.debug.print("Line: {s} :: len {d}\n", .{ line, line.len });
            if (line.len <= 0) {
                const token = .{ .kind = .empty_line, .line = self.current_line };
                std.debug.print("Token: {any} \n", .{token});
            } else {
                const token = self.parseLine(line);
                std.debug.print("Token: {any} \n", .{token});
            } 
            self.current_line += 1;
        }
    }
    pub fn parseLine(self: *MarkdownParser, line: []const u8) ?Token {
        var index: usize = 0;
        var token: Token = undefined;
        token.line = self.current_line;
        st: switch (State.start_of_line) {
            .start_of_line => switch (line[index]) {
                '#' => {
                    index += 1;
                    continue :st .start_of_header;
                },
                else => {
                    index += 1;
                    continue :st .start_of_line;
                },
            },
            .start_of_header => {
                token.line = self.current_line;
                var count: u8 = 1;
                while (line[index] == '#') {
                    count += 1;
                    index += 1;
                }

                token.kind = h: switch (count) {
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
                        return null;
                    },
                };
            },
        }
        return token;
    }
};
