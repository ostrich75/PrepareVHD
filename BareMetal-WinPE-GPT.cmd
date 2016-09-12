@echo off
@echo.
@echo -------------------------------------------------------------------
@echo This script only used to prepare a bare-metal machine and boot from an existing VHD
@echo -------------------------------------------------------------------

set basepath=%~dp0
goto menu

:menu
cls
echo.
echo. 
echo. *********** Please choose copying vhd file from network or local *********************
echo.
echo. 1: Copy VHD from Network
echo. 2: Copy VHD from Local Drive
echo.
echo. **************************************************************************************
echo.

set choice=
set /p choice= Please Choose:
IF NOT "%Choice%"=="" SET Choice=%Choice:~0,1%
if /i "%choice%"=="1" goto NetworkVHD
if /i "%choice%"=="2" goto LocalVHD
echo.
echo. Please input with 1 or 2!
echo.
goto menu 



:NetworkVHD
@echo.
@echo Please input source VHD path (Like \\vm-bj-fs01\b$\VHDBOOT\NANO.vhdx) ...
set /p VHDPath=
@echo.
@echo Please input username to access the above location  ...
set /p username=
@echo.
@echo Please input password of the above user ...
set /p password=
@echo.
for /f "tokens=1,2 delims=\" %%a in ("%vhdpath%") do set servername=%%a
set "unc=\\%servername%"
goto PrepareDisk

:LocalVHD
@echo.
@echo Please input source VHD path (Like X:\WSSCPOC\VHDBOOT\NANO.vhdx) ...
set /p VHDPath=
goto PrepareDisk

:PrepareDisk
@echo Display Disks of the System
@echo list disk > %Temp%\system_disks.txt
@echo exit >> %Temp%\system_disks.txt
diskpart /s %Temp%\system_disks.txt

:bootdisk
@echo "Please choose a Disk Number for Booting VHD, This should be default UEFI bootable disk e.g. input 0 for disk 0!"
set /p bootdisk=
if not defined bootdisk goto bootdisk

@echo select disk %bootdisk% > %TEMP%\prepare_disk.txt
@echo clean >> %TEMP%\prepare_disk.txt
@echo convert gpt >> %TEMP%\prepare_disk.txt

rem == 1. Windows RE tools partition ===============
@echo create partition primary size=500 >> %TEMP%\prepare_disk.txt
@echo format quick fs=ntfs label="Windows RE tools" >> %TEMP%\prepare_disk.txt
@echo assign letter=T >> %TEMP%\prepare_disk.txt
@echo set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac" >> %TEMP%\prepare_disk.txt
@echo gpt attributes=0x8000000000000001 >> %TEMP%\prepare_disk.txt

rem == 2. System partition =========================
@echo create partition efi size=100 >> %TEMP%\prepare_disk.txt
rem == Note: for Advanced Format Generation One drives, change to size=260.
@echo format quick fs=fat32 label="System" >> %TEMP%\prepare_disk.txt
@echo assign letter=S >> %TEMP%\prepare_disk.txt

rem == 3. Microsoft Reserved (MSR) partition =======
@echo create partition msr size=128 >> %TEMP%\prepare_disk.txt

rem == 4. Windows partition ========================
@echo create partition primary >> %TEMP%\prepare_disk.txt
@echo format fs=ntfs quick label=DATA >> %TEMP%\prepare_disk.txt
@echo assign letter=N >> %TEMP%\prepare_disk.txt

diskpart /s %TEMP%\prepare_disk.txt
if %errorlevel% neq 0 echo prepared disk failed! abort... && goto eof 

@echo ====            Copy VHD             =======
md N:\VHDBOOT
if /i "%choice%"=="2" goto COPYVHD
net use %unc% /user:%username% %password%

:COPYVHD
copy %VHDPath% N:\VHDBOOT\OS.VHDx
if %errorlevel% neq 0 echo "copy vhd file failed! abort..." && goto eof
goto ModifyBCD


:ModifyBCD
@echo ==== Mount VHD and Create Boot Entry =======
@echo sel vdisk file=N:\VHDBOOT\OS.VHDx > %TEMP%\vhd_mount.txt
@echo attach vdisk noerr >> %TEMP%\vhd_mount.txt
@echo sel part 2 >> %TEMP%\vhd_mount.txt 
@echo assign letter=V >> %TEMP%\vhd_mount.txt
@echo rescan >> %TEMP%\vhd_mount.txt
@echo rescan >> %TEMP%\vhd_mount.txt
@echo list volume >> %TEMP%\vhd_mount.txt
@echo exit >> %TEMP%\vhd_mount.txt

diskpart /s %TEMP%\vhd_mount.txt

rem === Copy the Windows RE Tools to the system partition ====================
md T:\Recovery\WindowsRE
copy V:\windows\system32\recovery\winre.wim T:\Recovery\WindowsRE\winre.wim

rem === Copy boot files from the Windows partition to the System partition ===
V:\windows\system32\bcdboot.exe V:\windows /s S:


rem === In the System partition, set the location of the WinRE tools =========
V:\Windows\System32\reagentc /setreimage /path T:\Recovery\WindowsRE /target V:\Windows


@echo sel vdisk file=N:\VHDBOOT\OS.VHDx > %TEMP%\vhd_dismount.txt
@echo detach vdisk >> %TEMP%\vhd_dismount.txt
@echo exit >> %TEMP%\vhd_dismount.txt

diskpart /s %TEMP%\vhd_dismount.txt
if %errorlevel% neq 0 echo prepared disk failed! abort... && goto eof 

goto :end
rem exit
:end
rem =======
rem Restart
rem =======

for /L %%a in (
 5,-1,0
) do (
 cls
 echo %%a seconds left
 ping 127.0.0.1 -n 2 > nul
 cls
)

@pause
wpeutil reboot

:eof
