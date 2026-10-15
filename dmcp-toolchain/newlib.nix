{
  buildPackages,
  stdenv,
  source,
  symlinkJoin,
}:

let
  newlib-standard = stdenv.mkDerivation {
    pname = "dmcp-newlib";
    inherit (source) version;
    src = "${source}/src/newlib.tar.bz2";
    depsBuildBuild = [ buildPackages.stdenv.cc ];
    strictDeps = true;
    enableParallelBuilding = true;
    # Newlib's install rules rely on directory creation order.
    enableParallelInstalling = false;
    dontDisableStatic = true;
    dontStrip = true;
    dontPatchELF = true;
    preConfigure = ''
      export CC_FOR_TARGET="$CC"
      export CC="$CC_FOR_BUILD"
      mkdir build
      cd build
      configureScript=../configure
    '';
    # Newlib's top-level host describes build tools; target describes the library.
    configurePlatforms = [
      "build"
      "target"
    ];
    configureFlags = [
      "--disable-multilib"
      "--disable-nls"
      "--disable-newlib-supplied-syscalls"
      "--enable-newlib-retargetable-locking"
      "--enable-newlib-io-long-long"
      "--enable-newlib-io-c99-formats"
      "--enable-newlib-register-fini"
    ];
    env.CFLAGS_FOR_TARGET = "-g -O2 -ffunction-sections -fdata-sections";
    makeFlags = [ "MAKEINFO=true" ];
    buildFlags = [
      "all-target-newlib"
      "all-target-libgloss"
    ];
    installTargets = [
      "install-target-newlib"
      "install-target-libgloss"
    ];
    passthru = {
      incdir = "/arm-none-eabi/include";
      libdir = "/arm-none-eabi/lib";
    };
    meta = {
      inherit (source.meta) homepage license;
      description = "Standard Newlib and libgloss used to build GCC runtime libraries";
      platforms = [ "arm-none" ];
    };
  };

  newlib-nano = newlib-standard.overrideAttrs (oldAttrs: {
    pname = "dmcp-newlib-nano";
    configureFlags = [
      "--disable-multilib"
      "--disable-nls"
      "--disable-newlib-supplied-syscalls"
      "--enable-newlib-retargetable-locking"
      "--enable-newlib-reent-small"
      "--disable-newlib-fvwrite-in-streamio"
      "--disable-newlib-fseek-optimization"
      "--disable-newlib-wide-orient"
      "--enable-newlib-nano-malloc"
      "--disable-newlib-unbuf-stream-opt"
      "--enable-lite-exit"
      "--enable-newlib-global-atexit"
      "--enable-newlib-nano-formatted-io"
    ];
    env = oldAttrs.env // {
      CFLAGS_FOR_TARGET = "-g -Os -ffunction-sections -fdata-sections";
    };
    meta = oldAttrs.meta // {
      description = "Reduced-footprint Newlib and libgloss for applications running on DM42 and DM42n calculators";
    };
  });
in

symlinkJoin {
  name = "dmcp-newlib-${source.version}";
  paths = [ newlib-standard ];
  postBuild = ''
    nanoPrefix="${newlib-nano}/arm-none-eabi"
    mkdir -p "$out/arm-none-eabi/include/newlib-nano"
    ln -s "$nanoPrefix/include/newlib.h" "$out/arm-none-eabi/include/newlib-nano/newlib.h"
    for library in "$nanoPrefix/lib/"*.a; do
      name=$(basename "$library" .a)
      ln -s "$library" "$out/arm-none-eabi/lib/''${name}_nano.a"
    done
  '';
  passthru = newlib-standard.passthru // {
    standard = newlib-standard;
    nano = newlib-nano;
  };
}
