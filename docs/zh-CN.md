# 使用说明（中文）

这是 **Thermal Master Web Viewer** —— 一个网页版热像仪查看器。
不用装软件，打开网页、插上相机、点一下连接就能看画面。

> 非官方项目，与 Thermal Master 无隶属关系。

## 三步使用

1. 用 **Chrome / Edge** 打开：
   `https://carrort7-droid.github.io/thermal-master-web-viewer/`
2. 把相机插到电脑（或手机的 USB-C 口）
3. 点 **Connect camera** → 在弹窗里选中相机

> 必须用 Chrome / Edge。Firefox、Safari 不支持 WebUSB。

## 各系统能不能直接用

| 系统 | 插上就能用？ | 说明 |
|---|---|---|
| 安卓手机 | ✅ 是 | 插 USB-C 直接开网页即可 |
| macOS | ✅ 是 | 免驱 |
| Windows（装过官方软件） | ✅ 是 | 驱动随官方软件装好了 |
| Windows（全新系统） | ❌ 否 | 需要一次性装驱动，见下 |
| iPhone / iPad | ❌ 不支持 | Safari 没有 WebUSB |

## Windows 为什么要折腾驱动

相机不是普通摄像头，它走的是厂商自定义接口。浏览器要访问这种接口，
系统里必须已经装好 **WinUSB** 驱动。

**网页本身装不了驱动** —— 这是浏览器的安全限制，不是本项目的问题。
所以全新 Windows 上第一次用，需要一次性把驱动装好。

### 先自检：10 秒知道缺不缺

插上相机，在项目目录里运行：

```powershell
powershell -ExecutionPolicy Bypass -File tools\windows\check-driver.ps1
```

- 输出 **`RESULT : READY`** → 可以直接用
- 输出 **`NOT READY ... code 28`** → 缺驱动，往下看

### 装驱动的三条路（按推荐排序）

**1. 装一次官方 Windows 软件（最省事）**
官方软件自带签名驱动包，装完以后所有型号插上自动生效，网页版也能直接用。

**2. 跑一次仓库里的安装脚本（不用装官方软件）**

下载 `web/driver/p2max-setup.bat`，双击，UAC 点「是」。
脚本会生成并自签 catalog 再绑定 WinUSB —— 不用开 Test Mode，不用重启。

**3. 让研发把 PID 加进驱动包（一劳永逸）**
驱动包是按 PID 匹配的，新型号必须加一行才会被覆盖。
详见 [windows-zero-setup.md](windows-zero-setup.md)。

## 型号与 PID 对照

| 型号 | PID | 分辨率 | 状态 |
|---|---|---|---|
| P1 | `45C2` | 160×120 | 可用 |
| P2 | `4281` | 256×192 | 可用 |
| P3 | `45A2` | 256×192 | 可用 |
| P4 | `42A1` | 256×192 | 可用 |
| **P2 Max** | `42B2` | 256×192 | 已实测 25 fps |

> 驱动包是按 **PID** 匹配的，和型号名、固件里显示的名字无关。
> 即便把设备名改成别的（例如 P3 LITE），只要 PID 一样，照样能识别。

## 常见问题

**点 Connect 后列表是空的**
Windows 缺驱动。跑上面的自检脚本确认，然后按三条路装驱动。

**画面一片灰**
正常现象。房间温度本来就均匀，对着发热的物体或切换到手动量程试试。

**每 90 秒"咔"一声**
机械快门在做非均匀性校正，正常。点 **Shutter** 可以手动触发。

**打不开页面**
先确认用的是 Chrome / Edge；再按 `Ctrl + F5` 强制刷新（新部署常被缓存）。
