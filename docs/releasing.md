# 构建与签名

当前版本为 **1.1.0**，Android 应用 ID 为 `app.misakafetch`。源码中的 `1.1.0+2` 表示应用版本 1.1.0、Android 构建号 2。

## Windows

在配置好 Flutter 与 Visual Studio C++ 桌面工具链的 Windows 电脑上执行：

```powershell
flutter pub get
flutter build windows --release
```

输出位于 `build/windows/x64/runner/Release/`。分发时保留完整目录、LICENSE 和 THIRD_PARTY_NOTICES.md。用户电脑需要 Visual C++ x64 运行库。

设置与背景保存在运行包内的 `user_data`，升级时保留用户自己的目录；公开安装包不包含个人设置或背景。

## Android

配置 JDK、Android SDK 和自己的签名后执行：

```powershell
flutter pub get
flutter build apk --release
```

可参考 `tool/create_android_signing.ps1` 配置本机签名。输出位于 `build/app/outputs/flutter-apk/app-release.apk`。缺少签名配置时 Release 构建会失败，Debug 构建无需正式签名。

官方安装包沿用 V1.0.0 的应用 ID 和发布签名。更新必须保留同一签名并递增构建号；自行生成的新签名不能覆盖安装官方版本。密钥、密码和 `android/key.properties` 不提交仓库，也不随安装包分发。签名材料需要独立离线备份。

## 源码检查

```powershell
flutter analyze
flutter test
```

自动测试不代替真机验证；旧版本的验证结果不自动适用于新版本。

## 发行文件

[GitHub Releases](https://github.com/fmSCMR/MisakaFetch/releases) 提供：

- `MisakaFetch-V1.1.0-Windows-x64.zip`
- `MisakaFetch-V1.1.0.apk`
- `SHA256SUMS.txt`

`V1.1.0` 标签应指向对应版本的源码提交。校验文件中的文件名和 SHA-256 必须与实际附件一致；上传后可核对 GitHub 返回的附件 digest。

更新内容见 [V1.1.0](release-notes-1.1.0.md)，历史更新见 [V1.0.0](release-notes-1.0.0.md)。