# 固件需求单：P2 MAX / P3 Lite 增加 Microsoft OS 描述符（WCID）

**目的**：让 Windows 在相机首次插入时**自动安装 WinUSB 驱动**，实现"插上即用"——用户不装软件、不需管理员权限、不需任何设置。

---

## 1. 背景

网页版查看器（WebUSB）在 Windows 上有一个硬性前提：相机接口必须已绑定 **WinUSB** 驱动。
Chrome 官方文档明确：*"Windows 上打开 USB 设备不是默认能力，即使未加载任何驱动；必须加载 WinUSB，方式只有两种：安装 INF，或固件在枚举时提供 Microsoft OS 兼容描述符。"*

目前 P2 MAX 属于后者缺失，导致全新 Windows 上显示"未知设备（代码 28）"，用户必须先装驱动才能用。

---

## 2. 现状实测（2026-10-31，实机）

| 项目 | 实测值 |
| --- | --- |
| VID / PID | `0x3474` / **`0x42B2`** |
| 产品字符串 | `P2 MAX` |
| 固件版本 | `00.00.01.03` |
| 硬件版本 | `P2max-00.01` |
| `bcdUSB` | **`0x0200`** |
| `0xEE` 字符串（MS OS 1.0） | **不存在** |
| BOS 描述符（MS OS 2.0） | **不支持** |
| 接口布局 | IF0 `0xFF/0xF0/0x00`（EP `0x84` IN、`0x05` OUT）<br>IF1 alt1 `0xFF/0xF0/0x01`（EP `0x81` IN、`0x02` OUT） |

结论：两种 WCID 机制均未实现，Windows 因此不会自动装驱动。

---

## 3. 需要实现的内容（推荐 MS OS 1.0）

> 选 1.0 的原因：**不需要修改 `bcdUSB`**（保持 `0x0200` 即可），改动量最小；Windows 7 及以上均支持。

### 3.1 响应字符串描述符 `0xEE`

`GET_DESCRIPTOR(STRING, index=0xEE, langid=0x0000)` 返回 **18 字节**：

| 偏移 | 长度 | 值 |
| --- | --- | --- |
| 0 | 1 | `18`（bLength） |
| 1 | 1 | `0x03`（STRING） |
| 2 | 14 | `"MSFT100"`，**UTF-16LE** |
| 16 | 1 | `bVendorCode`：任选一个未使用的厂商请求码，例如 `0x01` |
| 17 | 1 | `0x00` |

### 3.2 响应厂商请求

`bmRequestType = 0xC0`、`bRequest = bVendorCode`、`wValue = 0x0000`、
`wIndex = 0x0004`（扩展兼容 ID）、`wLength = dwLength`

返回（共 40 字节：16 字节头 + 1×24 字节功能项）：

| 偏移 | 长度 | 值 |
| --- | --- | --- |
| 0 | 4 | `dwLength = 40` |
| 4 | 2 | `bcdVersion = 0x0100` |
| 6 | 2 | `wIndex = 0x0004` |
| 8 | 1 | `bCount = 1`（功能项个数） |
| 9 | 7 | 保留，全 `0x00` |
| 16 | 24 | 功能项（见下） |

功能项（24 字节）：

| 偏移 | 长度 | 值 |
| --- | --- | --- |
| +0 | 1 | `bFirstInterfaceNumber = 0` |
| +1 | 1 | 保留，`0x01` |
| +2 | 8 | `CompatibleID = "WINUSB\0\0"`（8 字节，NUL 补齐） |
| +10 | 8 | `SubCompatibleID`，全 `0x00` |
| +18 | 6 | 保留，全 `0x00` |

### 3.3 可选：扩展属性

同一厂商请求，`wIndex = 0x0005` 返回 `DeviceInterfaceGUIDs`。
绑 WinUSB 不强制，但若桌面端软件也要打开相机，建议一并实现。

### 3.4 不要改动接口布局

务必保持 IF0 `0xFF/0xF0`、端点 `0x84/0x05` 与 IF1 alt1 `0x81/0x02` 不变——上位机与网页均依赖该布局。

---

## 4. 验收标准

1. **描述符层**：运行验证工具，输出必须为
   ```
   MS OS 1.0 WINUSB: YES
   ```
   （工具：仓库内 `tools/probe-ms-os.py`，命令 `python tools/probe-ms-os.py`）

2. **干净 Windows**（未装过任何 Thermal Master 软件、未做过任何驱动绑定）插入相机：
   - 设备管理器**无黄色感叹号**
   - 驱动详情：`Service = WinUSB`，**`INF = winusb.inf`**（注意：不是 `oemXX.inf`）

3. **功能验证**：打开 <https://carrort7-droid.github.io/thermal-master-web-viewer/> → 点 Connect camera → 出现 256×192、25fps 热像画面。

---

## 5. 常见失败原因（排查清单）

| 现象 | 可能原因 |
| --- | --- |
| 工具显示 `no 0xEE string` | `0xEE` 字符串未实现，或 `langid` 不等于 `0x0000` 时未返回 |
| 工具显示 `compat ID request failed` | `bVendorCode` 与实际响应请求不一致；或 `wIndex` 不是 `0x0004` |
| 工具显示 `CompatibleID=''` | `"WINUSB"` 未按 8 字节 NUL 补齐，或大小写/编码错误 |
| 描述符有但 Windows 仍报错 | 复合设备（IAD）下 `bFirstInterfaceNumber` 填错，应填 `0` |
| 刚插入正常、重枚举后失效 | 描述符只在特定状态返回，需保证每次枚举都可用 |

---

## 6. 影响面评估

- **只影响 Windows 首次枚举时的驱动选择**，不改变 USB 接口、报文协议或数据格式。
- **Android / iOS / macOS / Linux 行为完全不变**（这些平台本就不需要该驱动）。
- **已装过驱动的机器不受影响**，仍使用原驱动。
- 上位机软件、网页查看器**均无需改动**。

---

## 7. 附：另一条可选路径（无需固件）

若固件排期较长，可先在 **官方 Windows 软件的驱动包**里补一行（已有的 `P3.cat` 等就是按 PID 生成的）：

```
DeviceID = "VID_3474&PID_42B2&MI_00"
```

用同样的自签方式重签即可（现有包也是 libwdi 自签，无需 WHQL）。
缺点：用户仍需安装/更新一次官方软件，不满足"零操作"目标。
