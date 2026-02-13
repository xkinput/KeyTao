# NixOS Flake 配置示例

这是一个完整的示例，展示如何在你的 NixOS 系统中集成星空键道6。

## 示例文件结构

```
/etc/nixos/  或  ~/nix-config/
├── flake.nix
├── configuration.nix
└── home.nix
```

## flake.nix

```nix
{
  description = "My NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # 添加星空键道6
    rime-keytao = {
      url = "github:xkinput/KeyTao";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, rime-keytao, ... }@inputs: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.your-username = import ./home.nix;
          
          # 传递 inputs 给 home-manager
          home-manager.extraSpecialArgs = { inherit inputs; };
        }
      ];
    };
  };
}
```

## configuration.nix

```nix
{ config, pkgs, ... }:

{
  # ... 其他配置 ...

  # 启用 fcitx5 输入法
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;  # 如果使用 Wayland
      addons = with pkgs; [
        fcitx5-rime
        fcitx5-chinese-addons
        fcitx5-gtk
        fcitx5-configtool
      ];
    };
  };

  # ... 其他配置 ...
}
```

## home.nix

```nix
{ config, pkgs, inputs, ... }:

{
  # 导入星空键道6的 Home Manager 模块
  imports = [
    inputs.rime-keytao.homeManagerModules.default
  ];

  # ... 其他配置 ...

  # 启用星空键道6
  programs.rime-keytao = {
    enable = true;
    
    # 根据你使用的 Rime 前端选择数据目录
    rimeDataDir = ".local/share/fcitx5/rime";  # fcitx5-rime（默认）
    # rimeDataDir = ".config/ibus/rime";       # ibus-rime
  };

  # ... 其他配置 ...
}
```

## 应用配置

```bash
# 构建并切换到新配置
sudo nixos-rebuild switch --flake .#your-hostname

# 重新部署 Rime
fcitx5-remote -r  # fcitx5
# 或
ibus-daemon -drx  # ibus
```

## 完整示例（单文件版）

如果你不想分离配置，这里是一个单文件版本的 `flake.nix`：

```nix
{
  description = "My NixOS Configuration with Rime XKJD";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    rime-keytao.url = "github:xkinput/KeyTao";
    rime-keytao.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, rime-keytao, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        
        {
          # 系统配置
          i18n.inputMethod = {
            enable = true;
            type = "fcitx5";
            fcitx5.addons = with pkgs; [ fcitx5-rime fcitx5-chinese-addons ];
          };
          
          users.users.user = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
          };
        }
        
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.user = {
            imports = [ rime-keytao.homeManagerModules.default ];
            
            programs.rime-keytao.enable = true;
            
            home.stateVersion = "24.05";
          };
        }
      ];
    };
  };
}
```

## 高级配置：覆盖默认配置

如果你想自定义键道配置，可以使用 `home.file` 覆盖特定文件：

```nix
{
  programs.rime-keytao.enable = true;

  # 自定义 default.custom.yaml
  home.file.".local/share/fcitx5/rime/default.custom.yaml" = {
    text = ''
      patch:
        schema_list:
          - schema: xkjd6
          - schema: xkjd6dz
        
        menu:
          page_size: 9
    '';
    force = true;  # 覆盖链接的文件
  };
}
```

## 只使用包不使用模块

如果你想完全手动管理配置：

```nix
{
  home.packages = with pkgs; [
    # 其他包...
  ];

  # 手动安装脚本
  home.activation.installRimeXKJD = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.rsync}/bin/rsync -av --delete \
      ${inputs.rime-keytao.packages.${pkgs.system}.default}/share/rime-data/ \
      $HOME/.local/share/fcitx5/rime/
  '';
}
```
