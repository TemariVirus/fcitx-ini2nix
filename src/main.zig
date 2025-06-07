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
    defer bw.flush() catch @panic("Failed to flush");

    var nix: lib.NixWriter = .init(bw.writer().any(), 2);
    try nix.startSet();
    defer nix.endSet() catch @panic("Failed to write");

    try convertFile(config_dir, "profile", "inputMethod", false, &nix);
    try convertFile(config_dir, "config", "globalOptions", false, &nix);

    try nix.startAttribute("addons");
    defer nix.endAttribute() catch @panic("Failed to write");
    try nix.startSet();
    defer nix.endSet() catch @panic("Failed to write");

    var conf_dir = try config_dir.openDir("conf", .{ .iterate = true });
    defer conf_dir.close();
    var it = conf_dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.eql(u8, "cached_layouts", entry.name)) continue;
        const attr_name = std.fs.path.stem(entry.name);
        try convertFile(conf_dir, entry.name, attr_name, true, &nix);
    }
}

fn convertFile(
    config_dir: std.fs.Dir,
    sub_path: []const u8,
    attribute_name: []const u8,
    with_global_section: bool,
    nix: *lib.NixWriter,
) !void {
    const f = try config_dir.openFile(sub_path, .{});
    defer f.close();
    var br = std.io.bufferedReader(f.reader());

    try nix.startAttribute(attribute_name);
    try lib.convert(br.reader().any(), nix, with_global_section);
    try nix.endAttribute();
}
