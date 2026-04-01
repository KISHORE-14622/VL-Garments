@echo off
echo ========================================
echo VL-Garments Website Update Script
echo ========================================
echo.

echo Step 1: Building Flutter Web App...
cd my_app
call flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)

echo.
echo Step 2: Copying built files to frontend directory...
cd ..
xcopy /E /I /Y my_app\build\web\* frontend\

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to copy files!
    pause
    exit /b 1
)

echo.
echo ========================================
echo SUCCESS! Website files updated.
echo ========================================
echo.
echo Next steps:
echo 1. Review the changes: git status
echo 2. Commit the changes: git add frontend ^&^& git commit -m "Update website"
echo 3. Push to deploy: git push
echo.
pause
