# fcitx-ini2nix

Convert [Fcitx5](https://fcitx-im.org/) configuration files to Nix.

## Usage

```sh
# Create a new shell with the package installed
nix shell github:TemariVirus/fcitx-ini2nix
# Run the program
fcitx-ini2nix
```

Prints the current user's Fcitx5 configuration to stdout as a nix attribute set,
ready to be assigned to `i18n.inputMethod.fcitx5.settings`.
