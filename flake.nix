{
  description = "KeyTao (星空键道6) - Rime input method schema";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        librime-with-tools = pkgs.librime.overrideAttrs (old: {
          cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DBUILD_TOOLS=ON" ];
          postInstall = (old.postInstall or "") + ''
            for bin in rime_console rime_api_console; do
              src=$(find "$NIX_BUILD_TOP" -maxdepth 5 -name "$bin" -not -name "*.cc" -type f 2>/dev/null | head -1)
              [ -n "$src" ] || continue
              install -m755 "$src" "$out/bin/$bin"
              # fix rpath: remove sandbox build paths, add real $out/lib
              while IFS= read -r rp; do
                install_name_tool -delete_rpath "$rp" "$out/bin/$bin" 2>/dev/null || true
              done < <(otool -l "$out/bin/$bin" | awk '/LC_RPATH/{f=1} f && /^ *path /{print $2; f=0}')
              install_name_tool -add_rpath "$out/lib" "$out/bin/$bin"
            done
          '';
        });
      in
      {
        packages.default = pkgs.callPackage ./default.nix { };

        packages.rime-keytao = self.packages.${system}.default;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            librime-with-tools # provides rime_deployer, rime_console, rime_api_console, etc.
            lua5_4 # provides luac
            ncurses # required by rime_tui
          ];
          shellHook = ''
            export RIME_SHARED="${pkgs.rime-data}/share/rime-data"

            # compile mem_bench on first entry (or when source changes)
            BENCH_SRC="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")/scripts/mem_bench.cc"
            BENCH_BIN="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")/scripts/mem_bench"
            LIBRIME_STORE="${librime-with-tools}"
            if [ "$BENCH_SRC" -nt "$BENCH_BIN" ] 2>/dev/null || [ ! -x "$BENCH_BIN" ]; then
              echo "[mem_bench] compiling..."
              c++ -std=c++17 -O2 \
                -I"$LIBRIME_STORE/include" \
                "$BENCH_SRC" \
                -L"$LIBRIME_STORE/lib" -lrime \
                -Wl,-rpath,"$LIBRIME_STORE/lib" \
                -o "$BENCH_BIN" \
                && echo "[mem_bench] ready → scripts/mem_bench" \
                || echo "[mem_bench] compile failed (see above)"
            fi

            # compile rime_tui on first entry (or when source changes)
            TUI_SRC="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")/scripts/rime_tui.cc"
            TUI_BIN="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")/scripts/rime_tui"
            if [ "$TUI_SRC" -nt "$TUI_BIN" ] 2>/dev/null || [ ! -x "$TUI_BIN" ]; then
              echo "[rime_tui] compiling..."
              c++ -std=c++17 -O2 \
                -I"$LIBRIME_STORE/include" \
                "$TUI_SRC" \
                -L"$LIBRIME_STORE/lib" -lrime \
                -lncurses \
                -Wl,-rpath,"$LIBRIME_STORE/lib" \
                -o "$TUI_BIN" \
                && echo "[rime_tui] ready → scripts/rime_tui" \
                || echo "[rime_tui] compile failed (see above)"
            fi
          '';
        };
      }
    )
    // {
      # Overlay for easy integration
      overlays.default = final: prev: {
        rime-keytao = final.callPackage ./default.nix { };
      };

      # Home Manager module
      homeManagerModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        let
          cfg = config.programs.rime-keytao;
          rime-keytao-pkg = pkgs.callPackage ./default.nix { };
        in
        {
          options.programs.rime-keytao = {
            enable = mkEnableOption "KeyTao (Rime Xingkong Jiandao) input method schema";

            package = mkOption {
              type = types.package;
              default = rime-keytao-pkg;
              description = "The rime-keytao package to use";
            };

            rimeDataDir = mkOption {
              type = types.str;
              default = if pkgs.stdenv.isDarwin then "Library/Rime" else ".local/share/fcitx5/rime";
              description = ''
                Rime user data directory relative to home.
                Default values:
                - Library/Rime (macOS Squirrel, automatically set)
                - .local/share/fcitx5/rime (Linux fcitx5-rime, automatically set)
                Other common values:
                - .config/ibus/rime (ibus-rime)
              '';
            };
          };

          config = mkIf cfg.enable {
            home.activation.installRimeKeytao = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/${cfg.rimeDataDir}"

              # Sync schema/dict files from Nix store, overwriting stale files.
              # Exclude user-generated data that must never be overwritten.
              $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -av \
                --chmod=D0755,F0644 \
                --exclude='*.userdb/' \
                --exclude='user.yaml' \
                --exclude='installation.yaml' \
                --exclude='sync/' \
                "${cfg.package}/share/rime-data/" \
                "${config.home.homeDirectory}/${cfg.rimeDataDir}/"

              $VERBOSE_ECHO "KeyTao Rime schema files installed to ${cfg.rimeDataDir}"
            '';
          };
        };
    };
}
