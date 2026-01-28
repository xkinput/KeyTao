{
  description = "Xingkong Jiandao (星空键道6) - Rime input method schema";

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
        
        packages.rime-xkjd = self.packages.${system}.default;
      }
    ) // {
      # Overlay for easy integration
      overlays.default = final: prev: {
        rime-xkjd = final.callPackage ./default.nix { };
      };

      # Home Manager module
      homeManagerModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.rime-xkjd;
          rime-xkjd-pkg = pkgs.callPackage ./default.nix { };
        in
        {
          options.programs.rime-xkjd = {
            enable = mkEnableOption "Rime Xingkong Jiandao input method schema";

            package = mkOption {
              type = types.package;
              default = rime-xkjd-pkg;
              description = "The rime-xkjd package to use";
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
            home.file = 
              let
                rimeFiles = builtins.readDir "${cfg.package}/share/rime-data";
                mkRimeFileLink = name: value: {
                  name = "${cfg.rimeDataDir}/${name}";
                  value.source = "${cfg.package}/share/rime-data/${name}";
                };
              in
                listToAttrs (
                  mapAttrsToList mkRimeFileLink rimeFiles
                );
          };
        };
    };
}
