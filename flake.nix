{
  description = "KeyTao (星空键道6) - Rime input method schema";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.callPackage ./default.nix { };
        
        packages.rime-keytao = self.packages.${system}.default;
      }
    ) // {
      # Overlay for easy integration
      overlays.default = final: prev: {
        rime-keytao = final.callPackage ./default.nix { };
      };

      # Home Manager module
      homeManagerModules.default = { config, lib, pkgs, ... }:
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
              default = ".local/share/fcitx5/rime";
              description = ''
                Rime user data directory relative to home.
                Common values:
                - .local/share/fcitx5/rime (fcitx5-rime)
                - .config/ibus/rime (ibus-rime)
                - Library/Rime (macOS Squirrel)
              '';
            };
          };

          config = mkIf cfg.enable {
            # Use activation script instead of home.file to handle existing directories
            home.activation.installRimeKeytao = lib.hm.dag.entryAfter ["writeBoundary"] ''
              $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/${cfg.rimeDataDir}"
              
              # Use rsync to sync files, preserving existing user data
              $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -av --ignore-existing \
                "${cfg.package}/share/rime-data/" \
                "${config.home.homeDirectory}/${cfg.rimeDataDir}/"
              
              $VERBOSE_ECHO "KeyTao Rime schema files installed to ${cfg.rimeDataDir}"
            '';
          };
        };
    };
}
