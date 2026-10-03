# MisakaFetch

**V1.1.0 · Bilibili 视频封面提取器 · Windows / Android**

输入视频链接、BV 号或分享文本，查看视频信息，预览并保存原始封面。无需登录。

## 下载

在 [GitHub Releases](https://github.com/fmSCMR/MisakaFetch/releases) 下载对应安装包：

- Windows：`MisakaFetch-V1.1.0-Windows-x64.zip`
- Android：`MisakaFetch-V1.1.0.apk`

Windows 需要完整解压，保留 DLL 和 `data` 文件夹，运行 `Windows/MisakaFetch.exe`。如提示缺少 MSVCP140 或 VCRUNTIME140，请安装 [微软 Visual C++ x64 运行库](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)。Android 直接安装 APK。

## 使用

1. 点击“视频封面提取”，展开输入区域。
2. 输入视频链接、BV 号或分享文本，点击“提取封面”。
3. 点击“保存原图”或“复制图片链接”。再次点击“视频封面提取”可收起，输入和结果会保留。

支持 AV 链接及 Bilibili 短链接。例如：

```text
BV1Q541167Qg
https://www.bilibili.com/video/BV1Q541167Qg/
```

## 功能

- 显示视频标题、UP 主、BV 号和封面图片。
- 保存原始图片，不截图、不重新压缩。
- 浅色、深色及跟随系统主题，标题和主题按钮始终显示。
- 自定义背景，调整模糊、亮度、遮罩与图片适配方式。
- 调整提取页卡片底色、边框颜色和透明度。
- Windows 单窗口运行，支持保存目录、文件名格式和同名文件自动编号。
- Android 10 及以上保存到 `Pictures/MisakaFetch`；Android 7–9 使用系统文件选择器。

## 设置与升级

Windows 设置和背景保存在运行包内的 `user_data` 文件夹；升级时保留自己的这个文件夹。Android 设置保存在应用私有目录。

从 Windows V1.0.0 升级时，新目录可能需要重新选择背景及偏好，旧设置文件不会删除。Android 更新需使用相同签名的安装包。

## 支持平台

| 平台 | 系统要求 |
| --- | --- |
| Windows x64 | Windows 10 / 11，Visual C++ x64 运行库 |
| Android | Android 7.0 / API 24 及以上 |

Android APK 包含 arm64-v8a、armeabi-v7a、x86_64。不支持 Web、iOS、macOS 或 Linux。

## 源码

项目使用 Flutter / Dart。安装 Flutter SDK 后，在包含 `pubspec.yaml` 的目录执行：

```text
flutter pub get
flutter run
```

Windows 构建使用 `flutter build windows --release`。Android 构建使用 `flutter build apk --release`，需先配置自己的签名；可参考 `tool/create_android_signing.ps1`。源码测试使用 `flutter test`。

## 隐私与限制

应用仅访问 Bilibili 公开视频信息与图片，不提供登录、Cookie 导入、视频下载或访问限制绕过。不收集账号或使用统计，不使用第三方解析服务器。

Bilibili 接口可能变化或限流，封面清晰度取决于返回的原图。

## 更新记录

- [V1.1.0](docs/release-notes-1.1.0.md)
- [V1.0.0](docs/release-notes-1.0.0.md)

## 反馈与许可证

问题和建议请提交到 [Issues](https://github.com/fmSCMR/MisakaFetch/issues)。

代码采用 [MIT License](LICENSE)，第三方依赖见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。封面权利归原权利人，代码许可证不授予封面的使用权。本项目与 Bilibili 无官方关联。
