# Third-Party Notices

本仓库/安装包包含以下第三方组件，版权与许可证归各自权利人所有：

## 应用图标（原创）

本项目图标为**原创设计**（终端提示符图形），版权归本项目贡献者所有，
随仓库 MIT 许可证发布，不包含任何第三方商标元素。

## Microsoft WebView2 SDK

`client/WebView2/Microsoft.Web.WebView2.Core.dll`、
`client/WebView2/Microsoft.Web.WebView2.WinForms.dll`
取自 NuGet 包 `Microsoft.Web.WebView2`，
`WebView2Loader.dll` 为官方再分发件。
**许可证全文随包附于 `client/WebView2/LICENSE.txt`**（MIT 风格，
含再分发条款）。WebView2 运行时由安装包通过微软官方 Evergreen
引导器安装（引导器按微软官方分发指引随包提供）。
微软商标与版权归 Microsoft Corporation 所有。

## Node.js

安装包内嵌 Node.js 官方便携版（构建时从 nodejs.org 或 npmmirror 下载，
解压自带 LICENSE 文件随包分发），遵循 Node.js 自身许可证。

## DeepSeek Harness（@deepseek-ai/* 发布包）

安装包载荷来自 DeepSeek Harness 官方发布 tarball（npm 打包产物，
每个包自带 LICENSE），许可证：MIT。
项目主页：https://github.com/deepseek-ai/deepseek-harness

> 注意：本项目**不含** DeepSeek 的商标标识（鲸鱼 Logo）。
> "DeepSeek Harness" 仅为说明性引用（nominative use），
> 本项目与其无隶属、赞助或背书关系。

## 社区插件

安装器 profile 模板默认安装 `dshmarket`（MIT），
其市场内其他插件由各自作者维护，遵循各自许可证。

## 7-Zip SFX

构建产物使用 7-Zip 的 7zS2.sfx 模块（Igor Pavlov，Public domain）。
构建脚本从 7-zip.org 官方站点下载。
