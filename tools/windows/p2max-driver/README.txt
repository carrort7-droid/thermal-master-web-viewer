P2 Max / P3 Lite — Windows 一键驱动（让网页点 Connect 就能用）
==============================================================

为什么需要这一步
----------------
WebUSB 在 Windows 上必须先把“WinUSB”驱动绑到设备，浏览器才看得见它。
你的 P3 之所以插上就用，是因为官方软件已经用自签驱动把 P3 绑好了；
P2 Max（硬件 ID：VID_3474&PID_42B2）当时不在那个包里，所以只差这一下绑定。
绑完之后是永久的：插上 → 开网页 → 点 Connect，结束。

怎么装（二选一，都只要一次）
----------------------------

方法一（推荐，双击即可）
  1. 把 P2 Max / P3 Lite 插上电脑。
  2. 右键 install.bat → “以管理员身份运行”。
  3. 看到 SUCCESS 就完事。打开网页点 Connect 即可。
  如果你的机器弹出“驱动未签名”警告（说明没开测试模式），
  先跑一次 enable-testmode.bat，重启，再跑 install.bat。

方法二（Zadig，100% 稳）
  打开 Zadig → 选 P2 Max → 选 WinUSB → 点 Install/Replace。一分钟，无需重启。

装完验证
--------
管理员 PowerShell 跑：
  powershell -ExecutionPolicy Bypass -File ..\check-driver.ps1
看到 “RESULT : READY - the web viewer can open this camera” 即可。

之后
----
每次插上设备，Windows 会自动绑 WinUSB，网页点 Connect 直接连，
不用再装任何东西、不用找人、不用改固件。
