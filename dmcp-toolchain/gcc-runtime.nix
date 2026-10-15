{
  source,
  stdenv,
}:

assert stdenv.cc.libc != null;

let
  commonAttrs = {
    inherit (source) version;
    meta = {
      inherit (source.meta) homepage license;
      platforms = [ "arm-none" ];
    };
    src = "${source}/src/gcc.tar.bz2";
    strictDeps = true;
    enableParallelBuilding = true;
    dontDisableStatic = true;
    dontStrip = true;
    dontPatchELF = true;
    configureFlags = [
      "--disable-multilib"
      "--disable-nls"
      "--disable-shared"
      "--disable-tls"
      "--with-newlib"
    ];
    makeFlags = [ "MAKEINFO=true" ];
  };

  libgcc = stdenv.mkDerivation (
    commonAttrs
    // {
      pname = "dmcp-libgcc";
      meta = commonAttrs.meta // {
        description = "GCC low-level runtime library for DMCP applications";
      };
      preConfigure = ''
        mkdir -p build/libgcc
        cp -r ${stdenv.cc.cc.buildSupport}/gcc build/gcc
        chmod -R u+w build/gcc
        cd build/libgcc
        configureScript=../../libgcc/configure
      '';
      configureFlags = commonAttrs.configureFlags ++ [
        # The official startup code omits TM clone registration.
        "--disable-tm-clone-registry"
      ];
      env = {
        CFLAGS = "-g -O2";
      };
      makeFlags = commonAttrs.makeFlags ++ [ "gcc_objdir=../gcc" ];
    }
  );

  libstdcxxStdenv = stdenv.overrideRuntime { inherit libgcc; };

  libstdcxx = libstdcxxStdenv.mkDerivation (
    commonAttrs
    // {
      pname = "dmcp-libstdcxx";
      meta = commonAttrs.meta // {
        description = "GNU C++ standard library for DMCP applications";
      };
      preConfigure = ''
        mkdir build
        cd build
        configureScript=../libstdc++-v3/configure
      '';
      configureFlags = commonAttrs.configureFlags ++ [
        "--disable-libstdcxx-pch"
        "--with-cross-host=${libstdcxxStdenv.buildPlatform.config}"
        "--with-target-subdir=arm-none-eabi"
        "--with-gxx-include-dir=${placeholder "out"}/arm-none-eabi/include/c++/${source.gccVersion}"
      ];
      env = {
        CFLAGS = "-g -O2";
        CXXFLAGS = "-g -O2";
      };
    }
  );
in
{
  inherit libgcc libstdcxx;
}
