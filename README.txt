Devin Agent 界面简体中文汉化包
================================

用法
----
双击运行「一键汉化.bat」即可。脚本会自动:
  1. 找到 Devin 安装目录(默认 E:\Devin,也探测 C/D 盘和
     %LOCALAPPDATA%\Programs\Devin)
  2. 复制 zh-CN-translation.js / zh-CN-review.js 到 assets
  3. 在入口 bundle 的语言列表注册 zh(中文(简体))
  4. 补丁 index bundle:zh 语言跳过云端保存(服务端不认 zh),
     改用 localStorage 持久化

然后重启 Devin(或 Ctrl+Shift+P -> Developer: Reload Window),
在设置/命令面板的语言选项里选「中文(简体)」。

特性
----
* 幂等:重复运行会自动跳过已补丁部分,不会重复写入
* 自动备份:首次补丁前把原文件存为 *.js.zhorig
* 抗更新:补丁按代码结构定位(不依赖文件哈希),Devin 升级
  覆盖文件后重跑一次「一键汉化.bat」即可恢复
* 本包可放任意位置(桌面/U盘),脚本用自身目录定位资源
* Devin 安装路径自动探测,优先级:
    1) -AssetsDir 手动指定
    2) 常见安装目录(E:\、%LOCALAPPDATA%\Programs\、Program Files、D:\、C:\)
    3) 正在运行的 Devin.exe 进程路径反推
    4) 注册表卸载条目的安装位置
  探测全部失败时手动指定:
    powershell -File apply-zh.ps1 -AssetsDir "D:\...\assets"

还原
----
双击「还原英文.bat」:把 .zhorig 备份盖回原文件并删除 zh chunk,
重启 Devin 即恢复出厂状态。

文件清单
--------
一键汉化.bat      - 应用汉化(双击)
还原英文.bat      - 还原原始英文(双击)
apply-zh.ps1      - 汉化补丁脚本
restore-zh.ps1    - 还原脚本
zh-CN-translation.js - 主界面中文资源(20,190 条,全量)
zh-CN-review.js      - Review 界面中文资源(1,160 条,全量)
