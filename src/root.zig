const std = @import("std");

pub fn convert(
    ini: std.io.AnyReader,
    nix: std.io.AnyWriter,
    write_comments: bool,
) !void {
    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    try nix.writeAll("{\n");

    try nix.print("  \"{s}\" = {{\n", .{"globalSection"});
    while (true) {
        const first_char = ini.readByte() catch |err| switch (err) {
            error.EndOfStream => {
                try nix.writeAll("  };\n}");
                return;
            },
            else => |e| return e,
        };

        // Leading whitespace
        if (first_char == ' ') continue;
        // Empty line
        if (first_char == '\n') continue;

        // Section start
        if (first_char == '[') {
            fbs.reset();
            try ini.streamUntilDelimiter(fbs.writer(), '\n', null);
            const str = fbs.getWritten();

            var parts = std.mem.splitScalar(u8, str, ']');
            const section = parts.first();
            try nix.print("  }};\n  \"{s}\" = {{\n", .{section});
            continue;
        }

        // Key-value pair
        fbs.reset();
        fbs.writer().writeByte(first_char) catch unreachable;
        try ini.streamUntilDelimiter(fbs.writer(), '\n', null);

        const str = fbs.getWritten();
        var parts = std.mem.splitScalar(u8, str, '#');
        const kvp = parts.first();
        const comment = parts.rest();

        var kvp_parts = std.mem.splitScalar(u8, kvp, '=');
        const key = parseKeyOrValue(kvp_parts.first());
        const value = parseKeyOrValue(kvp_parts.rest());

        // Comment only
        if (key.len == 0) {
            if (write_comments and comment.len > 0) {
                try nix.print("    #{s}\n", .{comment});
            }
            continue;
        }

        if (write_comments and comment.len > 0) {
            try nix.print("    \"{s}\" = {}; #{s}\n", .{ key, valueFormatter(value), comment });
        } else {
            try nix.print("    \"{s}\" = {};\n", .{ key, valueFormatter(value) });
        }
    }
}

fn parseKeyOrValue(raw: []const u8) []const u8 {
    const no_whitespace = std.mem.trim(u8, raw, &std.ascii.whitespace);
    return std.mem.trim(u8, no_whitespace, "\"");
}

fn valueFormatter(value: []const u8) std.fmt.Formatter(formatValue) {
    return .{ .data = value };
}

fn formatValue(
    value: []const u8,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    // Bool
    if (std.ascii.eqlIgnoreCase(value, "True")) {
        return writer.writeAll("true");
    }
    if (std.ascii.eqlIgnoreCase(value, "False")) {
        return writer.writeAll("false");
    }

    // Int or float
    blk: {
        _ = std.fmt.parseFloat(f64, value) catch break :blk;
        return writer.writeAll(value);
    }

    // String
    try writer.print("''{s}''", .{value});
}
