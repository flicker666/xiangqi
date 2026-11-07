# 中国象棋 Xiangqi

单机版中国象棋 iPhone App（SwiftUI），带强 AI、背景音乐与音效、棋谱、残局。

## 功能

- **完整规则**：车马炮象士将 / 仕帅、马腿、象眼、炮架、将军 / 将死 / 困毙、九宫、河界、卒过河横走、将帅不见面；同一方连续将军 3 次判负（长打简化处理），同一局面出现 3 次判和。
- **强 AI**：Negamax + Alpha-Beta 剪枝 + 迭代加深 + 静态评估（子力 + 位置分表）+ 吃子杀棋搜索（Quiescence）。三档难度：
  - 入门：搜索深度 2，思考上限 0.6 秒
  - 进阶：搜索深度 3，思考上限 1.5 秒
  - 大师：搜索深度 4，思考上限 3.0 秒
  - AI 在后台线程计算，不卡 UI。
- **界面**：SwiftUI 木纹棋盘、九宫斜线、炮位 / 兵位标记、红黑汉字棋子、点选走子、合法落点提示、上一步高亮、悔棋、新局、难度选择、红先 / AI 先手可选、胜负提示。
- **音乐与音效**：全部程序合成，不含任何版权音乐文件。背景音乐为古风五声音阶（宫商角徵羽）旋律循环，可开关、音量可调；音效有走子、吃子、将军、胜利、失败声。
- **棋谱**：对局自动记录中文着法，可保存到本地列表、查看、复盘逐步播放、删除、导出分享（文本）。
- **残局**：内置 8 个经典残局（单车胜单士、马炮胜单士、车马胜单车、双炮胜单象、马兵胜单士、车炮胜双士、单车胜双象、双马胜单车），红方先行，将死黑将即过关，带提示，黑方由入门 AI 应着。

## 在 Xcode 里打开

1. 需要一台 Mac，安装 Xcode 15 或更新版本。
2. 克隆本仓库：`git clone https://github.com/flicker666/xiangqi.git`
3. 双击打开 `Xiangqi.xcodeproj`。
4. 顶部选择一个模拟器（例如 iPhone 16），按 `Cmd+R` 运行。
5. 最低支持 iOS 16.0。

## 装到真机上

真机安装需要 Apple Developer 证书签名，仓库里没有、也无法替你提供证书：

1. 在 Xcode 里打开工程，选中 Target `Xiangqi` → Signing & Capabilities。
2. 勾选 Automatically manage signing，用你自己的 Apple ID 登录（免费个人账号也可以装到自己的 iPhone 上，有效期 7 天；付费开发者账号有效期 1 年）。
3. 把 Bundle Identifier 改成你自己的（例如 `com.你的名字.xiangqi`，不能和别人重复）。
4. 连接 iPhone，选择真机为运行目标，按 `Cmd+R`。
5. 首次运行若提示“不受信任的开发者”，去 iPhone 设置 → 通用 → VPN 与设备管理 → 信任你的开发者证书。

## GitHub Actions

`.github/workflows/ios.yml`：每次推到 `main` 分支时，在 `macos-latest` 上用 `xcodebuild` 编一个 iOS Simulator 构建（`CODE_SIGNING_ALLOWED=NO`，不做真机签名），用于验证代码能编译通过。

> 注意：本机开发环境为 Linux、无 Xcode，未在本机真编译；请以 Mac 上 Xcode 的实际编译结果和 GitHub Actions 的运行结果为准。

## 文件结构

```
Xiangqi.xcodeproj/          Xcode 工程
Xiangqi/
  XiangqiApp.swift          App 入口
  Info.plist
  Assets.xcassets/          图标与主题色
  Models/
    Models.swift            棋子、棋盘、走法生成、将军判定、中文着法
    AIEngine.swift          AI（Alpha-Beta + 迭代加深 + 评估 + 杀棋搜索）
    GameStore.swift         棋谱保存、残局数据、对局状态机
  Services/
    AudioManager.swift      程序化背景音乐与音效（AVAudioEngine）
  Views/
    Views.swift             棋盘、对局、棋谱复盘、残局、设置界面
.github/workflows/ios.yml  CI：模拟器构建
```

## 仓库

https://github.com/flicker666/xiangqi
