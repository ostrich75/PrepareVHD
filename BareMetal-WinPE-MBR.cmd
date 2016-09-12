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
for /f "tokens=1,2 delims=\" %%a in ("%vhdxpath%") do set servername=%%a
set "unc=\\%servername%"
goto PrepareDisk

:LocalVHD
@echo.
@echo Please input source VHD path (Like X:\WSSCPOC\VHDBOOT\NANO.vhdx) ...
set /p VHDPath=
goto PrepareDisk

:PrepareDisk
@echo select disk 0 > %TEMP%\prepare_disk.txt
@echo clean >> %TEMP%\prepare_disk.txt
@echo create partition primary size=500 >> %TEMP%\prepare_disk.txt
@echo format quick fs=ntfs >> %TEMP%\prepare_disk.txt
@echo assign letter=S >> %TEMP%\prepare_disk.txt
@echo active >> %TEMP%\prepare_disk.txt
@echo create partition primary >> %TEMP%\prepare_disk.txt
@echo format fs=ntfs quick label=DATA >> %TEMP%\prepare_disk.txt
@echo assign letter=N >> %TEMP%\prepare_disk.txt
@echo exit >> %TEMP%\prepare_disk.txt

diskpart /s %TEMP%\prepare_disk.txt

@echo ====            Copy VHD             =======
md N:\VHDBOOT
if /i "%choice%"=="2" goto COPYVHD
net use z: %unc% /user:%username% %password%

:COPYVHD
copy %VHDPath% N:\VHDBOOT\OS.VHDx

if errorlevel 1 goto Failed
if errorlevel 0 goto ModifyBCD

:ModifyBCD
@echo ==== Mount VHD and Create Boot Entry =======
@echo sel vdisk file=N:\VHDBOOT\OS.VHDx > %TEMP%\vhd_mount.txt
@echo attach vdisk noerr >> %TEMP%\vhd_mount.txt
@echo rescan >> %TEMP%\vhd_mount.txt
@echo rescan >> %TEMP%\vhd_mount.txt
@echo list volume >> %TEMP%\vhd_mount.txt
@echo exit >> %TEMP%\vhd_mount.txt

diskpart /s %TEMP%\vhd_mount.txt

@echo.
@echo What's the drive letter for the attached VHD) ...
set /p driveletter=
@echo.

%driveletter%:\windows\system32\bcdboot.exe %driveletter%:\windows /s S:

@echo sel vdisk file=N:\VHDBOOT\%vhdname% > %TEMP%\vhd_dismount.txt
@echo detach vdisk >> %TEMP%\vhd_dismount.txt
@echo exit >> %TEMP%\vhd_dismount.txt

diskpart /s %TEMP%\vhd_dismount.txt

goto :end

:Failed
@echo "Can't copy VHD file, operation abort!"
Pause
exit
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

exit