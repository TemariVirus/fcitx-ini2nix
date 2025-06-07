const std = @import("std");

const known_folders = @import("known-folders");

const lib = @import("root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config_dir = blk: {
        var local_config = try known_folders.open(
            allocator,
            .local_configuration,
            .{},
        ) orelse @panic("unable to open ~/.config");
        defer local_config.close();
        break :blk try local_config.openDir("fcitx5", .{});
    };
    defer config_dir.close();

    const stdout = std.io.getStdOut();
    var bw = std.io.bufferedWriter(stdout.writer());
    const writer = bw.writer().any();

    try writer.writeAll("{\n  inputMethod = ");
    try convertFile(config_dir, "profile", writer);
    try writer.writeAll(";\n  globalOptions = ");
    try convertFile(config_dir, "config", writer);

    try writer.writeAll(";\n  addons = {");
    {
        var conf_dir = try config_dir.openDir("conf", .{ .iterate = true });
        defer conf_dir.close();

        var it = conf_dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (std.mem.eql(u8, "cached_layouts", entry.name)) continue;

            try writer.print("\n  {s} = ", .{std.fs.path.stem(entry.name)});
            try convertFile(conf_dir, entry.name, writer);
            try writer.writeByte(';');
        }
    }
    try writer.writeAll("\n};\n}");

    try bw.flush();
}

fn convertFile(
    config_dir: std.fs.Dir,
    sub_path: []const u8,
    writer: std.io.AnyWriter,
) !void {
    const f = try config_dir.openFile(sub_path, .{});
    defer f.close();
    var br = std.io.bufferedReader(f.reader());
    try lib.convert(br.reader().any(), writer, false);
}
