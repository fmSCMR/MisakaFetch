# MisakaFetch V1.0.0

Bilibili 视频封面提取器，支持 Windows 和 Android。

## 功能

- 识别视频链接、BV 号、分享文本和 Bilibili 短链接。
- 展示公开视频信息，预览并保存原始封面，复制图片链接。
- 支持浅色、深色主题、自定义背景和保存设置。
- 关于页面可打开 GitHub 项目。

## 下载与使用

- Windows 10/11 x64：下载 `MisakaFetch-V1.0.0-Windows-x64.zip`，完整解压后进入 Windows 文件夹运行 MisakaFetch.exe。保留所有 DLL 和 data。
- Windows 需要 Microsoft Visual C++ x64 运行库。如提示缺少 MSVCP140 或 VCRUNTIME140，安装 [微软官方运行库](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)。
- Android 7.0 及以上：下载 `MisakaFetch-V1.0.0.apk` 安装。应用 ID 为 app.misakafetch，使用项目专用发布签名；后续覆盖更新须沿用应用 ID 和签名。
- `SHA256SUMS.txt` 提供两个安装包的 SHA-256。校验时使用完整文件名。

## 验证与限制

- 静态分析与 259 项自动测试通过；Windows 已通过开发机启动检查，Android 真机验证已完成。
- Windows 干净系统兼容性尚未专项验证，EXE 未配置代码签名。
- Bilibili 公开接口可能变化或限流；封面清晰度取决于公开返回的原图。

应用仅访问公开视频信息与封面，不提供登录、访问限制绕过或视频、音频下载。封面权利归原权利人，项目 MIT 许可证不授予封面的使用权。本项目与 Bilibili 无官方关联。

问题反馈请使用仓库 Issues，提供应用版本、平台和复现步骤；勿附密码、签名密钥或私人图片。
