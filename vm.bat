@echo off
IF "%1"=="" (
    echo "USASE: on | off | set [FD image]"
    echo "Now setting is ..."
    powershell Get-VMFloppyDiskDrive PlejEta
) ELSE IF "%1"=="on" (
    powershell Start-VM -Name PlejEta
) ELSE IF "%1"=="off" (
    powershell Stop-VM -Name PlejEta
) ELSE IF "%1"=="set" (
    SETLOCAL enabledelayedexpansion
    set /p IMG="FD image name:"
    powershell Set-VMFloppyDiskDrive PlejEta %~dp0\!IMG!
    endlocal
)