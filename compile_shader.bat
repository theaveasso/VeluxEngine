@echo off
setlocal enabledelayedexpansion

set "IN="
set "OUT="

:parse
if "%~1"=="" goto args_done
if /i "%~1"=="-in"  ( set "IN=%~2"  & shift & shift & goto parse )
if /i "%~1"=="-out" ( set "OUT=%~2" & shift & shift & goto parse )
echo Unknown argument: %~1
goto usage
:args_done

if not defined IN  goto usage
if not defined OUT goto usage

set "SLANGC=slangc"
if defined VULKAN_SDK if exist "%VULKAN_SDK%\Bin\slangc.exe" set "SLANGC=%VULKAN_SDK%\Bin\slangc.exe"

for %%F in ("%OUT%") do if not exist "%%~dpF" mkdir "%%~dpF"

"%SLANGC%" "%IN%" -target spirv -fvk-use-entrypoint-name -o "%OUT%"
if errorlevel 1 (
  echo Shader compilation failed: %IN%
  exit /b 1
)

echo Compiled %IN% -^> %OUT%
exit /b 0

:usage
echo Usage: compile_shader.bat -in ^<shader.slang^> -out ^<shader.spv^>
exit /b 1
