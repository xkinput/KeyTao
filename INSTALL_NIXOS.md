# 星空键道6 - Nix 安装指南

本仓库现已支持通过 Nix Flakes 在 NixOS 和 macOS 系统中便捷安装。

## 包含的文件

Nix 包会自动根据系统平台安装以下文件到 Rime 数据目录：

- **主码表文件**：`rime/` 目录下的所有词库和配置
- **Linux 专用配置**：
  - `schema/linux/keytao.schema.yaml` - Linux 版键道6方案
  - `schema/linux/keytao-dz.schema.yaml` - Linux 版键道6单字方案
- **macOS 专用配置**：
  - `schema/mac/keytao.schema.yaml` - Mac 版键道6方案
  - `schema/mac/keytao-dz.schema.yaml` - Mac 版键道6单字方案
  - `schema/mac/default.custom.yaml` - 默认配置
  - `schema/mac/squirrel.custom.yaml` - 鼠须管配置
  - 自动部署到 `~/Library/Rime` 目录（鼠须管默认目录）

与手动安装脚本（`scripts/linux/1install.sh` 或 `scripts/mac/2update.sh`）效果完全一致。

## 前提条件

### macOS 用户

**在使用 Nix 安装键道之前，必须先手动安装鼠须管（Squirrel）输入法。**

鼠须管目前尚未在 Nix 中打包，请通过以下方式之一安装：

**方式 1：官方下载**
- 访问 https://rime.im/download/#macOS
- 下载并安装 Squirrel.app

**方式 2：Homebrew**
```bash
brew install --cask squirrel
```

安装完成后，在"系统偏好设置 > 键盘 > 输入法"中添加"鼠须管"。

### Linux 用户

确保已安装 Rime 输入法前端（fcitx5-rime 或 ibus-rime），可通过 Nix 配置自动安装。

## 安装方式

### 方式一：使用 Home Manager 模块（推荐）

1. 在你的 `flake.nix` 中添加输入：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  
    # 添加 KeyTao
    rime-keytao = {
      url = "github:xkinput/KeyTao";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, rime-keytao, ... }: {
    homeConfigurations.your-username = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        # 导入 rime-keytao 的 Home Manager 模块
        rime-keytao.homeManagerModules.default
  
        # 你的其他配置
        ./home.nix
      ];
    };
  };
}
```

2. 在你的 `home.nix` 中启用：

```nix
{
  # 启用星空键道6
  programs.rime-keytao = {
    enable = true;
  
    # 可选：指定 Rime 数据目录
    # macOS：自动使用 Library/Rime（鼠须管默认目录，无需配置）
    # Linux：自动使用 .local/share/fcitx5/rime
  
    # 仅在需要自定义时配置：
    # rimeDataDir = ".local/share/fcitx5/rime";  # fcitx5-rime
    # rimeDataDir = ".config/ibus/rime";         # ibus-rime
    # rimeDataDir = "Library/Rime";              # macOS Squirrel（默认值）
  };
}
```

3. 重新构建并切换配置：

```bash
sudo nixos-rebuild switch --flake .#your-hostname
```

4. 重新部署 Rime：

```bash
# fcitx5-rime
fcitx5-remote -r

# 或在 fcitx5 设置中点击"重新部署"
```

### 方式二：手动安装包

如果你只想安装包而不使用 Home Manager 模块：

1. 在 `flake.nix` 中添加 overlay：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rime-keytao.url = "github:xkinput/KeyTao";
  };

  outputs = { nixpkgs, rime-keytao, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          nixpkgs.overlays = [ rime-keytao.overlays.default ];
        }
        ./configuration.nix
      ];
    };
  };
}
```

2. 手动复制文件到 Rime 配置目录：

```bash
# 构建包
nix build github:xkinput/KeyTao

# 复制到 fcitx5-rime 配置目录
cp -r result/share/rime-data/* ~/.local/share/fcitx5/rime/

# 或复制到 ibus-rime 配置目录
# cp -r result/share/rime-data/* ~/.config/ibus/rime/
```

### 方式三：直接使用（无需 flake）

对于不使用 flakes 的系统：

