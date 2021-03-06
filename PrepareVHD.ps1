﻿[CmdletBinding()]
param
(
    [string]
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("NativeBoot", "VirtualMachine")]
    $Usage = "NativeBoot",

    [string]
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("MBR", "GPT")]
    $VHDPartitionStyle = "MBR",

    [String]
    [Parameter(Mandatory = $false)]
    $ImagePath = "\\Vm-bj-fs01\b$\Image\2016\install.wim",

    [String]
    [Parameter(Mandatory = $false)]
    $VHDxPath = "D:\VHDBOOT",

    [String]
    [Parameter(Mandatory = $false)]
    $Differentiator = (get-date -format yyyyMMddss),

    [int64]
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(200GB, 40GB)]
    $size = 200GB,

    [String]
    [Parameter(Mandatory = $false)]
    $DriverPath,

    [String]
    [Parameter(Mandatory = $false)]
    $PackagePath,
    
    [string]
    [Parameter(Mandatory = $false)]
    $COMPUTERNAME,

    [String]
    [Parameter(Mandatory = $false)]
    $AdminPassword = "User@123",

    [String]
    [Parameter(Mandatory = $false)]
    $ProductKey = "74YFP-3QFB3-KQT8W-PMXWJ-7M648",

    [string]
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("ServerDataCenter", "ServerStandard", "Enterprise", "Professional", "Ultimate", "ServerDataCenterCore", "ServerStandardCore")]
    $Edition = "ServerDataCenter",
 
    [bool]
    [Parameter(Mandatory = $false)]
    $reboot = $true
)

if (!(Test-Path -Path $ImagePath))
{
    $ImagePath = Read-Host "Where is WIM image?"
    if (!(Test-Path -Path $ImagePath))
    {
        Write-Host "ERROR  : Can't find WIM image" -ForegroundColor Red
        Exit
    }
}

if (!(Test-Path -Path $VHDxPath))
{
    $VHDxPath = Read-Host "What directory do you want to put the VHDx?"
    if (!(Test-Path -Path $VHDxPath))
    {
        Write-Host "ERROR  : Can't find VHDx target location" -ForegroundColor Red
        Exit
    }
}

if ($DriverPath -ne "")
{
    if (!(Test-Path -Path $DriverPath))
    {
        $DriverPath = Read-Host "Driver path is not valid. Where is the location of the driver?"
        if (!(Test-Path -Path $DriverPath))
        {
            Write-Host "ERROR  : Can't find specified driver path." -ForegroundColor Red
            Exit
        }
    }
}

if ($PackagePath -ne "")
{
    if (!(Test-Path -Path $PackagePath))
    {
        $PackagePath = Read-Host "Package path is not valid. Where is the location of the packages?"
        if (!(Test-Path -Path $PackagePath))
        {
            Write-Host "ERROR  : Can't find specified package path." -ForegroundColor Red
            Exit
        }
    }
}

$ErrorActionPreference = 'Stop'

if ($COMPUTERNAME -eq "")
{
    if ($Usage -eq "NativeBoot")
    {
        if ($reboot -eq $true)
        {
            $COMPUTERNAME = HOSTNAME
            $MachineName = $COMPUTERNAME
        }
        else
        {
            $COMPUTERNAME = 'HOST'
            $MachineName = "*"
        }
    }
    else
    {
        $COMPUTERNAME = 'VM'
        $MachineName = "*"
    }
}
else
{
    $MachineName = $COMPUTERNAME
}

$VHDXFILE = Join-Path $VHDxPath $COMPUTERNAME'-'$Differentiator'.vhdx'

# Create VHD
$CreateVHDMessage = "Creating the new VHDX"
Write-Progress $CreateVHDMessage

# Load (aka "dot-source) the Function 
. $PSScriptRoot\Convert-WindowsImage.ps1 
# Prepare all the variables in advance (optional) 

$ConvertWindowsImageParam = @{  
    SourcePath          = $ImagePath  
    RemoteDesktopEnable = $True
    ExpandOnNativeBoot  = $false  
    Passthru            = $True  
    Edition             = $Edition    
    VHDPath             = $VHDXFILE 
    VHDFormat           = 'VHDX'
    SizeBytes           = $size
    BCDinVHD            = $Usage
    VHDPartitionStyle   = $VHDPartitionStyle
}

if ($DriverPath -ne "")
{
    $ConvertWindowsImageParam.Add("Driver",$DriverPath)
}

if ($PackagePath -ne "")
{
    $ConvertWindowsImageParam.Add("Package",$PackagePath)
}

$VHDx = Convert-WindowsImage @ConvertWindowsImageParam

Write-Progress $CreateVHDMessage -Completed

# Mount VHD
$MountVHDMessage = "Mounting the new created VHDX"
Write-Progress $MountVHDMessage
Dismount-DiskImage -ImagePath $VHDXFILE
Mount-DiskImage -ImagePath $VHDXFILE -StorageType vhdx -Access ReadWrite
$DriveLetter = (Get-DiskImage -ImagePath $VHDXFILE | Get-Disk | Get-Partition | Get-Volume).DriveLetter

Write-Progress $MountVHDMessage -Completed

Write-Host "INFO   : Computer Name will be"$MachineName -ForegroundColor Green
Write-Host "INFO   : Preparing Unattend File..."

# Get VHD Language and Architecture value from VHD
$VHDLanguage = 'EN-US'
$Architecture = 'AMD64'
$regSystemPath = $DriveLetter + ':\windows\system32\config\system'
Try
{
    reg load HKLM\SYSTEM_00 $regSystemPath
    $VHDLanguage = (Get-ChildItem -Path "HKLM:\SYSTEM_00\ControlSet001\Control\MUI\UILanguages").PSChildname
    $Architecture = (Get-ItemProperty -Path "HKLM:\SYSTEM_00\ControlSet001\Control\Session Manager\Environment").PROCESSOR_ARCHITECTURE
    [gc]::Collect()
    reg unload HKLM\SYSTEM_00
}
Catch
{
    $ErrorActionPreference = "Continue"
}

$ErrorActionPreference = 'Stop'

$UnattendedFilePath = Join-Path $PSScriptRoot "unattend_template.xml"

$UnattendedFile = (Get-Content $UnattendedFilePath)

$UnattendedFile = $UnattendedFile.Replace("%locale%", $VHDLanguage)
$UnattendedFile = $UnattendedFile.Replace("%Architecture%", $Architecture)
$UnattendedFile = $UnattendedFile.Replace("%ProductKey%", $ProductKey)
$UnattendedFile = $UnattendedFile.Replace("%adminpassword%", $AdminPassword)
$UnattendedFile = $UnattendedFile.Replace("%computername%", $MachineName)

$UnattendedFile | Out-File ($DriveLetter+":\unattend.xml") -Encoding ascii

Write-Host "INFO   : Unattend File is in position"

if ( ($Usage -eq "NativeBoot") -and ($reboot -eq $true)) 
{
    BCDBOOT.EXE $DriveLetter":\Windows"
    Dismount-DiskImage -ImagePath $VHDXFILE
    Restart-Computer    
}
else
{
    Dismount-DiskImage -ImagePath $VHDXFILE
    Write-Host "INFO   : VHDx File is ready:"$VHDXFILE -ForegroundColor Green
}
