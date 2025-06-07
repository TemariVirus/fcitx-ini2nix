{ pkgs, stdenv, zig }:
stdenv.mkDerivation {
  pname = "fcitx-ini2nix";
  version = "0.0.0";

  src = ../.;

  nativeBuildInputs = [ zig.hook ];

  postPatch = ''
    ln -s ${pkgs.callPackage ./deps.nix { }} $ZIG_GLOBAL_CACHE_DIR/p
  '';
}
