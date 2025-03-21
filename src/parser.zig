const std = @import("std");

pub const Template = struct {
    name: []const u8,
    data: []u8,
    templates: []Variable,

    pub fn print(self: Template) void {
        std.debug.print("Template {{\n\tname: {s},\n\ttemplates: [ ", .{self.name});
        for (self.templates) |t| {
            t.print();
        }
        std.debug.print("\n\t],\n}}\n\n", .{});
    }
};

const Variable = struct {
    kind: VariableKind,
    name: []const u8,
    pos: struct {
        start: usize,
        end: usize,
    },

    pub fn print(self: Variable) void {
        std.debug.print("\n\t\tVariable {{\n\t\t\tkind: {any},\n\t\t\tname: {s},\n\t\t\tpos: {any},\n\t\t}},", .{ self.kind, self.name, self.pos });
    }
};

const VariableKind = enum {
    none,
    value,
    template,
};

pub const TemplateParser = struct {
    index: usize = 0,
    data: []u8,

    const State = enum {
        start,
        var_start,
        var_name_start,
        var_end,
    };

    pub fn parse(self: *TemplateParser, allocator: std.mem.Allocator, name: []const u8) !Template {
        var template: Template = .{ .data = self.data, .templates = undefined, .name = name };
        var variables = std.ArrayList(Variable).init(allocator);

        while (self.next()) |v| {
            try variables.append(v);
        }

        template.templates = try variables.toOwnedSlice();
        return template;
    }

    pub fn next(self: *TemplateParser) ?Variable {
        var result: Variable = .{
            .kind = .none,
            .name = undefined,
            .pos = .{
                .start = 0,
                .end = 0,
            },
        };

        st: switch (State.start) {
            .start => switch (self.data[self.index]) {
                0 => {
                    if (self.index == self.data.len) {
                        return null;
                    }
                },
                '{' => {
                    self.index += 1;
                    continue :st .var_start;
                },
                else => {
                    self.index += 1;
                    if (self.index == self.data.len) return null;
                    continue :st .start;
                },
            },
            .var_start => {
                result.kind = .value;
                result.pos.start = self.index;

                while (true) {
                    switch (self.data[self.index]) {
                        '{' => {
                            self.index += 1;
                        },

                        '>' => {
                            self.index += 1;
                            result.kind = .template;
                        },
                        ' ' => {
                            self.index += 1;
                            continue :st .var_name_start;
                        },
                        else => {
                            std.log.warn("should not enter here we should be in the correct state for a var_start", .{});
                            return null;
                        },
                    }
                }
            },
            .var_name_start => {
                const start_idx = self.index;
                while (self.data[self.index] != ' ') {
                    self.index += 1;
                }
                result.name = self.data[start_idx..self.index];
                continue :st .var_end;
            },
            .var_end => {
                if (self.data[self.index] != ' ') {
                    std.log.warn("Invalid syntax need a space in variable decl {c} \n", .{self.data[self.index]});
                }
                self.index += 1;

                var seen: u8 = 0;
                while (seen < 2) {
                    if (self.data[self.index] == '}') {
                        self.index += 1;
                        seen += 1;
                    } else {
                        std.log.warn("Invalid syntax decl {d} ::  {c} \n", .{ seen, self.data[self.index] });
                        return result; // TODO(Alex) make this an syntax error as well
                    }
                }
                result.pos.end = self.index;
            },
        }

        return result;
    }
};
