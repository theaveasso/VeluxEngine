@echo off
setlocal enabledelayedexpansion

set "SAMPLE=%~1"
if "%SAMPLE%"=="" set "SAMPLE=sponza"

set "ODIN=odin"
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "SAMPLE_DIR=%ROOT%\samples\%SAMPLE%"

if not exist "%SAMPLE_DIR%" (
  echo No such sample: %SAMPLE_DIR%
  exit /b 1
)

for %%F in ("%SAMPLE_DIR%\assets\*.slang") do call :compile_one "%%~fF" || goto :err

"%ODIN%" build "%SAMPLE_DIR%" -debug -o:none ^
  -collection:vlx="%ROOT%" ^
  -collection:third_party="%ROOT%\third_party" ^
  -out:"%SAMPLE_DIR%\%SAMPLE%.exe" || goto :err

echo.
echo Built %SAMPLE_DIR%\%SAMPLE%.exe (debug symbols alongside it)
echo Run it from its own folder so relative assets resolve:  %SAMPLE_DIR%\%SAMPLE%.exe
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
