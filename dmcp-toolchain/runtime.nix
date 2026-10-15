{
  callPackage,
  source,
  stdenv,
}:

let
  newlib = callPackage ./newlib.nix {
    inherit source stdenv;
  };

  gccRuntime = callPackage ./gcc-runtime.nix {
    inherit source;
    stdenv = stdenv.overrideRuntime { newlib = newlib.standard; };
  };
in
{
  inherit newlib;
  inherit (gccRuntime) libgcc libstdcxx;
}
