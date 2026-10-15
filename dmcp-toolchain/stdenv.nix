{
  lib,
  pkgsCross,
  stdenvAdapters,
  source,
  gcc,
}:

let
  mkStdenv =
    {
      newlib ? null,
      libgcc ? null,
      libstdcxx ? null,
    }:

    let
      cross = pkgsCross.arm-embedded;

      bintools = cross.buildPackages.wrapBintoolsWith {
        bintools = gcc;
        libc = newlib;
      };

      cc = cross.buildPackages.wrapCCWith {
        cc = gcc;
        inherit bintools;
        libc = newlib;
        libcxx = libstdcxx;
        extraBuildCommands = ''ln -s arm-none-eabi-gcc "$out/bin/arm-none-eabi-gcc-${source.gccVersion}";'';
        nixSupport = {
          # Preserve GCC's -O2 frame-pointer policy instead of Nix's forced retention.
          cc-cflags-before = "-fomit-frame-pointer";
          # GCC's wrapper assumes target runtimes are bundled with the compiler.
          cc-cflags = lib.concatStringsSep " " (
            lib.optional (newlib != null) "--sysroot=${newlib}/arm-none-eabi"
            ++ lib.optional (libgcc != null) "-B${libgcc}/lib/gcc/arm-none-eabi/${source.gccVersion}/"
            ++ lib.optional (libstdcxx != null) "-B${libstdcxx}/arm-none-eabi/lib/"
          );
        }
        // lib.optionalAttrs (libstdcxx != null) {
          libcxx-cxxflags = lib.concatStringsSep " " [
            "-isystem ${libstdcxx}/arm-none-eabi/include/c++/${source.gccVersion}"
            "-isystem ${libstdcxx}/arm-none-eabi/include/c++/${source.gccVersion}/arm-none-eabi"
            "-isystem ${libstdcxx}/arm-none-eabi/include/c++/${source.gccVersion}/backward"
          ];
          libcxx-ldflags = "-L${libstdcxx}/arm-none-eabi/lib";
        };
      };
    in
    # Preserve the official target build flags without Nix hardening additions.
    stdenvAdapters.addAttrsToDerivation { hardeningDisable = [ "all" ]; } (
      stdenvAdapters.overrideCC cross.stdenvNoCC cc
    );

  mkOverridableStdenv =
    {
      runtimeArgs ? { },
      applyStdenvOverrides ? lib.id,
    }:
    let
      env = mkStdenv runtimeArgs;
    in
    applyStdenvOverrides env
    // {
      /**
        Rebuilds the stdenv with different target runtime libraries.

        Existing stdenv overrides are preserved.

        # Inputs

        `changes` (Attribute set or Function)
        : Runtime arguments to update, or a function receiving the previously
          supplied runtime arguments and returning the updates.

        Supported runtime attributes:

        - `newlib`: The target C library.
        - `libgcc`: The GCC runtime library.
        - `libstdcxx`: The C++ standard library.

        All libraries default to `null`. Unspecified attributes retain their
        previous values; setting an attribute to `null` removes that library.

        # Examples

        ```nix
        stdenv.overrideRuntime { inherit newlib; }
        stdenv.overrideRuntime { libstdcxx = null; }
        stdenv.overrideRuntime (previous: {
          newlib = previous.newlib.standard;
        })
        ```
      */
      overrideRuntime =
        changes:
        mkOverridableStdenv {
          runtimeArgs = runtimeArgs // (lib.toFunction changes runtimeArgs);
          inherit applyStdenvOverrides;
        };
      # Replay stdenv overrides in call order after rebuilding the runtime environment.
      override =
        changes:
        mkOverridableStdenv {
          inherit runtimeArgs;
          applyStdenvOverrides = base: (applyStdenvOverrides base).override changes;
        };
    };
in

mkOverridableStdenv { }
