const std = @import("std"); 
const net = std.net; 
const linux = std.os.linux;

const App = @import("App.zig");


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit(); 
    const allocator = gpa.allocator();

    var app = try App.init(allocator); 

    try app.run();
}


