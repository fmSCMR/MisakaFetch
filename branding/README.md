# MisakaFetch 图标

图标源文件：icon-square.jpg 为方形原图，icon-rounded.jpg 为圆角版本。平台资源通过格式转换和尺寸缩放生成，不添加运行时依赖。

- Windows 程序和辅助启动器：圆角版本，ICO 包含 16、24、32、48、64、128、256 像素帧。
- Android 7：方形版本，各密度 48 / 72 / 96 / 144 / 192 像素。
- Android 8+：方形版本加白色背景的自适应图标，前景留出遮罩安全区域，由系统决定最终圆形或圆角外形。规范见 https://developer.android.com/develop/ui/compose/system/icon_design_adaptive。

在源码根目录执行 powershell -ExecutionPolicy Bypass -File tool/generate_app_icons.ps1 可重新生成资源；然后分别构建 Windows / Android Release，并执行 tool/create_windows_launcher.ps1 更新辅助启动器。

源图片为 JPEG，没有透明通道，保留其白色背景及圆角图的阴影。icon-preview.png 是圆角素材的 256 像素预览，不是应用截图。
