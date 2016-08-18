# PrepareVHD
Customize and Create bootable VHD for Physical Machine and Virtual Machine

##List of Parameters

Usage: Use for native boot or virtual machine

    [String]
    
    Mandatory: false
    
    Accept Value: NativeBoot, VirtualMachine
    
    Default Value: NativeBoot


VHDPartitionStyle: MRR or GPT (G1 VM or G2 VM)

    [String]
    
    Mandatory: false
    
    Accept Value: MBR, GPT
    
    Default Value: MBR
    

ImagePath: Full path of the WIM image

    [String]
    
    Mandatory: false
    
    Default Value: "\\Vm-bj-fs01\b$\Image\2016\install.wim"
    

VHDxPath: The target location of the new created VHDx

    [String]
    
    Mandatory: false
    
    Default Value: "D:\VHDBOOT"
    

Differentiator: Use as suffix in the file name of new created VHDx.

    [String]
    
    Mandatory: false
    
    Default Value: (get-date -format yyyyMMddss)
    

Size:  Size of the VHDx

    [int64]
    
    Mandatory: false
    
    Accept Value: 200GB, 40GB
    
    Default Value: 200GB
    

DriverPath: The location of the Driver (Optional)

    [String]
    
    Mandatory: false
    
    Default Value: None
    

ComputerName: Computer name of host or virtual machine

    [string]
    
    Mandatory: false
    
    Default Value: None
    

AdminPassword: The password of the local administrator

    [String]
    
    Mandatory: false
    
    Default Value: User@123
    

ProductKey: The product key (Optional)

    [String]
    
    Mandatory: false
    
    Default Value: 74YFP-3QFB3-KQT8W-PMXWJ-7M648
    

Edition: The edition of the OS

    [string]
    
    Mandatory: false
    
    Accept Value: ServerDataCenter, ServerStandard, Enterprise, Professional, Ultimate, ServerDataCenterCore, ServerStandardCore
    
    Default Value: ServerDataCenter
    

Reboot: Add a new boot entry and reboot or not.

    [bool]
    
    Mandatory: false
    
    Default Value: $true
    
    
## Examples:
.\PrepareVHD.ps1 -ImagePath I:\sources\install.wim -VHDxPath F:\VHDBOOT -Differentiator WIN10G2 -Edition Enterprise

.\PrepareVHD.ps1 -ImagePath K:\sources\install.wim -VHDxPath F:\ -VHDPartitionStyle GPT -Usage VirtualMachine -Differentiator WS2012R2G2 -size 40GB -DriverPath "S:\_Drivers\HP\C7000\C7000 NIC" -COMPUTERNAME TESTVM1 -AdminPassword pass@word1 -Edition ServerStandardCore

