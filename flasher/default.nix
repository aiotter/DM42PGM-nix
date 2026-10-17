{
  lib,
  writers,
  python3Packages,
}:

let
  pydfuutil = python3Packages.callPackage ./pydfuutil.nix { };
in
writers.writePython3Bin "dm42-flasher" {
  libraries = [
    python3Packages.pyusb
    python3Packages.tqdm
    pydfuutil
  ];
} (lib.removePrefix "#!/usr/bin/env python3\n" (builtins.readFile ./flash.py))
