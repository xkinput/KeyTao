<h1 align="center">星空键道6</h1>

> 作者：**吅吅大山** | [键道官网][904] | [键道6词库议表][916] | [键道6查码工具][917]

> 交流群：[加入官方QQ大群][903] | [加入键道6群][928] | [加入TG群][929]

> 方案文档：[键道详尽操作指南][900] | [简易Wiki文档][921] | [键道6白话文教程][901]

> [键魂][221] - 键道初学者用的「键道」虚拟键位软件。学完规则不用记忆键位就能立即上手体验「键道」打字的乐趣！

> 选中查字 & 屏幕悬浮键位表辅助工具：[键道 for Quicker][218]

---

#### 目录结构说明：

| 路径                                   |         作用         |
| :------------------------------------- | :------------------: |
| [/Tools](./Tools)                         |       工具目录       |
| [/Tools/Extended](./Tools/Extended)       |       扩展码表       |
| [/Tools/SystemTools](./Tools/SystemTools) |  各系统配置文件工具  |
| [/rime](./rime)                           | 主码表文件夹[主码表] |
| [README.md](./README.md)                  |  readme.md说明文件  |

---

#### 首次安装：

* Windows 首选安装方式： 推荐手动安装小狼毫、Git，下载本项目，执行 Windows 目录下更新程序

  > 说明：打包内包含完整本项目，克隆完成后，请按照下面 Git 安装后同步最新码表 `git pull` 后，升级到最新码表。
  >

  > 若有疑问，请查看安装教程：https://www.bilibili.com/video/av53185153
  >
* Linux 首选安装方式：
  详见wiki页教程：[Linux安装rime键道教程][linux安装键道6]
* **NixOS 安装方式 🆕：**
  详见：**[NixOS 安装指南](./INSTALL_NIXOS.md)** | [配置示例](./examples/nixos-config-example.md)

  使用 Nix Flakes 一键安装，支持 Home Manager 模块自动管理配置文件。
* Mac 首选安装方式：

  1. 安装鼠须管

     > 有两种方式安装鼠须管，请选其1操作即可
     >

     1. 下载 [鼠须管文件安装][924]
     2. brew方式(需要提前安装brew)

        ```bash
        brew cask install squirrel
        ```
  2. 克隆rime键道仓库

     ```bash
     # github仓库
     git clone https://github.com/xkinput/KeyTao/
     ```
  3. 执行Mac专有脚本以完成键道码表部署

     ```bash
     # 跳转到KeyTao目录中Mac脚本目录
     cd KeyTao/Tools/SystemTools/MacTools/
     # 执行2update.sh 选择安装键道6词库y
     ./2update.sh
     # 待完成后尝试输入即可
     ```

  Mac可使用 [SCU][925] 做日常配置操作

  > 注意：请确保设备含有网络、可使用项目内配备的升级工具做升级码表到最新。
  >
* Android 首选安装方式：[Android键道6安装包][927]

  > 首先：安装安装包，打包内包含码表与皮肤，以及词库（内置词库比较旧，建议安装后继续下一步，来更新词库）
  >

  > 使用MGit来克隆rime键道最新词库：，请按照下面[安卓系统MGit](#android-系统-git)安装后克隆 `https://github.com/xkinput/KeyTao` 最新码表，复制最新码表到对应用户目录，重新部署以升级到最新码表。
  >

  > 更新方式：安装上面所讲的MGit，进入KeyTao，点击侧栏里的 `拉取`等待完成后，再次将最新码表复制到用户目录，重新部署同文输入法即可。
  >

  > 若有疑问，请查看安装教程。
  > 图文教程：[Android 安装「键道」同文输入法图文教程][220]
  >

  > 视频教程：https://www.bilibili.com/video/av53238185
  > `<a name="ios-install"></a>`
  >
* iOS 首选安装方式：

  - iRime：至 app store 搜寻 iRime 下载 app，内有教程；请参考 [iRime 部署「键道」图文教程][219] 或 [iOS平台安装部署教程][913]
  - 落格（付费软件）：至 app store 搜寻落格下载 app，至「对数云-主码表」下载「星空键道6.2 -- 官方版本]

