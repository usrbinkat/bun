# Simple shell.nix for users without flakes enabled
# For reproducible builds with locked dependencies, use: nix develop
# This uses unpinned <nixpkgs> for simplicity; flake.nix provides version pinning via flake.lock
{
  pkgs ? import <nixpkgs> { },
}:

let
  toolchain = import ./nix/llvm.nix { inherit pkgs; };
in
pkgs.mkShell rec {
  packages =
    with pkgs;
    [
      # Core build tools (matching bootstrap.sh)
      cmake
      ninja
      nasm
      toolchain.clang
      toolchain.llvm
      toolchain.lld
      toolchain.clang-tools
      (writeShellScriptBin "clang-format-21" ''
        exec ${toolchain.clang-tools}/bin/clang-format-unwrapped "$@"
      '')
      nodejs_26
      bun
      rustup
      go
      python3
      ccache
      pkg-config
      gnumake
      libtool
      ruby
      perl

      # Libraries
      openssl
      zlib
      libxml2

      # Development tools
      git
      curl
      wget
      unzip
      xz

      # Linux-specific: gdb and Chromium deps for testing
    ]
    ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      gdb
      # Chromium dependencies for Puppeteer tests
      libx11
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxscrnsaver
      libxtst
      libxkbcommon
      mesa
      nspr
      nss
      cups
      dbus
      expat
      fontconfig
      freetype
      glib
      gtk3
      pango
      cairo
      alsa-lib
      at-spi2-atk
      at-spi2-core
      libgbm
      liberation_ttf
      atk
      libdrm
      libxshmfence
      gdk-pixbuf
    ];

  shellHook = ''
    export CC="${pkgs.lib.getExe toolchain.clang}"
    export CXX="${pkgs.lib.getExe' toolchain.clang "clang++"}"
    export AR="${toolchain.llvm}/bin/llvm-ar"
    export RANLIB="${toolchain.llvm}/bin/llvm-ranlib"
    export CMAKE_C_COMPILER="$CC"
    export CMAKE_CXX_COMPILER="$CXX"
    export CMAKE_AR="$AR"
    export CMAKE_RANLIB="$RANLIB"
    export CMAKE_SYSTEM_PROCESSOR=$(uname -m)
    export TMPDIR=''${TMPDIR:-/tmp}
  ''
  + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
    export LD="${pkgs.lib.getExe' toolchain.lld "ld.lld"}"
    export NIX_CFLAGS_LINK="''${NIX_CFLAGS_LINK:+$NIX_CFLAGS_LINK }-fuse-ld=lld"
  ''
  + ''

    echo "====================================="
    echo "Bun Development Environment (Nix)"
    echo "====================================="
    echo "To build: bun bd"
    echo "To test:  bun bd test <test-file>"
    echo "====================================="
  '';
}
