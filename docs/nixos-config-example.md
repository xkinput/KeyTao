# Nix Flake 配置示例

这是一个完整的示例，展示如何在你的 NixOS 或 macOS 系统中集成星空键道6。

## 前提条件

### macOS 用户必读

**⚠️ 在使用本配置之前，必须先手动安装鼠须管（Squirrel）。**

鼠须管目前尚未在 Nix 中打包，请通过以下方式之一安装：

```bash
# 方式 1: Homebrew
brew install --cask squirrel

# 方式 2: 官方下载
# 访问 https://rime.im/download/#macOS 下载并安装
```

安装后在"系统偏好设置 > 键盘 > 输入法"中添加"鼠须管"。

### Linux 用户

Linux 上的 Rime 前端（fcitx5-rime 或 ibus-rime）可通过 Nix 配置自动安装，详见下方示例。

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
    # Linux 默认: .local/share/fcitx5/rime
    # macOS 默认: Library/Rime（自动设置，无需配置）
    rimeDataDir = ".local/share/fcitx5/rime";  # fcitx5-rime（Linux 默认）
    # rimeDataDir = ".config/ibus/rime";       # ibus-rime
  };

  # ... 其他配置 ...
}
```

## home.nix (macOS)

```nix
{ config, pkgs, inputs, ... }:

{
  # 导入星空键道6的 Home Manager 模块
  imports = [
    inputs.rime-keytao.homeManagerModules.default
  ];

  # ... 其他配置 ...

  # 启用星空键道6（macOS 自动使用 ~/Library/Rime）
  programs.rime-keytao = {
    enable = true;
    # macOS 无需配置 rimeDataDir，自动使用 Library/Rime
  };

  # ... 其他配置 ...
}
```

## 应用配置

### Linux (NixOS)

```bash
# 构建并切换到新配置
sudo nixos-rebuild switch --flake .#your-hostname

# 重新部署 Rime
fcitx5-remote -r  # fcitx5
# 或
ibus-daemon -drx  # ibus
```

### macOS (nix-darwin 或 Home Manager standalone)

```bash
# 如果使用 nix-darwin
darwin-rebuild switch --flake .#your-hostname

# 或者使用 home-manager 独立模式
home-manager switch --flake .#your-username

# 重新部署鼠须管
/Library/Input\ Methods/Squirrel.app/Contents/MacOS/Squirrel --reload
```

## 完整示例（单文件版 - Linux）

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
          - schema: keytao
          - schema: keytao-dz
        
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

## macOS 完整示例（Home Manager standalone）

> **⚠️ 前提条件**：请确保已安装鼠须管（Squirrel）。未安装请执行：
> ```bash
> brew install --cask squirrel
> ```
> 或访问 https://rime.im/download/#macOS 下载安装。

如果你在 macOS 上使用 Home Manager standalone（不使用 nix-darwin）：

```nix
# ~/.config/home-manager/flake.nix
{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rime-keytao = {
      url = "github:xkinput/KeyTao";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, rime-keytao, ... }: {
    homeConfigurations."your-username" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;  # 或 x86_64-darwin
      modules = [
        rime-keytao.homeManagerModules.default
        {
          home.username = "your-username";
          home.homeDirectory = "/Users/your-username";
          home.stateVersion = "24.05";

          # 启用星空键道6（自动使用 ~/Library/Rime）
          programs.rime-keytao.enable = true;
        }
      ];
    };
  };
}
```

应用配置：

```bash
# 切换配置
home-manager switch --flake ~/.config/home-manager#your-username

# 重新部署鼠须管
/Library/Input\ Methods/Squirrel.app/Contents/MacOS/Squirrel --reload
```
