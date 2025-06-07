const std = @import("std");

pub const NixWriter = struct {
    indent_size: usize,
    indents: usize = 0,
    writer: std.io.AnyWriter,

    pub fn init(writer: std.io.AnyWriter, indent_size: usize) NixWriter {
        return NixWriter{
            .indent_size = indent_size,
            .writer = writer,
        };
    }

    pub fn startSet(self: *NixWriter) !void {
        try self.writer.writeByte('{');
        self.indents += 1;
    }

    pub fn endSet(self: *NixWriter) !void {
        self.indents -|= 1;
        try self.newLine();
        try self.writer.writeByte('}');
    }

    pub fn startAttribute(self: NixWriter, name: []const u8) !void {
        try self.newLine();
        try self.writer.print("\"{s}\" = ", .{name});
    }

    pub fn endAttribute(self: NixWriter) !void {
        try self.writer.writeByte(';');
    }

    pub fn newLine(self: NixWriter) !void {
        try self.writer.writeByte('\n');
        try self.writer.writeByteNTimes(' ', self.indents * self.indent_size);
    }
};

pub fn convert(
    ini: std.io.AnyReader,
    nix: *NixWriter,
    write_comments: bool,
) !void {
    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    try nix.startSet();

    var in_global_section = true;
    try nix.startAttribute("globalSection");
    try nix.startSet();
    while (true) {
        const first_char = ini.readByte() catch |err| switch (err) {
            error.EndOfStream => {
                if (!in_global_section) {
                    try nix.endSet();
                    try nix.endAttribute();
                }
                try nix.endSet();
                try nix.endAttribute();
                try nix.endSet();
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
            try nix.endSet();
            try nix.endAttribute();
            if (in_global_section) {
                try nix.startAttribute("sections");
                try nix.startSet();
            }
            try nix.startAttribute(section);
            try nix.startSet();
            in_global_section = false;
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
        const key = parseIniKeyOrValue(kvp_parts.first());
        const value = parseIniKeyOrValue(kvp_parts.rest());

        // Comment only
        if (key.len == 0) {
            if (write_comments and comment.len > 0) {
                try nix.newLine();
                try nix.writer.print("#{s}", .{comment});
            }
            continue;
        }

        try nix.startAttribute(key);
        try nix.writer.print("{}", .{iniValueFormatter(value)});
        try nix.endAttribute();
        if (write_comments and comment.len > 0) {
            try nix.writer.print(" #{s}", .{comment});
        }
    }
}

fn parseIniKeyOrValue(raw: []const u8) []const u8 {
    const no_whitespace = std.mem.trim(u8, raw, &std.ascii.whitespace);
    return std.mem.trim(u8, no_whitespace, "\"");
}

fn iniValueFormatter(value: []const u8) std.fmt.Formatter(formatIniValue) {
    return .{ .data = value };
}

fn formatIniValue(
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
