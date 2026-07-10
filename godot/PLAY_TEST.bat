@echo off
setlocal
cd /d "%~dp0"
set "GODOT_EXE=%~dp0..\.tools\godot-4.7\Godot_v4.7-stable_win64.exe"

if not exist "%GODOT_EXE%" (
  echo Godot 4.7 was not found:
  echo %GODOT_EXE%
  echo.
  echo Ask the development setup to restore the portable Godot tool.
  pause
  exit /b 1
)

start "Road of the Dead - Godot Prototype" "%GODOT_EXE%" --path "%~dp0"
endlocal
