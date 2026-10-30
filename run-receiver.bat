@echo off
cd /d "%~dp0"
py -m pip install -r receiverequirements.txt
if errorlevel 1 goto :fail
py -m receiver.server --mode xbox
if errorlevel 1 goto :fail
pause
exit /b 0
:fail
echo.
echo Setup or receiver launch failed. See README.md for troubleshooting.
pause
exit /b 1
