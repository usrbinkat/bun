{
  description = "Bun - A fast all-in-one JavaScript runtime, bundler, transpiler and package manager";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:usrbinkat/nixpkgs/gssproxy-package-and-module";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      # Bun release version — single source of truth
      bunVersion = "1.4.2";

      # Per-platform binary release URLs and SRI hashes
      sources = {
        "aarch64-darwin" = {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/bun-darwin-aarch64.zip";
          hash = "sha256-kJh6OhbX21VtiGrD1VHnttPt8KHPQ6yu1iLoZ2vh0S8=";
          sourceRoot = "bun-darwin-aarch64";
        };
        "x86_64-darwin" = {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/bun-darwin-x64-baseline.zip";
          hash = "sha256-utW71s8U0JgNEV9ZVMn/kE32GdXplNLaH/zNPzFjALA=";
          sourceRoot = "bun-darwin-x64-baseline";
        };
        "aarch64-linux" = {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/bun-linux-aarch64.zip";
          hash = "sha256-VDKLvC2cjgyfiSxUTWbFeoO4QTnjSQnl7oF1jxrI/ac=";
          sourceRoot = null;
        };
        "x86_64-linux" = {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/bun-linux-x64.zip";
          hash = "sha256-NjaPrvdSeHXV/6UuU81IAhdB8qg+tiCKjdZAaNQiqRM=";
          sourceRoot = null;
        };
      };

      supportedSystems = builtins.attrNames sources;

      # Build the prebuilt bun binary package for a given pkgs
      mkBunPackage =
        pkgs:
        let
          inherit (pkgs) lib stdenvNoCC;
          platform = stdenvNoCC.hostPlatform.system;
          src = sources.${platform} or (throw "Unsupported system: ${platform}");
        in
        stdenvNoCC.mkDerivation {
          pname = "bun";
          version = bunVersion;

          src = pkgs.fetchurl {
            inherit (src) url hash;
          };

          sourceRoot = src.sourceRoot;

          strictDeps = true;

          nativeBuildInputs = [
            pkgs.unzip
            pkgs.installShellFiles
            pkgs.makeWrapper
          ]
          ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];

          buildInputs = [ pkgs.openssl ];

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            install -Dm 755 ./bun $out/bin/bun
            ln -s $out/bin/bun $out/bin/bunx
            runHook postInstall
          '';

          postPhases = [ "postPatchelf" ];
          postPatchelf =
            lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
              '${lib.getExe' pkgs.cctools "${pkgs.cctools.targetPrefix}install_name_tool"}' $out/bin/bun \
                -change /usr/lib/libicucore.A.dylib '${lib.getLib pkgs.darwin.ICU}/lib/libicucore.A.dylib'
              '${lib.getExe pkgs.rcodesign}' sign --code-signature-flags linker-signed $out/bin/bun
            ''
            +
              lib.optionalString
                (
                  stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform
                  && !(stdenvNoCC.hostPlatform.isDarwin && stdenvNoCC.hostPlatform.isx86_64)
                )
                ''
                  installShellCompletion --cmd bun \
                    --bash <(SHELL="bash" $out/bin/bun completions) \
                    --zsh <(SHELL="zsh" $out/bin/bun completions) \
                    --fish <(SHELL="fish" $out/bin/bun completions)
                '';

          meta = {
            homepage = "https://bun.sh";
            changelog = "https://bun.sh/blog/bun-v${bunVersion}";
            description = "Incredibly fast JavaScript runtime, bundler, transpiler and package manager – all in one";
            sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
            longDescription = ''
              All in one fast & easy-to-use tool. Instead of 1,000 node_modules for development, you only need bun.
            '';
            license = with lib.licenses; [
              mit
              lgpl21Only
            ];
            mainProgram = "bun";
            platforms = supportedSystems;
            broken = stdenvNoCC.hostPlatform.isMusl;
          };
        };

      # LLVM/Clang toolchain for building bun from source
      mkDevShell =
        pkgs:
        let
          inherit (pkgs) lib;
          llvm = pkgs.llvm_21;
          clang = pkgs.clang_21;
          lld = pkgs.lld_21;
          nodejs = pkgs.nodejs_26;

          devPackages = [
            pkgs.cmake
            pkgs.ninja
            pkgs.pkg-config
            pkgs.ccache
            clang
            llvm
            lld
            pkgs.gcc
            pkgs.rustc
            pkgs.cargo
            pkgs.go
            pkgs.bun
            nodejs
            pkgs.python3
            pkgs.libtool
            pkgs.ruby
            pkgs.perl
            pkgs.openssl
            pkgs.zlib
            pkgs.libxml2
            pkgs.libiconv
            pkgs.git
            pkgs.curl
            pkgs.wget
            pkgs.unzip
            pkgs.xz
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            pkgs.gdb
            pkgs.libx11
            pkgs.libxcb
            pkgs.libxcomposite
            pkgs.libxcursor
            pkgs.libxdamage
            pkgs.libxext
            pkgs.libxfixes
            pkgs.libxi
            pkgs.libxrandr
            pkgs.libxrender
            pkgs.libxscrnsaver
            pkgs.libxtst
            pkgs.libxkbcommon
            pkgs.mesa
            pkgs.nspr
            pkgs.nss
            pkgs.cups
            pkgs.dbus
            pkgs.expat
            pkgs.fontconfig
            pkgs.freetype
            pkgs.glib
            pkgs.gtk3
            pkgs.pango
            pkgs.cairo
            pkgs.alsa-lib
            pkgs.at-spi2-atk
            pkgs.at-spi2-core
            pkgs.libgbm
            pkgs.liberation_ttf
            pkgs.atk
            pkgs.libdrm
            pkgs.libxshmfence
            pkgs.gdk-pixbuf
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
            (pkgs.darwinMinVersionHook "11.0")
          ];
        in
        (pkgs.mkShell.override { stdenv = pkgs.clangStdenv; }) {
          packages = devPackages;
          hardeningDisable = [ "fortify" ];

          shellHook = ''
            export CC="${lib.getExe clang}"
            export CXX="${lib.getExe' clang "clang++"}"
            export AR="${llvm}/bin/llvm-ar"
            export RANLIB="${llvm}/bin/llvm-ranlib"
            export CMAKE_C_COMPILER="$CC"
            export CMAKE_CXX_COMPILER="$CXX"
            export CMAKE_AR="$AR"
            export CMAKE_RANLIB="$RANLIB"
            export CMAKE_SYSTEM_PROCESSOR="$(uname -m)"
            export TMPDIR="''${TMPDIR:-/tmp}"
          ''
          + lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            export LD="${lib.getExe' lld "ld.lld"}"
            export NIX_CFLAGS_LINK="''${NIX_CFLAGS_LINK:+$NIX_CFLAGS_LINK }-fuse-ld=lld"
            export LD_LIBRARY_PATH="${lib.makeLibraryPath devPackages}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          ''
          + ''
            echo "====================================="
            echo "Bun Development Environment"
            echo "====================================="
            echo "Bun:   $(bun --version 2>/dev/null || echo 'not found')"
            echo "Node:  $(node --version 2>/dev/null || echo 'not found')"
            echo "Clang: $(clang --version 2>/dev/null | head -n1 || echo 'not found')"
            echo "CMake: $(cmake --version 2>/dev/null | head -n1 || echo 'not found')"
            echo "LLVM:  ${llvm.version}"
            echo ""
            echo "Quick start:"
            echo "  bun bd                    # Build debug binary"
            echo "  bun bd test <test-file>   # Run tests"
            echo "====================================="
          '';

          CMAKE_BUILD_TYPE = "Debug";
          ENABLE_CCACHE = "1";
        };
    in

    # Per-system outputs
    flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        bunPkg = mkBunPackage pkgs;
      in
      {
        # nix build github:usrbinkat/bun
        packages = {
          default = bunPkg;
          bun = bunPkg;
        };

        # nix develop github:usrbinkat/bun
        devShells.default = mkDevShell pkgs;

        # nix flake check
        checks.bun-version =
          pkgs.runCommand "bun-version-check"
            {
              nativeBuildInputs = [ bunPkg ];
              meta.timeout = 30;
            }
            ''
              out_version="$(bun --version)"
              expected="${bunVersion}"
              if [ "$out_version" != "$expected" ]; then
                echo "Version mismatch: got $out_version, expected $expected" >&2
                exit 1
              fi
              touch $out
            '';
      }
    )

    # Cross-system outputs
    // {
      # nix flake init -t github:usrbinkat/bun
      templates = {
        default = {
          path = ./templates/default;
          description = "Bun project with nix flake";
          welcomeText = ''
            # Bun Project
            Run `nix develop` or `direnv allow` to enter the development shell.
          '';
        };
      };

      # Composable overlay: pkgs.bun = prebuilt binary
      # Usage: overlays = [ bun.overlays.default ];
      overlays.default = final: _prev: {
        bun = mkBunPackage final;
      };
    };
}