```bash
# 克隆仓库
git clone https://github.com/xkinput/KeyTao.git
cd KeyTao

# 构建
nix-build

# 复制到 Rime 配置目录
cp -r result/share/rime-data/* ~/.local/share/fcitx5/rime/

# 重新部署
fcitx5-remote -r
```

## 使用不同的 Rime 前端

### macOS - 鼠须管（Squirrel）

> **⚠️ 重要前提**：鼠须管目前尚未在 Nix 中打包，需要先手动安装。
> 
> 请访问 https://rime.im/download/#macOS 下载并安装鼠须管，或使用 Homebrew：
> ```bash
> brew install --cask squirrel
> ```

macOS 系统会自动检测并使用 `~/Library/Rime` 作为默认目录，无需额外配置：

```nix
# home.nix - macOS 用户无需指定 rimeDataDir
programs.rime-keytao = {
  enable = true;
  # 系统自动使用 Library/Rime
};
```

部署方式：

```bash
# 方式1: 命令行重新部署
/Library/Input\ Methods/Squirrel.app/Contents/MacOS/Squirrel --reload

# 方式2: 在鼠须管菜单中选择"重新部署"
```

### fcitx5-rime（Linux 推荐）

确保你的系统已安装并启用 fcitx5-rime：

```nix
# configuration.nix 或 home.nix
i18n.inputMethod = {
  enable = true;
  type = "fcitx5";
  fcitx5.addons = with pkgs; [
    fcitx5-rime
    fcitx5-chinese-addons
  ];
};

programs.rime-keytao = {
  enable = true;
  rimeDataDir = ".local/share/fcitx5/rime";
};
```

### ibus-rime

```nix
# configuration.nix
i18n.inputMethod = {
  enable = true;
  type = "ibus";
  ibus.engines = with pkgs.ibus-engines; [ rime ];
};
```

```nix
# home.nix
programs.rime-keytao = {
  enable = true;
  rimeDataDir = ".config/ibus/rime";
};
```

## 更新码表

由于使用了 flake 锁定版本，更新码表需要：

```bash
# 更新 flake 输入
nix flake lock --update-input rime-keytao

# 重新构建
sudo nixos-rebuild switch --flake .#your-hostname

# 重新部署 Rime
fcitx5-remote -r
```

## 配置自定义

所有 Rime 配置文件会被链接到你的 Rime 数据目录。你可以创建 `.custom.yaml` 文件来覆盖默认配置，例如：

```bash
# 编辑自定义配置
vim ~/.local/share/fcitx5/rime/default.custom.yaml

# 重新部署
fcitx5-remote -r
```

## 故障排查

### macOS - 重新部署后仍看不到键道方案

1. 检查文件是否正确安装：

```bash
ls -la ~/Library/Rime/*.schema.yaml
```

2. 查看 Rime 日志：

```bash
cat ~/Library/Rime/rime.log
```

3. 清除 Rime 缓存并重新部署：

```bash
rm -rf ~/Library/Rime/build
/Library/Input\ Methods/Squirrel.app/Contents/MacOS/Squirrel --reload
```

4. 检查鼠须管是否正在运行：

```bash
ps aux | grep Squirrel
```

### Linux - 重新部署 Rime 后仍看不到键道方案

1. 检查文件是否正确链接：

```bash
ls -la ~/.local/share/fcitx5/rime/*.schema.yaml
```

2. 查看 Rime 日志：

```bash
cat ~/.local/share/fcitx5/rime/rime.log
```

3. 清除 Rime 缓存：

```bash
rm -rf ~/.local/share/fcitx5/rime/build
fcitx5-remote -r
```

### Home Manager 配置冲突

如果你之前已经有自定义的 Rime 配置文件，Home Manager 可能会报错文件冲突。解决方法：

1. 备份现有配置
2. 使用 `home.file."xxx".force = true` 强制覆盖
3. 或者使用方式二手动管理

## 参考资源

- [键道官网](https://xkinput.github.io)
- [键道详尽操作指南](https://pingshunhuangalex.gitbook.io/rime-keytao/)
- [原始安装教程](https://github.com/xkinput/KeyTao)
