@echo off
REM ============================================================================
REM ESP32-WROOM-32 Medication Dispenser - voice + servos + web + HTTP API
REM Default COM port: COM3
REM ============================================================================

setlocal

set "ARDUINO_CLI=D:\Arduino CLI\arduino-cli.exe"
set "SKETCH=%~dp0"
set "FQBN=esp32:esp32:esp32"
set "PORT=COM3"

if not exist "%ARDUINO_CLI%" (
    echo Arduino CLI not found:
    echo   %ARDUINO_CLI%
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   ESP32-WROOM-32 Medication Dispenser
echo   Voice: HLK-V20 GPIO/UART enabled
echo   Servos: GPIO14, GPIO27, GPIO12, GPIO21
echo   Port: %PORT%
echo   FQBN: %FQBN%
echo ============================================================
echo.

echo [1/3] Compiling integrated firmware...
"%ARDUINO_CLI%" compile --fqbn %FQBN% "%SKETCH%"
if errorlevel 1 (
    echo.
    echo *** COMPILE FAILED ***
    pause
    exit /b 1
)
echo [1/3] Compile OK

echo.
echo [2/3] Uploading to %PORT%...
"%ARDUINO_CLI%" upload -p %PORT% --fqbn %FQBN% "%SKETCH%"
if errorlevel 1 (
    echo.
    echo *** UPLOAD FAILED ***
    echo Try: hold BOOT button on the board, then run this again.
    pause
    exit /b 1
)
echo [2/3] Upload OK

echo.
echo [3/3] Opening serial monitor at 115200 baud...
echo Useful commands:
echo   p1 650       test servo 1 directly
echo   p2 650       test servo 2 directly
echo   voice 2      simulate voice command for servo 2
echo   hlk toggle   switch HLK UART baud between 115200 and 9600
echo Press Ctrl+C to exit serial monitor.
echo.
timeout /t 2 >nul
"%ARDUINO_CLI%" monitor -p %PORT% -c baudrate=115200

endlocal
