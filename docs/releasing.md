# MisakaFetch 本地构建与签名

当前版本为 1.0.0，Android namespace / applicationId 为 app.misakafetch。Release 使用项目独立 RSA 3072 签名，不再使用 Android Debug 证书。Windows 保留完整运行目录后双击其中的 MisakaFetch.exe。

## Android 签名配置

设置 JAVA_HOME 为本机 JDK 路径，运行：

```powershell
powershell -ExecutionPolicy Bypass -File tool/create_android_signing.ps1
flutter build apk --release
```

脚本也可通过 -Keytool 指定 keytool.exe。已存在本机配置时不覆盖；已有密钥但凭据缺失时不会生成新密钥。密钥和随机密码存放在用户目录 .misakafetch/signing，仅当前 Windows 用户和 SYSTEM 可访问。android/key.properties 为本机副本，已被忽略。程序不会将密钥、密码、生成日志或 key.properties 放入运行包。

签名目录中的 recovery-copy 是同盘恢复副本，不能替代离线备份。将整个签名目录另存到安全的离线介质，保留原密钥以便安装未来更新。密码不显示在构建日志或文档中。

缺少 release 配置时 flutter build apk --release 明确失败，不会回退到 debug 签名。flutter run 等 Debug 开发方式无需正式签名。配置方式参照 [Flutter 官方签名说明](https://docs.flutter.dev/deployment/android#sign-the-app)。

新应用 ID 与旧 com.example.misakafetch 测试包不同，可以并存，不自动删除旧包或迁移其私有设置。图片保存目录仍是 Pictures/MisakaFetch。未来版本保持应用 ID 和签名一致，递增 pubspec.yaml 的构建号。

## 验证范围

flutter analyze、259 个自动测试、原始封面真实下载及字节保存核验、Widget 深浅主题与多尺寸渲染检查已通过。Windows 已验证开发机 Release 启动。

Android 真机验证已完成。Windows Release 已通过开发机启动检查；干净系统与原生系统对话框的专项验收尚未完成。

发行附件上传至 GitHub Releases：Windows 完整运行目录 ZIP、项目签名 Android APK、SHA256SUMS.txt。源码仓库只保存开发所需文件，构建后输出位于 build/。当前应用 ID 为 app.misakafetch，Android 最低 API 24；项目签名 Release APK 已完成签名核验，Android 真机验证已完成。

发布标签与标题使用 `V1.0.0` / `MisakaFetch V1.0.0`，沿用现有标签。Git 标签区分大小写，不另建 `v1.0.0`。


## 发行附件检查

发布说明见 [V1.0.0](release-notes-1.0.0.md)。每次上传后，将 GitHub API 返回的附件 `digest` 与本地 SHA-256 比较；同时确认 SHA256SUMS.txt 中的文件名和散列匹配实际附件。未改变的安装包无需重建。
