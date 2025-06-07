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
    with_global_section: bool,
) !void {
    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    try nix.startSet();

    var in_first_section = true;
    if (with_global_section) {
        try nix.startAttribute("globalSection");
        try nix.startSet();
    }

    while (true) {
        const first_char = ini.readByte() catch |err| switch (err) {
            error.EndOfStream => {
                if (!in_first_section) {
                    try nix.endSet();
                    try nix.endAttribute();
                }
                if (with_global_section) {
                    try nix.endSet();
                    try nix.endAttribute();
                }
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
            if (!in_first_section or with_global_section) {
                try nix.endSet();
                try nix.endAttribute();
            }
            if (in_first_section and with_global_section) {
                try nix.startAttribute("sections");
                try nix.startSet();
            }
            try nix.startAttribute(section);
            try nix.startSet();
            in_first_section = false;
            continue;
        }

        // Key-value pair
        fbs.reset();
        fbs.writer().writeByte(first_char) catch unreachable;
        try ini.streamUntilDelimiter(fbs.writer(), '\n', null);

        const str = fbs.getWritten();
        var parts = std.mem.splitScalar(u8, str, '#'); // '#' Indicates comment
        const kvp = parts.first();
        const comment = parts.rest();

        var kvp_parts = std.mem.splitScalar(u8, kvp, '=');
        const key = std.mem.trim(u8, kvp_parts.first(), &std.ascii.whitespace);
        const value = std.mem.trim(u8, kvp_parts.rest(), &std.ascii.whitespace);

        // Comment only
        if (key.len == 0) {
            if (comment.len > 0) {
                try nix.newLine();
                try nix.writer.print("#{s}", .{comment});
            }
            continue;
        }

        try nix.startAttribute(key);
        try nix.writer.print("{}", .{nixValueFormatter(value)});
        try nix.endAttribute();
        // Inline coment
        if (comment.len > 0) {
            try nix.writer.print(" #{s}", .{comment});
        }
    }
}

fn nixKeyFormatter(key: []const u8) std.fmt.Formatter(formatNixKey) {
    return .{ .data = key };
}

fn formatNixKey(
    value: []const u8,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    try writer.writeByte('"');
    for (value) |c| {
        if (c == '"') {
            try writer.writeByte('\\');
        }
        try writer.writeByte(c);
    }
    try writer.writeByte('"');
}

fn nixValueFormatter(value: []const u8) std.fmt.Formatter(formatNixValue) {
    return .{ .data = value };
}

fn formatNixValue(
    value: []const u8,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    try writer.writeAll("''");
    var i: usize = 0;
    while (i < value.len) {
        if (i + 1 < value.len and std.mem.eql(u8, "'" ** 2, value[i .. i + 2])) {
            try writer.writeAll("'" ** 3);
            i += 2;
        } else {
            try writer.writeByte(value[i]);
            i += 1;
        }
    }
    try writer.writeAll("''");
}
