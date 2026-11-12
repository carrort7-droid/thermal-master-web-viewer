# Checks whether a Thermal Master camera on this PC can be used by the web
# viewer, and where its driver came from.
#
#     powershell -ExecutionPolicy Bypass -File tools\windows\check-driver.ps1
#
# Read-only: it changes nothing. Requires no admin rights.

$ErrorActionPreference = "SilentlyContinue"

$devices = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like "*VID_3474*" }

if (-not $devices) {
    Write-Output "NO CAMERA FOUND"
    Write-Output ""
    Write-Output "No device with vendor id 3474 is connected."
    Write-Output "Plug the camera in and run this again."
    exit 1
}

$anyReady = $false

foreach ($d in $devices | Sort-Object InstanceId) {
    $id     = $d.InstanceId
    $svc    = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_Service).Data
    $inf    = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_DriverInfPath).Data
    $prov   = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_DriverProvider).Data
    $ver    = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_DriverVersion).Data
    $prob   = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_ProblemCode).Data

    $pid = "unknown"
    if ($id -match 'PID_([0-9A-Fa-f]{4})') { $pid = $Matches[1].ToUpper() }

    $ready = ($svc -eq "WinUSB")
    if ($ready) { $anyReady = $true }

    Write-Output "------------------------------------------------------------"
    Write-Output ("Device   : " + $d.FriendlyName)
    Write-Output ("PID      : " + $pid)
    Write-Output ("Service  : " + $(if ($svc) { $svc } else { "<none>" }))
    Write-Output ("Driver   : " + $(if ($inf) { $inf } else { "<none>" }) + "  (" + $(if ($prov) { $prov } else { "-" }) + " " + $(if ($ver) { $ver } else { "" }) + ")")
    Write-Output ("Problem  : " + $(if ($null -ne $prob) { $prob } else { "0" }))

    if ($ready) {
        $origin = switch -Wildcard ($prov) {
            "libwdi"   { "installed by a third-party tool (libwdi)" }
            "Microsoft" { "vendor driver package or Windows inbox" }
            default    { "third-party package" }
        }
        Write-Output ("RESULT   : READY - the web viewer can open this camera  [" + $origin + "]")
    }
    elseif ($prob -eq 28) {
        Write-Output "RESULT   : NOT READY - no driver installed (code 28)"
        Write-Output "           Install the official Thermal Master Windows software,"
        Write-Output "           or run tools\windows\p2max-driver\install.bat. See docs/windows-zero-setup.md."
    }
    else {
        Write-Output "RESULT   : NOT READY - driver present but not WinUSB"
        Write-Output "           Run tools\windows\p2max-driver\install.bat to rebind it to WinUSB."
    }
    Write-Output ""
}

Write-Output "============================================================"
if ($anyReady) {
    Write-Output "SUMMARY  : at least one camera can be used right now."
} else {
    Write-Output "SUMMARY  : none of the connected cameras can be opened yet."
    Write-Output "           The page will open fine, but 'Connect camera' will list nothing."
}
Write-Output ""
Write-Output "Model ids: P1=45C2  P2=4281  P3=45A2  P4=42A1  P2 Max=42B2"
