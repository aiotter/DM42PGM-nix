{
  callPackage,
  overrideCC,
  pkgsCross,
}:

let
  gcc = callPackage ./gcc.nix { };
in
{
  inherit gcc;
  stdenv = (overrideCC pkgsCross.arm-embedded.stdenvNoCC gcc).override {
    name = "dmcp-stdenv";
  };
}
