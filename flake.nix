{
  description = "Bun - A fast all-in-one JavaScript runtime, bundler, transpiler and package manager";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;

      version = "1.4.2";

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = lib.genAttrs supportedSystems;

      sources = {
        "aarch64-darwin" = {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-darwin-aarch64.zip";
          hash = "sha256-kJh6OhbX21VtiGrD1VHnttPt8KHPQ6yu1iLoZ2vh0S8=";
          sourceRoot = "bun-darwin-aarch64";
        };
        "aarch64-linux" = {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-aarch64.zip";
          hash = "sha256-VDKLvC2cjgyfiSxUTWbFeoO4QTnjSQnl7oF1jxrI/ac=";
          sourceRoot = null;
        };
        "x86_64-linux" = {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64.zip";
          hash = "sha256-NjaPrvdSeHXV/6UuU81IAhdB8qg+tiCKjdZAaNQiqRM=";
          sourceRoot = null;
        };
      };

      mkBun =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          src = sources.${system};
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "bun";
          inherit version;

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
          ++ lib.optionals pkgs.stdenvNoCC.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];

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
            lib.optionalString pkgs.stdenvNoCC.hostPlatform.isDarwin ''
              '${lib.getExe' pkgs.cctools "${pkgs.cctools.targetPrefix}install_name_tool"}' $out/bin/bun \
                -change /usr/lib/libicucore.A.dylib '${lib.getLib pkgs.darwin.ICU}/lib/libicucore.A.dylib'
              '${lib.getExe pkgs.rcodesign}' sign --code-signature-flags linker-signed $out/bin/bun
            ''
            + lib.optionalString (pkgs.stdenvNoCC.buildPlatform.canExecute pkgs.stdenvNoCC.hostPlatform) ''
              installShellCompletion --cmd bun \
                --bash <(SHELL="bash" $out/bin/bun completions) \
                --zsh <(SHELL="zsh" $out/bin/bun completions) \
                --fish <(SHELL="fish" $out/bin/bun completions)
            '';

          meta = {
            homepage = "https://bun.sh";
            changelog = "https://bun.sh/blog/bun-v${version}";
            description = "Incredibly fast JavaScript runtime, bundler, transpiler and package manager – all in one";
            sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
            license = with lib.licenses; [
              mit
              lgpl21Only
            ];
            mainProgram = "bun";
            platforms = builtins.attrNames sources;
            broken = pkgs.stdenvNoCC.hostPlatform.isMusl;
          };
        };

      mkDevShell =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          llvm = pkgs.llvm_21;
          clang = pkgs.clang_21;
          lld = pkgs.lld_21;
          nodejs = pkgs.nodejs_26;
          devPkgs = [
            pkgs.cmake
            pkgs.ninja
            pkgs.nasm
            pkgs.pkg-config
            pkgs.ccache
            clang
            llvm
            lld
            pkgs.llvmPackages_21.clang-tools
            (pkgs.writeShellScriptBin "clang-format-21" ''
              exec ${pkgs.llvmPackages_21.clang-tools}/bin/clang-format-unwrapped "$@"
            '')
            pkgs.gcc
            pkgs.rustup
            pkgs.go
            (mkBun system)
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
          ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.apple-sdk ];
        in
        (pkgs.mkShell.override { stdenv = pkgs.clangStdenv; }) {
          packages = devPkgs;
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
          ''
          + ''

            echo "====================================="
            echo "Bun Development Environment"
            echo "====================================="
            echo "Bun:    $(bun --version 2>/dev/null || echo 'not found')"
            echo "Node:   $(node --version 2>/dev/null || echo 'not found')"
            echo "Clang:  $(clang --version 2>/dev/null | head -n1 || echo 'not found')"
            echo "CMake:  $(cmake --version 2>/dev/null | head -n1 || echo 'not found')"
            echo "LLVM:   ${llvm.version}"
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
    {
      # nix build, nix run, nix shell, nix profile install
      packages = forAllSystems (system: {
        bun = mkBun system;
        default = mkBun system;
      });

      # nix develop — source build environment
      # nix develop .#minimal — prebuilt binary only
      devShells = forAllSystems (system: {
        default = mkDevShell system;
        minimal = (import nixpkgs { inherit system; }).mkShell {
          packages = [ (mkBun system) ];
        };
      });

      # Composable overlay for downstream flakes
      overlays.default = final: _prev: {
        bun = mkBun final.stdenv.hostPlatform.system;
      };

      # NixOS module: programs.bun.enable
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.bun;
        in
        {
          options.programs.bun = {
            enable = lib.mkEnableOption "Bun JavaScript runtime";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.bun;
              defaultText = lib.literalExpression "bun.packages.\${system}.bun";
              description = "The bun package to use.";
            };
          };
          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };

      # Home Manager module: programs.bun.enable, programs.bun.settings
      homeManagerModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.bun;
          tomlFormat = pkgs.formats.toml { };
        in
        {
          options.programs.bun = {
            enable = lib.mkEnableOption "Bun JavaScript runtime";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.bun;
              defaultText = lib.literalExpression "bun.packages.\${system}.bun";
              description = "The bun package to use.";
            };
            settings = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
              example = lib.literalExpression ''
                {
                  install.optional = false;
                  telemetry = false;
                }
              '';
              description = "Configuration written to $XDG_CONFIG_HOME/bunfig.toml.";
            };
          };
          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];
            xdg.configFile."bunfig.toml" = lib.mkIf (cfg.settings != { }) {
              source = tomlFormat.generate "bunfig.toml" cfg.settings;
            };
          };
        };

      # nix-darwin module: programs.bun.enable
      darwinModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.bun;
        in
        {
          options.programs.bun = {
            enable = lib.mkEnableOption "Bun JavaScript runtime";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.bun;
              defaultText = lib.literalExpression "bun.packages.\${system}.bun";
              description = "The bun package to use.";
            };
          };
          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };

      # nix flake init -t github:usrbinkat/bun
      templates.default = {
        path = ./templates/default;
        description = "Bun project with flake.nix consuming the bun overlay";
        welcomeText = ''
          # Bun Project

          Run `nix develop` to enter the development shell with bun ${version}.
          Run `bun install` to install dependencies.
        '';
      };

      # nix flake check
      checks = forAllSystems (system: {
        bun-build = mkBun system;
        bun-version =
          let
            pkgs = import nixpkgs { inherit system; };
            bun = mkBun system;
          in
          pkgs.runCommand "check-bun-version" { nativeBuildInputs = [ bun ]; } ''
            ACTUAL=$(bun --version)
            EXPECTED="${version}"
            if [ "$ACTUAL" != "$EXPECTED" ]; then
              echo "version mismatch: got $ACTUAL, expected $EXPECTED" >&2
              exit 1
            fi
            touch $out
          '';
      });

      # nix fmt
      formatter = forAllSystems (system: (import nixpkgs { inherit system; }).nixfmt-tree);
    };
}
