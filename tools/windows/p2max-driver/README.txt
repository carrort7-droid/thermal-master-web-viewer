Thermal Master P2 MAX / P3 Lite —— Windows 一键驱动安装
=======================================================

前提：相机已插上，Windows 10 或 11（64 位）。

怎么用
------
双击 install.bat → UAC 点「是」→ 等十几秒 → 回到网页点 Connect camera。

不需要重启，不需要开 Test Mode，也不需要装官方软件。

它做了什么
----------
1. pnputil 先直接装一次（必然失败：厂商 INF 没有 .cat 签名目录）
2. dpscat.exe 依据 p2max.inf 现生成一个 p2max.cat
3. 用本机自签证书给 cat 签名，并把该证书导入 Root + TrustedPublisher
4. 再跑 pnputil /add-driver /install，这次系统接受
5. pnputil /scan-devices 触发重新枚举
6. 复查设备状态：Service = WinUSB，ProblemCode = 0

只改这一台机器的驱动绑定，不碰 Secure Boot、不动驱动签名策略、不影响其他 USB 设备。

文件
----
p2max.inf      把系统自带的 winusb.inf 绑定到 VID_3474&PID_42B2（只此一个设备）
dpscat.exe     由 INF 生成 catalog（微软 DIFx 工具，取自官方安装包）
install.ps1    安装器主体，含 -Verify / -Uninstall
install.bat    双击入口

排错
----
日志：C:\ProgramData\P2MaxDriver\install.log

只检查不安装：
    powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Verify

卸载：
    powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Uninstall

退出码：0 成功 / 1 失败 / 3 设备未插入
