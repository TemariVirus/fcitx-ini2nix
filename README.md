# fcitx-ini2nix

Converts [Fcitx5](https://fcitx-im.org/) configuration files to Nix.

## Usage

```sh
fcitx-ini2nix
```

Prints the current user's Fcitx5 configuration to stdout as a nix attribute set,
ready to be assigned to `i18n.inputMethod.fcitx5.settings`.
