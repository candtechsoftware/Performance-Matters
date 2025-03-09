const std = @import("std");
const Allocator = std.mem.Allocator;
const Self = @This();

const Config = struct {
    port: u16 = 8081,
    host: []const u8 = "0.0.0.0",
    timeout_ms: u32 = 30000,
};

allocator: Allocator,
config: Config,
server: std.net.Server,

pub fn init(allocator: Allocator) !Self {
    const config: Config = .{};
    var addr = try std.net.Address.parseIp(config.host, config.port);
    const server = try addr.listen(.{});
    return .{
        .server = server,
        .config = config,
        .allocator = allocator,
    };
}

pub fn run(self: *Self) !void {
    std.log.info("Server running on {s}:{d}\n", .{ self.config.host, self.config.port });
    while (true) {
        const connection = try self.server.accept();

        handleConnection(self.allocator, connection) catch |err| {
            std.log.err("Error handling a connection: {any}\n", .{err});
        };
    }
}

pub fn handleConnection(allocator: Allocator, connection: std.net.Server.Connection) !void {
    defer connection.stream.close();

    var buffer: [4096]u8 = undefined;
    const bytes_read = try connection.stream.read(&buffer);
    const request = buffer[0..bytes_read];

    const req_line_end = std.mem.indexOf(u8, request, "\r\n") orelse request.len;
    const req_line = request[0..req_line_end]; // ex GET / HTTP 1/1
    _ = req_line;

    var iter = std.mem.splitAny(u8, request, " ");
    const method = iter.next() orelse return error.InvalidRequest;
    const path = iter.next() orelse return error.InvalidRequest;

    std.log.info("Recieved request {s} {s} \n", .{ method, path });

    switch (handleMethod(method)) {
        .GET => {
            try serveFile(allocator, connection, path);
        },
        else => {
            // TODO(Alex): should return 500 error or something
            std.log.err("Unimplemented method {s}\n", .{method});
            return error.InvalidRequest;
        },
    }
}

pub fn handleMethod(method_str: []const u8) std.http.Method {
    return @enumFromInt(std.http.Method.parse(method_str));
}

pub fn getPath(path_from_request: []const u8) []const u8 {
    // Check for root or index paths
    if (std.mem.eql(u8, path_from_request, "/") or std.mem.eql(u8, path_from_request, "/index.html")) {
        return "index.html";
    }

    // Check for articles list page
    if (std.mem.eql(u8, path_from_request, "/articles")) {
        return "articles.html";
    }

    return "404.html";
}



pub fn serveFile(allocator: Allocator, connection: std.net.Server.Connection, path_from_request: []const u8) !void {
    if (std.mem.indexOf(u8, path_from_request, "..") != null) {
        return error.InvalidPath;
    }


    const path = getPath(path_from_request);
    const full_path = try std.fmt.allocPrint(allocator, "public/{s}", .{path});
    defer allocator.free(full_path);

    const file = try std.fs.cwd().openFile(full_path, .{});
    defer file.close();

    const state = try file.stat();
    const file_size = state.size;

    const headers = try std.fmt.allocPrint(
        allocator,
        "HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\n\r\n",
        .{ "text/html", file_size },
    );
    defer allocator.free(headers);

    _ = try connection.stream.write(headers); // send heanders

    var buffer: [8192]u8 = undefined;
    while (true) {
        const bytes_read = try file.read(&buffer);
        if (bytes_read == 0) break; // EOF
        _ = try connection.stream.write(buffer[0..bytes_read]);
    }
}
