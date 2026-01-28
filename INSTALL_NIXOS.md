# 星空键道6 - NixOS 安装指南

本仓库现已支持通过 Nix Flakes 在 NixOS 系统中便捷安装。

## 包含的文件

Nix 包会自动安装以下文件到 Rime 数据目录：

- **主码表文件**：`rime/` 目录下的所有词库和配置（67个文件）
- **Linux 专用配置**：
  - `Tools/SystemTools/default.yaml` - 系统默认配置
  - `Tools/SystemTools/default.custom.yaml` - 用户自定义配置模板
  - `Tools/SystemTools/rime/Linux/xkjd6.schema.yaml` - Linux 版键道6方案
  - `Tools/SystemTools/rime/Linux/xkjd6dz.schema.yaml` - Linux 版键道6单字方案

与手动安装脚本（`Tools/SystemTools/LinuxTools/1install.sh`）效果完全一致。

## 安装方式

### 方式一：使用 Home Manager 模块（推荐）

1. 在你的 `flake.nix` 中添加输入：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    
    # 添加 Rime_JD
    rime-keytao = {
      url = "github:xkinput/Rime_JD";  # 或 "git+https://gitee.com/xkinput/Rime_JD"
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
    
    # 可选：指定 Rime 数据目录（默认是 fcitx5）
    rimeDataDir = ".local/share/fcitx5/rime";  # fcitx5-rime
    # rimeDataDir = ".config/ibus/rime";       # ibus-rime
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
    rime-keytao.url = "github:xkinput/Rime_JD";
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
nix build github:xkinput/Rime_JD

# 复制到 fcitx5-rime 配置目录
cp -r result/share/rime-data/* ~/.local/share/fcitx5/rime/

# 或复制到 ibus-rime 配置目录
# cp -r result/share/rime-data/* ~/.config/ibus/rime/
```

### 方式三：直接使用（无需 flake）

对于不使用 flakes 的系统：

```bash
# 克隆仓库
git clone https://gitee.com/xkinput/Rime_JD.git
cd Rime_JD

# 构建
nix-build

# 复制到 Rime 配置目录
cp -r result/share/rime-data/* ~/.local/share/fcitx5/rime/

# 重新部署
fcitx5-remote -r
```

## 使用不同的 Rime 前端

### fcitx5-rime（推荐）

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
vim ~/.local/share/fcitx5/rime/xkjd6.custom.yaml

# 重新部署
fcitx5-remote -r
```

## 故障排查

### 重新部署 Rime 后仍看不到键道方案

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

- [键道官网](https://xkinput.gitee.io)
- [键道详尽操作指南](https://pingshunhuangalex.gitbook.io/rime-keytao/)
- [原始安装教程](https://gitee.com/xkinput/Rime_JD)
