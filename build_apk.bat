@echo off
echo ========================================================
echo   MIDI SKU Finder - Android APK Build Script
echo ========================================================
echo.
echo Building Release APK...
flutter build apk --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo   BUILD SUCCESSFUL!
    echo   APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo ========================================================
) else (
    echo.
    echo BUILD FAILED. Check errors above.
)
pause
