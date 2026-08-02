@echo off
setlocal enabledelayedexpansion

set "GAME=%~1"
if "%GAME%"=="" set "GAME=hollow"

set "ODIN=odin"
set "GAME_DIR=game\%GAME%"

if not exist "%GAME_DIR%" (
  echo No such game: %GAME_DIR%
  exit /b 1
)

for %%F in ("%GAME_DIR%\assets\*.slang") do call :compile_one "%%~fF" || goto :err

"%ODIN%" build %GAME_DIR% -debug -o:none ^
  -collection:vlx=. ^
  -collection:third_party=third_party ^
  -out:%GAME_DIR%\%GAME%.exe || goto :err

echo.
echo Built %GAME_DIR%\%GAME%.exe (debug symbols alongside it)
echo Run it from its own folder so relative assets resolve:  %GAME_DIR%\%GAME%.exe
exit /b 0

:compile_one
findstr /M /C:"[shader(" %1 >nul 2>&1
if errorlevel 1 (
  echo Skipping module %~nx1
  exit /b 0
)
call "%~dp0compile_shader.bat" -in %1 -out "%~dpn1.spv"
exit /b %errorlevel%

:err
echo Build failed
exit /b 1