#### 并击功能：

> 并击功能说明：在并击模式下，可实现字词100%左右互击，也能更方便的处理某些别手键位。目前并击功能已集成于本项目的Windows键道6之内，其他平台的用户请自行提取配置文件。如您在使用过程中有任何疑问，可在本项目留言咨询，或加入官方群讨论。

> 并击功能教学视频：https://www.bilibili.com/video/av68282400/

#### 安装 Git 使用说明：使用 Git 程序（可滚动更新）

 **[Git下载地址罗列][918]**

* ##### Windows 系统 Git：

  [官网][905] | [国内镜像源][912]
* Linux 系统 Git：[自行安装]
* Mac 系统 Git：内建 git 程序，无需另外安装
* ##### Android 系统 Git：

  [下载(MGit)][926]
* iOS 系统：现阶段无法使用 git 更新，请参考[首次安装方式](#ios-install)

##### 使用简述：

```bash
# 需要安装 Git 后，将克隆项目到本地（打开 git bash 中输入，下面一样的）
git clone https://github.com/xkinput/KeyTao
# 切换到项目文件夹
cd KeyTao
# 在文件管理器打开当前目录（`pwd` 可以查看目录位置），进入 KeyTao/Tools/SystemTools/ 对应系统的工具目录执行复制码表工具（1install），再重新部署即可更新完成
```

##### 获取更新：

1. 获取上游地址的 master 分支

```bash
git pull
```

2. 获取后，执行复制码表工具（2update），再重新部署即可更新完成

#### 最后：

> 重新部署，并尝试输入文字。安装完成。

#### 键道6方案[文档][930]

#### 扩展说明：

1. 扩展控制文件为 keytao.extended.dict.yaml / keytao-dz.extended.dict.yaml
2. 文件中有详细说明。

#### 分支说明：

> master 为定期更新稳定内容。

---

#### 若你想要发起 PR 为本项目做出贡献：

##### 创建远程仓库，指向 PR 提交者的仓库

1. 指定上游地址`git remote add upstream https://github.com/xkinput/KeyTao.git`
2. 从该远程仓库拉取代码`git fetch upstream`
   > **如果上游更新内容含有 缩减仓库历史，请在 push 代码前 pull rebase
   > 详见：[缩减仓库说明][908]**
   >
3. 将该仓库的上游分支合并到自己分支`git merge upstream`
4. 推送到自己的仓库
   `git push origin master`

##### 提交commit规范：

* 码表分类：[据议表调整： x个] 外加调整：词组 编码... x个
* 工具类：系统名：工具名 文件名 纠错/添加/删除

> 详见：**[git-简明指南][909] / [git入门][919] [码云PR教程][907] / [博客PR教程][906] / [缩减仓库说明][908]**

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

| Windows                |          Linux          |      Apple 装置      |        Android        |
| ---------------------- | :----------------------: | :------------------: | :-------------------: |
| [Windows(weasel)][101] | [Linux(ibus-rime)][104] | [Mac(squirrel)][102] | [Android(trime)][105] |
| [Windows(小小)][203]   | [Linux(fcitx-rime)][103] |  [iOS(iRime)][106]  | [Android(小小)][203] |
| [Windows(多多)][108]   |    [Linux(小小)][203]    |   [iOS(落格)][107]   |                      |

> 键道的跨平台使用离不开以上优秀的输入平台

[999]: https://github.com/xkinput/KeyTao
[linux安装键道6]: https://github.com/xkinput/KeyTao/wiki/Linux%E5%AE%89%E8%A3%85rime%E9%94%AE%E9%81%936%E6%95%99%E7%A8%8B
[101]: https://github.com/rime/weasel
[102]: https://github.com/rime/squirrel
[103]: https://github.com/fcitx/fcitx-rime
[104]: https://github.com/rime/ibus-rime
[105]: https://github.com/osfans/trime
[106]: https://github.com/jimmy54/iRime
[107]: https://im.logcg.com/
[108]: https://chinput.com/portal.php
[200]: https://github.com/rime
[201]: http://rime.im
[202]: https://github.com/osfans
[203]: https://github.com/dgod/yong
[204]: https://github.com/xkinput/KeyTao
[205]: https://xkinput.github.io/xxxk-help
[206]: https://github.com/tswwe
[207]: https://github.com/lyserenity/xkjd6_tc
[208]: https://github.com/xkinput/KeyTao/releases
[209]: https://github.com/xkinput/KeyTao/repository/archive/master.zip
[210]: https://github.com/xkinput/KeyTao/tree/master/Tools/SystemTools
[211]: https://github.com/xkinput/KeyTao/tree/master/rime
[212]: https://github.com/xkinput/KeyTao/tree/master/SystemTools/Android
[213]: https://gitee.com/morler/rime_xklb
[214]: https://gitee.com/morler
[215]: https://github.com/dzyht/rime_xkyb
[216]: https://gitee.com/dzyht
[217]: https://gitee.com/dzyht/rime_xkybd
[218]: https://getquicker.net/Sharedaction?code=05ec6884-ae9f-44ed-5f89-08d9b92d74db
[219]: https://telegra.ph/iRime-%E5%A6%82%E4%BD%95%E5%AF%BC%E5%85%A5%E8%BE%93%E5%85%A5%E6%96%B9%E6%A1%88---%E4%BB%A5%E9%94%AE%E9%81%93%E4%B8%BA%E4%BE%8B-12-25
[220]: https://telegra.ph/Android-%E5%AE%89%E8%A3%85%E9%94%AE%E9%81%93%E5%90%8C%E6%96%87%E8%BE%93%E5%85%A5%E6%B3%95%E5%9B%BE%E6%96%87%E6%95%99%E7%A8%8B-12-25
[221]: https://ispoto.github.io/KeySoul/
[900]: https://pingshunhuangalex.gitbook.io/rime-xkjd/
[901]: https://xkinput.github.io/xxxk-help/#/schema-xkjd6
[902]: http://daniushuangpin.ys168.com
[903]: https://jq.qq.com/?_wv=1027&k=5sTEYIQ
[904]: https://xkinput.github.io
[905]: https://git-scm.com/
[906]: http://www.ruanyifeng.com/blog/2017/07/pull_request.html
[907]: http://git.mydoc.io/?t=180700
[908]: http://git.mydoc.io/?t=83153
[909]: http://rogerdudler.github.io/git-guide/index.zh.html
[910]: http://sj.qq.com/myapp/detail.htm?apkName=com.aor.pocketgit
[911]: https://www.jianguoyun.com/p/DV2MIxsQ67buBhjNl1w
[912]: https://npm.taobao.org/mirrors/git-for-windows
[913]: https://hanhngiox.net/install/ios.html
[914]: https://pan.baidu.com/s/1uvTbIKwxzJU-Udk4WeDAwQ
[915]: https://pan.baidu.com/s/1BiXlCS4JualOtXvbbTeAQQ
[916]: https://docs.qq.com/sheet/BFdiXU0nyc1W1kwuZl3Gx31r2KLm2k3F8YzI4
[917]: http://xkinput.github.io/tools/search
[918]: https://gitee.com/all-about-git
[919]: https://www.liaoxuefeng.com/wiki/0013739516305929606dd18361248578c67b8067c8c017b000/001373962845513aefd77a99f4145f0a2c7a7ca057e7570000
[920]: https://pan.baidu.com/s/1S9ktUAFcqJjjnqovEBSLig
[921]: https://github.com/xkinput/KeyTao/wikis
[923]: http://rimejd.ys168.com
[924]: https://rime.im/download/#macOS
[925]: https://github.com/neolee/SCU
[926]: https://f-droid.org/zh_Hans/packages/com.manichord.mgit
[927]: https://wwa.lanzoux.com/b0dhdlkj
[928]: https://jq.qq.com/?_wv=1027&k=c1T3vOwc
[929]: https://t.me/xkinput
[930]: https://keytao-docs.vercel.app/
