# Build DM42/DM42n firmware with Nix

This repository provides a Nix build chain for the DM42/DM42n program using the
official SwissMicros [Free42](https://github.com/swissmicros/free42) and
[DM42PGM](https://github.com/swissmicros/DM42PGM) sources.
The same build chain can also use a custom Free42 fork by overriding the Free42 input.

## Build from the official sources

With Nix and flakes enabled, run:

```sh
nix build github:aiotter/DM42PGM-nix
```

This produces `.pgm` for DM42 and `.pg5` for DM42n in `result/`.
For DM42-3.26, both files were verified to be byte-for-byte identical to the official binaries.

To verify that both firmware files match the official SHA-256 hashes, run:

```sh
nix flake check github:aiotter/DM42PGM-nix
```

## Build with a custom Free42 fork

For example, you can build with my custom Free42 fork:

```sh
nix build github:aiotter/DM42PGM-nix --override-input free42 github:aiotter/dm42-free42
```

This overrides the Free42 input for that build without changing `flake.lock`.

## Install on a DM42/DM42n

1. Mount your calculator (`SETUP` -> `System` -> `Reset to DMCP menu` -> `Activate USB Disk`).
2. Copy `result/DM42-***.pgm` (DM42) or `result/DM42-***.pg5` (DM42n) to the calculator's USB disk.
3. Unmount the USB disk.
4. Choose `Load Program` on the calculator and select the copied file.
