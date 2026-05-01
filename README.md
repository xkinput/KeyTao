<h1 align="center">星空键道6</h1>

> 作者：**吅吅大山** | [键道官网][904] | [键道6查码工具][917] | [键道文档][900]

> 社区：[星空输入法QQ群][903] | [星空键道QQ群][928] | [加入TG群][929]

> [键魂][221] - 键道初学者用的「键道」虚拟键位软件。学完规则不用记忆键位就能立即上手体验「键道」打字的乐趣！

> 选中查字 & 屏幕悬浮键位表辅助工具：[键道 for Quicker][218]

---

#### 目录说明：

| 路径                                 |         作用         |
| :----------------------------------- | :------------------: |
| [/docs](./docs)                         |       文档目录       |
| [/extend-dicts](./extend-dicts)         |       扩展词典       |
| [/rime](./rime)                         | 主码表文件夹[主码表] |
| [/schema](./schema)                     |  各系统方案配置文件  |
| [/scripts](./scripts)                   |    各系统脚本工具    |
| [/INSTALL_NIXOS.md](./INSTALL_NIXOS.md) |    NixOS 安装指南    |
| [/README.md](./README.md)               |     项目说明文件     |

---

#### 安装教程：

* 前往下载 **[KeyTao 键道安装更新程序](https://github.com/xkinput/keytao-installer/releases/latest)**，可自动完成键道方案的安装与更新，支持 Windows / macOS / Linux / Android。
* Linux 如果遇到fcitx/ibus问题可查看[安装 fcitx/rime 教程][linux安装键道6]
* **Nix/NixOS 安装方式 🆕：**
  详见：**[Nix 安装指南](./INSTALL_NIXOS.md)** | [配置示例](./docs/nixos-config-example.md)

  使用 Nix Flakes 一键安装，支持 Home Manager 模块自动管理配置文件。

  > **macOS 用户注意**：使用 Nix 安装前需先手动安装鼠须管（见下方 Mac 安装方式）。
  >
* iOS 安装方式：

  - **[元书输入法][106]**：至 App Store 搜索「元书输入法」下载，进入「输入方案 → 下载方案」，填写以下稳定链接即可自动获取最新 iOS 码表包：
    ```
    https://keytao.vercel.app/api/install/ios-latest
    ```
    下载后切换目录到键道即可自动部署

#### 并击功能：

> 并击功能说明：在并击模式下，可实现字词100%左右互击，也能更方便的处理某些别手键位。目前并击功能已集成于本项目的Windows键道6之内，其他平台的用户请自行提取配置文件。如您在使用过程中有任何疑问，可在本项目留言咨询，或加入官方群讨论。

> 并击功能教学视频：https://www.bilibili.com/video/av68282400/

#### 扩展说明：

1. 扩展控制文件为 keytao.extended.dict.yaml / keytao-dz.extended.dict.yaml
2. 文件中有详细说明。

---

#### 开发与验证：

##### 验证 Schema 配置

运行以下脚本可在本地对所有平台的方案做完整验证（Lua 语法 + 五平台 Rime 编译）：

```bash
bash scripts/validate.sh
```

验证内容：
1. **Lua 语法检查** — 用 `luac -p` 检查 `rime/lua/*.lua` 所有文件
2. **五平台编译** — 用 `rime_deployer --build` 分别编译 linux / mac / windows / android / ios 各平台的 schema 组合，任何 schema 错误都会报出

CI 会在每次 Release 发布前自动运行此脚本，编译失败则阻止发布。

##### Nix 开发环境

使用 `nix develop` 可一键获得 `rime_deployer` 和 `luac`：

```bash
nix develop          # 进入开发 shell，自动配置 RIME_SHARED
bash scripts/validate.sh
```

非 Nix 环境（如 Ubuntu）需手动安装依赖：

```bash
sudo apt install librime-bin rime-data lua5.4
```

---

---

### 星空系列其他 Rime 方案：

| [Morler][214]   | [歌颂][216]                 |
| --------------- | --------------------------- |
| [星空两笔][213] | [星空一笔 OR 星空一道][217] |

---

### 键道6第三方维护版本：

| RIME        |      小小      |
| ----------- | :------------: |
| [Qshu][204] | [thxnder][206] |
| [主页][204] |  [主页][205]  |

---

### 扩展词库：

| 正體字碼表      | 二分词库 |    诗词引导    |
| --------------- | :------: | :------------: |
| [岳飞丫飞][207] | 吅吅大山 | [thxnder][206] |
| [主页][207]     |          |  [主页][206]  |

---

### 键道可以运行在以下平台中：

| Windows                |          Linux          |              Apple 装置              |        Android        |
| ---------------------- | :----------------------: | :----------------------------------: | :-------------------: |
| [Windows(weasel)][101] | [Linux(ibus-rime)][104] |         [Mac(squirrel)][102]         | [Android(trime)][105] |
| [Windows(小小)][203]   | [Linux(fcitx-rime)][103] |           [iOS(元书)][106]           | [Android(小小)][203] |
| [Windows(多多)][108]   |    [Linux(小小)][203]    | [iOS(iRime)][920] / [iOS(落格)][107] |                      |

> 键道的跨平台使用离不开以上优秀的输入平台

[linux安装键道6]: https://github.com/xkinput/KeyTao/wiki/Linux%E5%AE%89%E8%A3%85rime%E9%94%AE%E9%81%936%E6%95%99%E7%A8%8B
[101]: https://github.com/rime/weasel
[102]: https://github.com/rime/squirrel
[103]: https://github.com/fcitx/fcitx-rime
[104]: https://github.com/rime/ibus-rime
[105]: https://github.com/osfans/trime
[106]: https://apps.apple.com/cn/app/%E5%85%83%E4%B9%A6%E8%BE%93%E5%85%A5%E6%B3%95/id6744464701
[107]: https://im.logcg.com/
[920]: https://github.com/jimmy54/iRime
[108]: https://chinput.com/portal.php
[203]: https://github.com/dgod/yong
[204]: https://github.com/xkinput/KeyTao
[205]: https://xkinput.github.io/xxxk-help
[206]: https://github.com/tswwe
[207]: https://github.com/lyserenity/xkjd6_tc
[213]: https://gitee.com/morler/rime_xklb
[214]: https://gitee.com/morler
[216]: https://gitee.com/dzyht
[217]: https://gitee.com/dzyht/rime_xkybd
[218]: https://getquicker.net/Sharedaction?code=05ec6884-ae9f-44ed-5f89-08d9b92d74db
[219]: https://telegra.ph/iRime-%E5%A6%82%E4%BD%95%E5%AF%BC%E5%85%A5%E8%BE%93%E5%85%A5%E6%96%B9%E6%A1%88---%E4%BB%A5%E9%94%AE%E9%81%93%E4%B8%BA%E4%BE%8B-12-25
[221]: https://ispoto.github.io/KeySoul/
[900]: https://keytao-docs.vercel.app
[903]: https://qm.qq.com/q/PU65aZoNOg
[904]: https://keytao.vercel.app
[913]: https://hanhngiox.net/install/ios.html
[917]: https://keytao.vercel.app/phrases
[928]: https://qm.qq.com/q/uNFITZVL4A
[929]: https://t.me/xkinput
