@echo off
setlocal EnableExtensions

title Build NEXPOS Installer

cd /d "%~dp0"

set "FLUTTER_PATH="
for /f "delims=" %%F in ('where flutter 2^>nul') do (
  set "FLUTTER_PATH=%%F"
  goto :flutter_found
)

:flutter_found
if not defined FLUTTER_PATH (
  echo [HATA] Flutter bulunamadi.
  echo Lutfen PATH'e Flutter ekleyin ve tekrar deneyin.
  pause
  exit /b 1
)

if not exist "frontend\pubspec.yaml" (
  echo [HATA] frontend\pubspec.yaml bulunamadi.
  pause
  exit /b 1
)

set "ISCC_PATH="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not defined ISCC_PATH if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"
if not defined ISCC_PATH if exist "%LocalAppData%\Programs\Inno Setup 6\ISCC.exe" set "ISCC_PATH=%LocalAppData%\Programs\Inno Setup 6\ISCC.exe"

if not defined ISCC_PATH (
  echo [HATA] Inno Setup 6 bulunamadi.
  echo Lutfen Inno Setup 6 kurun: https://jrsoftware.org/isinfo.php
  pause
  exit /b 1
)

echo [1/3] Flutter Windows release derleniyor...
pushd "frontend"
"%FLUTTER_PATH%" pub get
if errorlevel 1 (
  popd
  echo [HATA] flutter pub get basarisiz.
  pause
  exit /b 1
)

"%FLUTTER_PATH%" build windows --release
if errorlevel 1 (
  popd
  echo [HATA] Flutter Windows release derleme basarisiz.
  pause
  exit /b 1
)
popd

echo [2/3] installer.iss derleniyor...
"%ISCC_PATH%" "installer.iss"
if errorlevel 1 (
  echo [HATA] Derleme basarisiz.
  pause
  exit /b 1
)

echo [3/3] Tamamlandi.
echo Uretilen dosya: %cd%\NexPOS-Setup.exe

pause
exit /b 0
