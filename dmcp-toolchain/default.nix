{
  lib,
  callPackage,
  pkgsCross,
  stdenvAdapters,
}:

let
  source = callPackage ./source.nix { };

  stdenv = import ./stdenv.nix {
    gcc = callPackage ./gcc.nix { inherit source; };
    inherit
      lib
      pkgsCross
      source
      stdenvAdapters
      ;
  };

  runtime = callPackage ./runtime.nix {
    inherit source stdenv;
  };

  finalStdenv = stdenv.overrideRuntime {
    inherit (runtime) newlib libgcc libstdcxx;
  };

in
{
  gcc = finalStdenv.cc.overrideAttrs (oldAttrs: {
    pname = "dmcp-toolchain";
    inherit (source) version;
    passthru = oldAttrs.passthru // {
      inherit (runtime) newlib libgcc libstdcxx;
      newlibNano = runtime.newlib.nano;
    };
    meta = oldAttrs.meta // {
      inherit (source.meta) homepage license;
      description = "GNU Arm Embedded toolchain for DMCP and DMCP5 applications";
      platforms = lib.systems.flakeExposed;
    };
  });
  stdenv = finalStdenv.override {
    name = "dmcp-stdenv";
  };
}
