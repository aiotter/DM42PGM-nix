{
  lib,
  stdenv,
  fetchzip,
  fetchpatch,
  bison,
  flex,
  m4,
  perl,
  gmp,
  mpfr,
  libmpc,
  zlib,
}:

let
  version = "10.3-2021.10";
  sources = fetchzip {
    name = "gcc-arm-none-eabi-${version}-source";
    url = "https://developer.arm.com/-/media/Files/downloads/gnu-rm/${version}/gcc-arm-none-eabi-${version}-src.tar.bz2";
    hash = "sha256-eaQStkUA7IkFWivHApKrLDq5mUM14hQSuNPa8OKXYiM=";
  };
  commonConfigureFlags = [
    "--build=${stdenv.buildPlatform.config}"
    "--host=${stdenv.hostPlatform.config}"
    "--target=arm-none-eabi"
    "--enable-languages=c,c++"
    # Both calculators use this CPU/ABI.
    "--with-arch=armv7e-m"
    "--with-mode=thumb"
    "--with-fpu=fpv4-sp-d16"
    "--with-float=hard"
    "--disable-libstdcxx-pch"
    "--disable-nls"
    "--disable-shared"
    "--disable-tls"
    "--disable-werror"
    "--with-newlib"
    "--with-native-system-header-dir=/include"
    "--with-system-zlib"
    "--with-sysroot=${builtins.placeholder "out"}/arm-none-eabi"
    # The official startup code omits TM clone registration.
    "--disable-tm-clone-registry"
    "--disable-multilib"
    "--disable-newlib-supplied-syscalls"
    "--enable-newlib-retargetable-locking"
  ];
in
stdenv.mkDerivation {
  pname = "dmcp-toolchain";
  inherit version;
  srcs = map (component: "${sources}/src/${component}.tar.bz2") [
    "gcc"
    "binutils"
    "newlib"
  ];
  sourceRoot = "gcc";

  nativeBuildInputs = [
    bison
    flex
    m4
    perl
  ];
  buildInputs = [
    gmp
    mpfr
    libmpc
    zlib
  ];
  strictDeps = true;
  # GCC 10 passes translated diagnostic strings to its own printf-like callbacks.
  hardeningDisable = [ "format" ];
  enableParallelBuilding = true;
  # Newlib's install rules rely on directory creation order.
  enableParallelInstalling = false;
  dontDisableStatic = true;
  dontStrip = true;
  dontPatchELF = true;

  env = {
    CFLAGS = "-O2 -std=gnu11";
    CXXFLAGS = "-O2 -std=gnu++11";
    M4 = lib.getExe m4;
  };

  postUnpack = ''
    cp -r binutils/{bfd,binutils,gas,ld,opcodes,libctf,etc} "$sourceRoot/"
    # Binutils needs matching libiberty declarations and implementations.
    cp -r binutils/include/. "$sourceRoot/include/"
    rm -r "$sourceRoot/libiberty"
    cp -r binutils/libiberty "$sourceRoot/"
    cp -rn binutils/config/. "$sourceRoot/config/"
    cp -n binutils/{test-driver,ylwrap} "$sourceRoot/"
    cp -r newlib/{newlib,libgloss} "$sourceRoot/"
  '';
  patches = [
    ./libcxx-headers.patch
  ]
  ++ lib.optionals (stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64) [
    (fetchpatch {
      name = "apple-silicon.patch";
      url = "https://raw.githubusercontent.com/xpack-dev-tools/arm-none-eabi-gcc-xpack/e39be910534fe4946d93622dbc86c7bb7a7bbe73/patches/gcc-10.3.1-apple-silicon.patch.diff";
      hash = "sha256-Zt0KGC1NMKjd8HA9lzi6NdMkkFH3Eet7nTXvjnj7bFw=";
    })
  ];

  preFixupPhases = [
    "prepareNanoPhase"
    "configurePhase"
    "buildPhase"
    "installPhase"
  ];

  preConfigure = ''
    mkdir build
    cd build
    configureScript=../configure
  '';
  configureFlags = commonConfigureFlags ++ [
    "--enable-newlib-io-long-long"
    "--enable-newlib-io-c99-formats"
    "--enable-newlib-register-fini"
  ];

  postConfigure = ''
    # Split Newlib into sections without changing libgcc's startup objects.
    cat >> Makefile <<'EOF'
    configure-target-newlib all-target-newlib configure-target-libgloss all-target-libgloss: private CFLAGS_FOR_TARGET = -g -O2 -ffunction-sections -fdata-sections
    EOF
  '';
  makeFlags = [
    "MAKEINFO=true"
    "M4=${lib.getExe m4}"
  ];
  buildFlags = [
    "all-binutils"
    "all-gas"
    "all-ld"
    "all-gcc"
    "all-target-newlib"
    "all-target-libgloss"
    "all-target-libgcc"
    "all-target-libstdc++-v3"
  ];
  installTargets = [
    "install-binutils"
    "install-gas"
    "install-ld"
    "install-gcc"
    "install-target-newlib"
    "install-target-libgloss"
    "install-target-libgcc"
    "install-target-libstdc++-v3"
  ];

  prepareNanoPhase = ''
    runHook prePrepareNano
    # Remove only Newlib and libgloss configuration and build products.
    make -j1 MAKEINFO=true distclean-target-libgloss distclean-target-newlib

    # Keep other modules' Makefiles so their configure/build steps stay cached.
    configureFlags=(
      --no-recursion
      ${lib.escapeShellArgs commonConfigureFlags}
      --enable-newlib-reent-small --disable-newlib-fvwrite-in-streamio
      --disable-newlib-fseek-optimization --disable-newlib-wide-orient
      --enable-newlib-nano-malloc --disable-newlib-unbuf-stream-opt
      --enable-lite-exit --enable-newlib-global-atexit
      --enable-newlib-nano-formatted-io
    )
    export CFLAGS_FOR_TARGET="-g -Os -ffunction-sections -fdata-sections"
    buildFlags=(all-target-newlib all-target-libgloss)
    installTargets=(install-target-newlib install-target-libgloss)
    prefix="$NIX_BUILD_TOP/newlib-nano-install"
    preConfigure=
    postConfigure=
    postInstall=${lib.escapeShellArg ''
      nanoPrefix="$prefix/arm-none-eabi"
      mkdir -p "$out/arm-none-eabi/include/newlib-nano"
      cp "$nanoPrefix/include/newlib.h" "$out/arm-none-eabi/include/newlib-nano/"
      for library in "$nanoPrefix/lib/"*.a; do
        name=$(basename "$library" .a)
        cp "$library" "$out/arm-none-eabi/lib/''${name}_nano.a"
      done
      prefix="$out"
    ''}
    runHook postPrepareNano
  '';

  meta = {
    description = "GNU Arm Embedded GCC 10.3 for DMCP and DMCP5 applications";
    homepage = "https://developer.arm.com/downloads/-/gnu-rm";
    license = with lib.licenses; [
      gpl3Plus
      lgpl3Plus
      bsd2
    ];
    platforms = lib.systems.flakeExposed;
  };
}
