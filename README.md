# MisakaFetch

MisakaFetch 是一款简洁的 Bilibili 视频封面提取器，使用 Flutter / Dart 开发，支持 Windows 和 Android，两平台共用界面、解析和网络代码。

粘贴视频链接、BV 号或分享文本，查看公开视频信息和封面，再保存原始图片或复制图片链接。应用直接请求 Bilibili 公开信息和图片 CDN，无需登录或自建服务器。

**版本：1.0.0。支持 Windows 和 Android，Android 真机验证已完成。**

## 功能

- 识别完整视频链接、BV 号和分享文本；支持 AV 视频链接及符合限制的 Bilibili 短链接。
- 显示视频标题、UP 主、BV 号、完整封面预览及原始图片地址。
- 保存原始图片字节，不截图、不重新压缩；根据实际类型使用 jpg / png / webp / gif 扩展名。
- Windows 系统另存为或默认目录直接保存，同名文件自动编号；Android 10+ 写入 Pictures/MisakaFetch，Android 7–9 使用系统文件选择器。
- 清理非法文件名，处理中文和长标题；中文错误提示、加载状态、封面重试与重复请求保护。
- Material 3，浅色 / 深色 / 跟随系统主题，选择在本地持久化，适应桌面窗口和手机尺寸。汉字使用简体中文字体回退，Windows 优先微软雅黑，保留原有英文字体。

可通过左下角设置按钮选择自定义背景，调整模糊、亮度、遮罩和适配方式，支持更换、移除与恢复背景参数。背景副本和设置保存在本机应用数据目录；原始选中图片不会修改或删除。还可选择三种文件名格式、Windows 默认保存目录和保存成功后的行为（仅提示 / 打开所在文件夹 / 不显示额外操作）。关于区域显示实际应用版本、MIT 与第三方许可证。

不提供登录、Cookie 导入、访问限制绕过或视频 / 音频 / 弹幕下载。

## 支持平台

| 平台 | 最低要求 | 当前验证状态 |
| --- | --- | --- |
| Windows x64 | Windows 10 / 11，Visual C++ x64 运行库 | Debug / Release 构建和开发机启动通过；干净系统待验收 |
| Android | Android 7.0 / API 24 | Debug / Release APK 构建通过；真机验证通过 |

Android 通用 APK 包含 arm64-v8a、armeabi-v7a、x86_64。v1.0 不支持 Web、iOS、macOS 或 Linux。

## 使用

1. 启动应用，粘贴视频链接、BV 号或分享文本。
2. 点击“提取封面”，等待信息和图片加载。
3. 点击“保存原图”选择位置或写入相册，也可点击“复制图片链接”。

输入示例：

```text
BV1Q541167Qg
https://www.bilibili.com/video/BV1Q541167Qg/
分享视频：https://www.bilibili.com/video/BV1Q541167Qg/?share_source=copy_web
```

Windows 压缩包需完整解压，保留 DLL 和 data 目录后运行 MisakaFetch.exe。Android 10+ 在文件管理器的 Pictures/MisakaFetch 或系统相册查看图片；Android 7–9 保存到系统选择器指定的位置。视频及封面是否可访问取决于公开返回结果。

