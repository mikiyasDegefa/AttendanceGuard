@echo off
REM =============================================================================
REM  WiFi Tracker — Flutter APK Build Script (Windows)
REM  Usage: Double-click build_apk.bat  OR  run in Command Prompt
REM =============================================================================

setlocal EnableDelayedExpansion
title WiFi Tracker APK Builder

REM ── Config ──────────────────────────────────────────────────────────────────
set FLUTTER_VERSION=3.22.0
set FLUTTER_CHANNEL=stable
set FLUTTER_DIR=%USERPROFILE%\flutter
set ANDROID_SDK_DIR=%USERPROFILE%\android-sdk
set OUTPUT_DIR=%~dp0output
set APK_NAME=wifi-tracker-release.apk
set FLUTTER_URL=https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_%FLUTTER_VERSION%-stable.zip
set CMDTOOLS_URL=https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip

REM ── Banner ───────────────────────────────────────────────────────────────────
echo.
echo  ============================================
echo   WiFi Tracker ^| Flutter APK Builder
echo   Flutter %FLUTTER_VERSION% ^| Windows
echo  ============================================
echo.

REM ── Check Java ───────────────────────────────────────────────────────────────
echo [CHECK] Looking for Java...
java -version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Java not found!
    echo.
    echo  Please install JDK 17 from:
    echo  https://adoptium.net/temurin/releases/?version=17
    echo.
    echo  After installing, re-run this script.
    pause
    exit /b 1
)
echo [ OK ] Java found
echo.

REM ── Check / Install Flutter ──────────────────────────────────────────────────
echo [CHECK] Looking for Flutter...
if exist "%FLUTTER_DIR%\bin\flutter.bat" (
    echo [ OK ] Flutter already installed at %FLUTTER_DIR%
) else (
    echo [BUILD] Downloading Flutter %FLUTTER_VERSION%...
    echo         This may take a few minutes...
    echo.

    if not exist "%TEMP%\flutter_download" mkdir "%TEMP%\flutter_download"

    REM Use PowerShell to download
    powershell -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%FLUTTER_URL%' -OutFile '%TEMP%\flutter_download\flutter.zip' }"

    if errorlevel 1 (
        echo [ERROR] Download failed. Check your internet connection.
        pause
        exit /b 1
    )

    echo [BUILD] Extracting Flutter...
    powershell -Command "Expand-Archive -Path '%TEMP%\flutter_download\flutter.zip' -DestinationPath '%USERPROFILE%' -Force"

    if errorlevel 1 (
        echo [ERROR] Extraction failed.
        pause
        exit /b 1
    )
    echo [ OK ] Flutter installed at %FLUTTER_DIR%
)

REM ── Add Flutter to PATH for this session ─────────────────────────────────────
set PATH=%FLUTTER_DIR%\bin;%PATH%
echo.

REM ── Check / Install Android SDK ──────────────────────────────────────────────
echo [CHECK] Looking for Android SDK...
if exist "%ANDROID_SDK_DIR%\cmdline-tools\latest\bin\sdkmanager.bat" (
    echo [ OK ] Android SDK already installed
) else (
    echo [BUILD] Downloading Android command-line tools...

    if not exist "%TEMP%\android_download" mkdir "%TEMP%\android_download"

    powershell -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%CMDTOOLS_URL%' -OutFile '%TEMP%\android_download\cmdtools.zip' }"

    if errorlevel 1 (
        echo [ERROR] Android SDK download failed.
        pause
        exit /b 1
    )

    echo [BUILD] Extracting Android SDK tools...
    if not exist "%ANDROID_SDK_DIR%\cmdline-tools" mkdir "%ANDROID_SDK_DIR%\cmdline-tools"
    powershell -Command "Expand-Archive -Path '%TEMP%\android_download\cmdtools.zip' -DestinationPath '%TEMP%\android_download\extracted' -Force"
    xcopy /E /I /Y "%TEMP%\android_download\extracted\cmdline-tools" "%ANDROID_SDK_DIR%\cmdline-tools\latest" >nul

    echo [ OK ] Android command-line tools installed
)

REM ── Add Android tools to PATH ────────────────────────────────────────────────
set ANDROID_HOME=%ANDROID_SDK_DIR%
set ANDROID_SDK_ROOT=%ANDROID_SDK_DIR%
set PATH=%ANDROID_SDK_DIR%\cmdline-tools\latest\bin;%ANDROID_SDK_DIR%\platform-tools;%PATH%
echo.

REM ── Accept Licenses and install SDK components ───────────────────────────────
echo [BUILD] Accepting Android licenses and installing SDK components...
echo        (Press Enter if prompted)
echo.

echo y | call sdkmanager --licenses >nul 2>&1
call sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" 2>nul

echo [ OK ] Android SDK components installed
echo.

REM ── Configure Flutter ────────────────────────────────────────────────────────
echo [BUILD] Configuring Flutter...
call flutter config --no-analytics >nul 2>&1
call flutter config --android-sdk "%ANDROID_SDK_DIR%" >nul 2>&1
echo [ OK ] Flutter configured
echo.

REM ── Check this is a Flutter project ──────────────────────────────────────────
if not exist "%~dp0pubspec.yaml" (
    echo [ERROR] pubspec.yaml not found!
    echo         Run this script from your Flutter project folder.
    pause
    exit /b 1
)

REM ── Get dependencies ──────────────────────────────────────────────────────────
echo [BUILD] Fetching Flutter dependencies...
cd /d "%~dp0"
call flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get failed.
    pause
    exit /b 1
)
echo [ OK ] Dependencies fetched
echo.

REM ── Build APK ────────────────────────────────────────────────────────────────
echo [BUILD] Building release APK...
echo        (This takes 3-7 minutes on first run)
echo.

call flutter build apk --release --no-tree-shake-icons

if errorlevel 1 (
    echo.
    echo [ERROR] Build failed! See errors above.
    pause
    exit /b 1
)

REM ── Copy output ──────────────────────────────────────────────────────────────
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
copy /Y "%~dp0build\app\outputs\flutter-apk\app-release.apk" "%OUTPUT_DIR%\%APK_NAME%" >nul

if exist "%OUTPUT_DIR%\%APK_NAME%" (
    echo.
    echo  ============================================
    echo   BUILD SUCCESSFUL!
    echo  ============================================
    echo   File : %APK_NAME%
    echo   Path : %OUTPUT_DIR%\%APK_NAME%
    echo  ============================================
    echo.

    REM Open the output folder automatically
    explorer "%OUTPUT_DIR%"
) else (
    echo [ERROR] APK not found after build.
    pause
    exit /b 1
)

REM ── Install to device if connected ───────────────────────────────────────────
adb devices 2>nul | findstr /C:"device" | findstr /V /C:"List" >nul 2>&1
if not errorlevel 1 (
    echo [BUILD] Android device detected — installing APK...
    adb install -r "%OUTPUT_DIR%\%APK_NAME%"
    if not errorlevel 1 (
        echo [ OK ] APK installed on device!
    ) else (
        echo [ WARN] Device install failed — copy APK manually
    )
    echo.
)

REM ── Install guide ────────────────────────────────────────────────────────────
echo  HOW TO INSTALL ON YOUR PHONE:
echo  ─────────────────────────────
echo  1. Copy %APK_NAME% to your phone
echo     ^(USB cable, WhatsApp to yourself, or Google Drive^)
echo.
echo  2. On your phone:
echo     Settings ^> Security ^> Install unknown apps ^> Enable
echo.
echo  3. Open the APK file ^> tap Install
echo.

pause
