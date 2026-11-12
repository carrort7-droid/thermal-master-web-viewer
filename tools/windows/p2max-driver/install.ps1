<#
  P2 MAX / P3 Lite — WinUSB 绑定安装器
  ------------------------------------
  把 Windows 自带的 WinUSB 绑定到 VID_3474&PID_42B2，让浏览器可以通过 WebUSB 打开相机。

  为什么需要签名：驱动包（INF）必须带一个 .cat 目录，否则 pnputil 会报
  「第三方 INF 不包含数字签名信息」。厂商包里没有 .cat，所以这里现场生成一个，
  用本机自签证书签名并信任 —— 这比开 Test Mode 安全，也不需要重启。

  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
    powershell ... -File install.ps1 -Verify      # 只看状态，不改系统
    powershell ... -File install.ps1 -Uninstall   # 卸载

  退出码：0 成功 / 1 失败 / 3 设备未插入
#>
[CmdletBinding()]
param(
  [switch]$Verify,
  [switch]$Uninstall,
  [switch]$NoElevate
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$Here     = $PSScriptRoot
$InfPath  = Join-Path $Here 'p2max.inf'
$Dpscat   = Join-Path $Here 'dpscat.exe'
$WorkDir  = Join-Path $env:ProgramData 'P2MaxDriver'
$Stage    = Join-Path $WorkDir 'stage'
$LogFile  = Join-Path $WorkDir 'install.log'
$DevMatch = 'USB\VID_3474&PID_42B2*'
$CertName = 'CN=P2Max WinUSB Signer (local)'

function Log {
  param([string]$Text, [string]$Level = 'INFO')
  $line = '[{0}] {1,-4} {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Text
  Write-Host $line
  if (Test-Path $WorkDir) { Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8 }
}

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-State {
  $rows = @()
  foreach ($d in (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
                  Where-Object { $_.InstanceId -like $DevMatch })) {
    $svc = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue).Data
    $prb = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction SilentlyContinue).Data
    $rows += [pscustomobject]@{ Id = $d.InstanceId; Status = [string]$d.Status; Service = [string]$svc; Problem = $prb }
  }
  return $rows
}

function Test-Ready {
  param($Rows)
  $f = $Rows | Where-Object { $_.Id -like '*MI_00*' } | Select-Object -First 1
  if (-not $f) { return $false }
  return ($f.Service -eq 'WINUSB' -and $f.Problem -eq 0)
}

function Show-State {
  param($Rows)
  if (-not $Rows -or $Rows.Count -eq 0) { Log '没有找到 VID_3474&PID_42B2 设备（相机没插上？）' 'ERR'; return }
  foreach ($r in $Rows) {
    $s = if ($r.Service) { $r.Service } else { '(无)' }
    Log ("{0}  Status={1}  Service={2}  Problem={3}" -f $r.Id, $r.Status, $s, $r.Problem)
  }
}

function Invoke-Cmd {
  param([string]$Exe, [string[]]$Args, [string]$Tag)
  Log "[$Tag] $(Split-Path -Leaf $Exe) $($Args -join ' ')"
  $out  = & $Exe @Args 2>&1 | Out-String
  $code = $LASTEXITCODE
  foreach ($l in ($out -split "`r?`n")) { if ($l.Trim()) { Log "    $($l.Trim())" 'TOOL' } }
  Log "[$Tag] 退出码: $code"
  return $code
}

# ---------------------------------------------------------------- 提权
# -Verify 只读，不需要提权；安装与卸载需要
if (-not $Verify) {
  if (-not (Test-Admin) -and -not $NoElevate) {
    Write-Host '需要管理员权限，正在请求提升…'
    $argline = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
    if ($Verify)    { $argline += ' -Verify' }
    if ($Uninstall) { $argline += ' -Uninstall' }
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argline -Verb RunAs -Wait -PassThru
    exit $p.ExitCode
  }
}

if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force -ErrorAction SilentlyContinue | Out-Null }

$state = Get-State

# ---------------------------------------------------------------- 只读
if ($Verify) {
  Show-State $state
  if (Test-Ready $state) {
    Log '驱动已就绪：设备绑定 WinUSB，无错误码。' 'OK'
    Write-Output ('RESULT: ' + (@{ ready = $true } | ConvertTo-Json -Compress))
    exit 0
  }
  Log '驱动未就绪。' 'ERR'
  Write-Output ('RESULT: ' + (@{ ready = $false } | ConvertTo-Json -Compress))
  exit 1
}

