# Devin Agent 界面简体中文汉化包

非官方简体中文语言包，为 **Devin Desktop**（Windows 桌面端）的 Agent 界面提供全量中文翻译。

- 主界面翻译资源 **20,190 条**（`zh-CN-translation.js`）
- Review 界面翻译资源 **1,160 条**（`zh-CN-review.js`）
- 一键安装 / 一键还原，自动备份原始文件

## 效果截图

语言选项中注册并选中「中文(简体)」：

![语言选择器](screenshots/language-picker.png)

侧边栏导航全面中文化：

![侧边栏导航](screenshots/sidebar-nav.png)

主界面页面中文化（自动化页示例）：

![自动化页面](screenshots/automation-page.png)

## 使用方法

1. 下载本仓库（或 [Releases](../../releases) 中的 zip 包）并解压到任意位置（桌面、U 盘均可）。
2. 双击运行 **`一键汉化.bat`**，脚本会自动：
   1. 探测 Devin 安装目录
   2. 复制 `zh-CN-translation.js` / `zh-CN-review.js` 到 assets 目录
   3. 在入口 bundle 的语言列表中注册 `zh`（中文(简体)）
   4. 补丁 index bundle：`zh` 语言跳过云端保存（服务端语言枚举不含 `zh`），改用 `localStorage` 持久化
3. 重启 Devin（或 `Ctrl+Shift+P` → `Developer: Reload Window`）。
4. 在命令面板执行 `配置显示语言 / Configure Display Language`，选择 **中文(简体)**。

自动探测失败时手动指定 assets 目录：

```powershell
powershell -File apply-zh.ps1 -AssetsDir "D:\...\devin-webapp-host\assets"
```

## 还原英文

双击 **`还原英文.bat`**：将 `.zhorig` 备份盖回原文件并删除 `zh-CN-*.js` chunk，重启 Devin 即恢复出厂状态。

## 特性

- **幂等**：重复运行自动跳过已补丁部分，不会重复写入
- **自动备份**：首次补丁前把原文件保存为 `*.js.zhorig`
- **抗更新**：补丁按代码结构定位（不依赖文件哈希），Devin 升级覆盖文件后重跑一次 `一键汉化.bat` 即可恢复
- **任意位置运行**：脚本以自身所在目录定位资源，无需放进安装目录
- **安装路径自动探测**，优先级：
  1. `-AssetsDir` 手动指定
  2. 常见安装目录（`E:\`、`%LOCALAPPDATA%\Programs\`、`Program Files`、`D:\`、`C:\`）
  3. 正在运行的 `Devin.exe` 进程路径反推
  4. 注册表卸载条目的安装位置

## 工作原理

补丁针对 `resources\app\out\vs\workbench\devin-webapp-host\assets` 下的前端 bundle：

1. **拷贝语言 chunk**：把两个 `zh-CN-*.js` 翻译资源放入 assets，并追加到 `entry-host-editor-mode-menu-*.js` 的 `m.f` 依赖表与 `__vite__mapDeps`。
2. **注册语言项**：克隆语言列表中最后一个条目改写为 `{code:'zh', label:'中文(简体)'}`。
3. **写路径补丁**：`PUT users/ui-language` 对 `zh` 直接本地返回（服务端枚举不认 `zh`，否则会保存失败）。
4. **读路径补丁**：`GET users/ui-language` 对 `zh` 优先读 `localStorage['devin-language']`，避免启动时被服务端返回的 `en` 覆盖。

## 文件清单

| 文件 | 说明 |
| --- | --- |
| `一键汉化.bat` | 应用汉化（双击） |
| `还原英文.bat` | 还原原始英文（双击） |
| `apply-zh.ps1` | 汉化补丁脚本 |
| `restore-zh.ps1` | 还原脚本 |
| `zh-CN-translation.js` | 主界面中文资源（20,190 条，全量） |
| `zh-CN-review.js` | Review 界面中文资源（1,160 条，全量） |
| `README.txt` | 包内说明 |

## 注意事项

- 本项目为第三方非官方补丁，与 Cognition / Devin 官方无关。
- 补丁会修改本地安装文件，使用前请知悉风险；`.zhorig` 备份可完全还原。
- Devin 版本更新后若入口 bundle 结构变化，补丁脚本可能提示「版本可能已变化」，需要更新补丁逻辑。
- 翻译文件较大（约 1 MB），首次加载语言时可能稍慢。