克隆仓库后，包含 `pubspec.yaml`、`lib/` 和 `android/` 的目录就是项目根目录；本文所有开发命令均在该目录执行。普通用户请在仓库 [Releases](https://github.com/fmSCMR/MisakaFetch/releases) 下载 Windows ZIP 或 Android APK。Windows ZIP 完整解压后进入 Windows 文件夹运行 MisakaFetch.exe。

## 截图

| Windows 浅色 | Windows 深色 | Android |
| --- | --- | --- |
| 截图待补充 | 截图待补充 | 截图待补充 |

截图要求见 [截图说明](docs/screenshots/README.md)。

## 开发环境

已验证：Flutter **3.47.5 stable**、Dart **3.13.4**。首次复现建议使用相同 Flutter 版本；应用依赖由提交的 pubspec.lock 固定。

- Windows：Visual Studio 2026 的“使用 C++ 的桌面开发”工作负载和 Windows SDK；开启 Windows 开发者模式以支持插件符号链接。
- Android：JDK 21、Android SDK Platform 36、Build Tools 36.0.0、Platform Tools、NDK 28.2.13676358。可使用 Android Studio 或独立 SDK 命令行工具。
- Gradle 9.3.1 和 Android Gradle Plugin 9.1.0 由项目配置管理，无需全局安装 Gradle。
- Git，用于源码版本管理。

项目使用 Git 管理源码；开发者可克隆仓库后创建自己的分支。

运行 `flutter doctor -v` 检查环境。首次依赖及工具链下载需要网络。

## 如何运行

在包含 pubspec.yaml 的项目根目录执行：

```powershell
flutter pub get
flutter run -d windows
```

Android：连接已开启 USB 调试的手机并允许调试授权，或启动模拟器。将实际设备 ID 替换下面的占位：

```powershell
flutter devices
flutter run -d <设备ID>
```

## 检查与测试

```powershell
flutter analyze
flutter test
```

已完成本地静态分析与 **259 个测试**；`.github/workflows/ci.yml` 在推送和 Pull Request 时执行 `flutter analyze` 与 `flutter test`，不需要签名密钥。当前检查覆盖输入解析、JSON 验证、超时、错误转换、文件名、原始字节保存、模拟平台通道和 UI。默认测试不请求 Bilibili；模拟通道不代表设备保存已验收。

显式联网检查：

```powershell
dart run tool/verify_bilibili.dart
dart run tool/verify_cover.dart
```

以下为可选的 Windows 本地 QA 流程，需要 Windows 系统字体，不在普通设备上运行：

```powershell
dart run tool/verify_cover.dart --write-fixture
flutter test tool/render_ui_test.dart
flutter test tool/verify_save_test.dart
```

QA 输出位于 `build/qa`。Windows 渲染检查使用系统微软雅黑字体；字体文件不随应用分发。原图保存测试校验下载与保存字节一致。

## 构建 Windows

在配置了桌面工具链的 Windows 电脑上执行：

```powershell
flutter pub get
flutter build windows --release
```

输出为 build/windows/x64/runner/Release/。分发时保留整个目录，并附带 LICENSE 和 THIRD_PARTY_NOTICES.md。用户电脑需要微软 Visual C++ x64 Redistributable，参见 [Flutter Windows 分发说明](https://docs.flutter.dev/platform-integration/windows/building#building-your-own-zip-file-for-windows)。

## 构建 Android APK

```powershell
flutter pub get
flutter build apk --release
```

输出为 build/app/outputs/flutter-apk/app-release.apk。

**Release 使用项目专用签名，应用 ID 为 app.misakafetch。** 首次本地构建需设置 JAVA_HOME 后运行 `powershell -ExecutionPolicy Bypass -File tool/create_android_signing.ps1`（仅适用于该 PowerShell 进程），或自行配置忽略的 android/key.properties。私钥保存在用户目录 .misakafetch/signing，不能公开或随应用分发；应另存离线备份。缺少签名配置时 Release 构建会明确失败，Debug 构建仍可使用。参见 [Flutter Android 签名文档](https://docs.flutter.dev/deployment/android#sign-the-app) 和 [发布准备说明](docs/releasing.md)。

发行附件放在 GitHub Releases，源码仓库不存放构建产物或个人备份。Windows 构建后分发整个 Release 目录，Android 分发项目签名 APK；不要上传签名密钥、密码或 android/key.properties。

## 项目结构

```text
lib/
  main.dart                           启动入口
  app.dart                            Material 3 与统一主题状态
  controllers/settings_controller.dart 设置即时更新与顺序保存
  pages/settings_page.dart            外观、背景、保存与关于设置
  widgets/app_background.dart         独立背景效果层
  services/background_image_service.dart 背景内部副本与校验
  models/                             视频、下载图片与应用设置模型
  pages/home_page.dart                主界面与异步交互状态
  widgets/video_result_card.dart      视频结果卡片
  utils/bilibili_parser.dart           输入识别与链接校验
  utils/filename_utils.dart            跨平台文件名清理
  services/bilibili_service.dart       公开接口、短链与 JSON 验证
  services/image_download_service.dart 原图下载与错误转换
  services/image_save_service.dart     Windows / Android 保存入口
  services/settings_repository.dart    设置读取、校验与本地持久化
  services/platform_actions_service.dart Windows 目录选择与打开
  services/app_info_service.dart        平台应用版本元数据
android/                              Android 入口与小型存储桥接
windows/                              Windows 原生运行入口
test/                                 模型、解析器、服务和界面测试
tool/                                 显式联网与本地 QA 工具
docs/                                 设备验收清单、截图占位和发布说明
pubspec.yaml / pubspec.lock            依赖声明与锁定版本
```

Bilibili 逻辑集中在 parser / service；UI 使用经过验证的 VideoInfo，不直接读取 API JSON。AndroidImageSaver.kt 仅封装 MediaStore / 系统文件选择器及后台原始字节写入，不维护另一套界面或视频解析。

## 依赖与许可证

| 依赖 | 用途 | 许可证 |
| --- | --- | --- |
| [url_launcher 6.3.2](https://pub.dev/packages/url_launcher) | 通过系统浏览器打开 GitHub 项目 | BSD-3-Clause |
| [http 1.6.0](https://pub.dev/packages/http) | 网络请求、取消与可注入客户端 | BSD-3-Clause |
| [file_selector 1.1.0](https://pub.dev/packages/file_selector) | Windows 系统另存为、两平台背景图片选择 | BSD-3-Clause |
| [shared_preferences 2.5.5](https://pub.dev/packages/shared_preferences) | 轻量本地设置持久化，使用 Async API | BSD-3-Clause |
| [path_provider 2.1.6](https://pub.dev/packages/path_provider) | 自定义背景的应用内部持久化目录 | BSD-3-Clause |
| [package_info_plus 10.2.1](https://pub.dev/packages/package_info_plus) | 读取当前构建的应用版本，避免重复硬编码 | BSD-3-Clause |
| flutter_lints | 开发时静态分析规则 | BSD-3-Clause |

另使用 Flutter SDK 和 flutter_test。运行时传递依赖许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，Flutter 构建产物还包含生成的依赖许可集合；分发时保留它们。没有广告、Analytics 或存储权限插件。

## 隐私

输入在本地识别，仅为查询公开视频信息及下载封面访问 Bilibili 官方域名和图片 CDN。不运行自建服务器，不上传输入到第三方解析服务，不收集账号、设备指纹或使用统计。正常网络请求会向目标服务提供连接信息，如 IP 地址。

Windows 写入用户选择的路径；Android 10+ 只创建应用自己的媒体条目，Android 7–9 只取得所选文档的写入授权，不读取已有相册。业务仅需 INTERNET；合并 APK 还含 应用私有签名级权限 `app.misakafetch.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`（由 AndroidX 合并引入）。没有定位、摄像头、麦克风或广泛存储权限。

## 已知限制

- Bilibili 公开 Web 接口不是对第三方保证稳定的开放 API，可能变化、限流或拒绝访问；应用显示错误，不绕过限制。
- 短链接最多五次跳转，仅访问允许的 Bilibili 域名；HTML 中转页、第三方地址或非视频页可能需要改用完整链接 / BV。
- 视频请求总超时 20 秒、JSON 上限 2 MiB；图片请求超时 20 秒、上限 20 MiB。损坏或不能解码的图片不能保存。
- 公开接口返回的原图不一定有更高分辨率，部分视频可能返回透明占位图；应用保留原始内容。
- 设置系统已包含主题持久化、独立设置页、自定义背景、界面动画、保存选项与关于信息；关于页可通过系统浏览器打开 GitHub 项目，失败时可复制地址。次要字段 AV 号、发布时间、简介保留在模型中，当前界面只显示核心信息。
- Android 应用 ID 为 `app.misakafetch`，Release APK 使用项目专用签名。旧测试包的私有设置不会自动迁移到新应用。
- Windows 干净系统待验收，EXE 尚无代码签名；Windows、启动器和 Android 已使用 MisakaFetch 专属图标。
- 文件名最多 100 个 Unicode 码点及 240 UTF-8 字节；目录过长、不可写或空间不足仍可能保存失败。

文档索引见 [docs/README.md](docs/README.md)，发布步骤见 [docs/releasing.md](docs/releasing.md)。

## License

项目代码采用 [MIT License](LICENSE)。Flutter 和第三方依赖保留各自许可证。视频封面属于其原权利人，项目代码的 MIT 许可证不授予封面的使用权。本项目与 Bilibili 无官方关联。

## 问题反馈

请通过 [Issues](https://github.com/fmSCMR/MisakaFetch/issues) 提交问题，包含版本、平台和复现步骤。反馈前移除图片或日志中的个人信息。发布说明见 [V1.0.0](docs/release-notes-1.0.0.md)。
