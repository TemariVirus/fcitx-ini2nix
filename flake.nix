{
  description =
    "fcitx-ini2nix converts your local fcitx config to a Nix attribute set.";

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-linux" "x86_64-linux" ];

      perSystem = { system, pkgs, ... }:
        let inherit (pkgs) callPackage zig_0_14;
        in {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.zig-overlay.overlays.default ];
            config = { };
          };

          packages.default = callPackage nix/package.nix { zig = zig_0_14; };
        };
    };
}
