[CmdletBinding()]
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

function Get-Script-Directory
{
    $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value
    return Split-Path $scriptInvocation.MyCommand.Path
}


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
    $VHDxPath = Read-Host "What directory do you want to put the VHDx"
    if (!(Test-Path -Path $VHDxPath))
    {
        Write-Host "ERROR  : Can't find VHDx target location" -ForegroundColor Red
        Exit
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

$ScriptPath = Get-Script-Directory

# Load (aka "dot-source) the Function 
. $ScriptPath\Convert-WindowsImage.ps1 
# Prepare all the variables in advance (optional) 

if ($DriverPath -eq "")
{
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
}
else
{
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
        Driver              = $DriverPath
        VHDPartitionStyle   = $VHDPartitionStyle
    } 
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
$VHDLanguage = 'en-us'
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

$UnattendedFilePath = ".\unattend_template.xml"

$UnattendedFile = (Get-Content $UnattendedFilePath)

$UnattendedFile = $UnattendedFile -replace "%locale%", $VHDLanguage
$UnattendedFile = $UnattendedFile -replace "%Architecture%", $Architecture
$UnattendedFile = $UnattendedFile -replace "%ProductKey%", $ProductKey
$UnattendedFile = $UnattendedFile -replace "%adminpassword%", $AdminPassword
$UnattendedFile = $UnattendedFile -replace "%computername%", $MachineName

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