# ---------------------------------------------------------------- 卸载
if ($Uninstall) {
  Log '查找已发布的驱动包…'
  $target = $null
  foreach ($b in ((& pnputil.exe /enum-drivers 2>&1 | Out-String) -split "(`r?`n){2,}")) {
    if ($b -match 'p2max') { $m = [regex]::Match($b, 'oem\d+\.inf'); if ($m.Success) { $target = $m.Value; break } }
  }
  if (-not $target) { Log '没找到已安装的驱动包。' 'WARN'; exit 0 }
  Log "卸载 $target"
  Invoke-Cmd 'pnputil.exe' @('/delete-driver', $target, '/uninstall', '/force') 'DEL' | Out-Null
  Log '已卸载，请拔插设备。' 'OK'
  exit 0
}

# ---------------------------------------------------------------- 安装
try {
  Log "=== 开始安装 ($(Get-Date -Format s)) ==="

  if (-not (Test-Path $InfPath)) { Log "找不到 $InfPath" 'ERR'; exit 1 }
  if (-not $state -or $state.Count -eq 0) { Log '设备未插入：请先插上相机再运行。' 'ERR'; exit 3 }
  if (Test-Ready $state) { Log '驱动已就绪，无需安装。' 'OK'; exit 0 }

  # 1) 暂存：INF 必须和 .cat 同目录
  if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
  New-Item -ItemType Directory -Path $Stage -Force | Out-Null
  Copy-Item -LiteralPath $InfPath -Destination $Stage
  $stageInf = Join-Path $Stage 'p2max.inf'
  $cat      = Join-Path $Stage 'p2max.cat'
  Log "暂存目录: $Stage"

  # 2) 阶段 A：直接装（缺 cat 会明确报「不包含数字签名信息」）
  Log '--- 阶段 A：pnputil 直接安装 ---'
  Invoke-Cmd 'pnputil.exe' @('/add-driver', $stageInf, '/install') 'A' | Out-Null
  Start-Sleep -Seconds 2
  $state = Get-State
  Show-State $state

  # 3) 阶段 B：生成 cat → 自签 → 信任 → 重装
  if (-not (Test-Ready $state)) {
    Log '阶段 A 未通过（预期：缺签名目录），生成并自签 catalog。' 'WARN'

    if (Test-Path $Dpscat) {
      if (Test-Path $cat) { Remove-Item -LiteralPath $cat -Force }
      Push-Location $Stage
      try { Invoke-Cmd $Dpscat @('/PATH', $Stage) 'CAT' | Out-Null } catch { Log "dpscat: $($_.Exception.Message)" 'WARN' }
      Pop-Location
    } else {
      Log "缺少 dpscat.exe，无法生成 catalog。" 'ERR'
    }

    if (Test-Path $cat) {
      Log "已生成 catalog: $cat" 'OK'

      $cert = Get-ChildItem Cert:\LocalMachine\My |
              Where-Object { $_.Subject -eq $CertName } | Select-Object -First 1
      if (-not $cert) {
        Log '创建本机自签代码签名证书…'
        $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $CertName `
                  -CertStoreLocation 'Cert:\LocalMachine\My' `
                  -NotAfter (Get-Date).AddYears(10) -KeyUsage DigitalSignature
      }
      $cer = Join-Path $Stage 'signer.cer'
      Export-Certificate -Cert $cert -FilePath $cer -Force | Out-Null
      foreach ($store in 'Root', 'TrustedPublisher') {
        Import-Certificate -FilePath $cer -CertStoreLocation "Cert:\LocalMachine\$store" | Out-Null
      }
      Log '证书已导入 Root / TrustedPublisher'

      try {
        $sig = Set-AuthenticodeSignature -FilePath $cat -Certificate $cert -HashAlgorithm SHA256
        Log "catalog 签名状态: $($sig.Status)"
      } catch {
        Log "签名失败: $($_.Exception.Message)" 'WARN'
      }

      Log '--- 阶段 B：pnputil 带签名重装 ---'
      Invoke-Cmd 'pnputil.exe' @('/add-driver', $stageInf, '/install') 'B' | Out-Null
      Invoke-Cmd 'pnputil.exe' @('/scan-devices') 'RESCAN' | Out-Null
      Start-Sleep -Seconds 3
      $state = Get-State
      Show-State $state
    }
  }

  # 4) 终验
  if (Test-Ready $state) {
    Log '安装成功：设备已绑定 WinUSB，ProblemCode = 0。' 'OK'
    Log '回到网页点 Connect camera 即可。' 'OK'
    Write-Output ('RESULT: ' + (@{ ready = $true } | ConvertTo-Json -Compress))
    exit 0
  }

  Log '仍未就绪。请拔插一次设备后重跑；若仍失败，把 install.log 发出来。' 'ERR'
  Write-Output ('RESULT: ' + (@{ ready = $false } | ConvertTo-Json -Compress))
  exit 1
}
catch {
  Log "异常: $($_.Exception.Message)" 'ERR'
  Log $_.ScriptStackTrace 'ERR'
  exit 1
}
