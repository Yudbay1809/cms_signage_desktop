@echo off
setlocal

set "PROJECT_DIR=D:\cms_signage_desktop"
set "TARGET_DIR=D:\APP\desktop"

set "FLUTTER="
if exist "D:\tools\flutter\bin\flutter.bat" set "FLUTTER=D:\tools\flutter\bin\flutter.bat"
if not defined FLUTTER if exist "C:\Users\MSI\Downloads\flutter_windows_3.41.0-stable\flutter\bin\flutter.bat" set "FLUTTER=C:\Users\MSI\Downloads\flutter_windows_3.41.0-stable\flutter\bin\flutter.bat"

if not defined FLUTTER (
  echo Flutter tidak ditemukan.
  echo Set path di file ini: FLUTTER=...\\flutter.bat
  exit /b 1
)

echo [1/3] Build release (Windows)...
cd /d "%PROJECT_DIR%" || exit /b 1
call "%FLUTTER%" build windows --release || goto :err

echo [2/3] Copy release ke %TARGET_DIR% ...
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

robocopy "%PROJECT_DIR%\build\windows\x64\runner\Release" "%TARGET_DIR%" /MIR /R:2 /W:1 >nul
set "RC=%ERRORLEVEL%"
if %RC% GEQ 8 goto :err_copy

echo [3/3] Selesai.
echo Output: %TARGET_DIR%\cms_signage_desktop.exe
exit /b 0

:err_copy
echo Gagal copy dengan robocopy (exit code: %RC%).
exit /b 1

:err
echo Build gagal. Cek log di atas.
exit /b 1
