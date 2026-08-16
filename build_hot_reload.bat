@echo off
setlocal enabledelayedexpansion

set "ODIN=odin"
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

for %%I in (%ODIN%.exe) do set "ODIN_EXE=%%~$PATH:I"
if not defined ODIN_EXE (
  echo Cannot find %ODIN%.exe on PATH
  exit /b 1
)
for %%I in ("%ODIN_EXE%") do set "ODIN_DIR=%%~dpI"
set "ODIN_DIR=%ODIN_DIR:~0,-1%"

set "GLFW_DLL=%ODIN_DIR%\vendor\glfw\lib\glfw3.dll"
if not exist "%GLFW_DLL%" (
  echo Cannot find %GLFW_DLL%
  exit /b 1
)

set "BOX3D_DLL=%ROOT%\third_party\box3d\lib\shared\box3d.dll"
if not exist "%BOX3D_DLL%" (
  echo Cannot find %BOX3D_DLL% - run setup.bat
  exit /b 1
)

if not exist "%ROOT%\build" mkdir "%ROOT%\build"
if not exist "%ROOT%\build\glfw3.dll" (
  copy /y "%GLFW_DLL%" "%ROOT%\build\glfw3.dll" >nul || goto :err
)
copy /y "%BOX3D_DLL%" "%ROOT%\build\box3d.dll" >nul || goto :err

"%ODIN%" build "%ROOT%\hot_reload" -debug -o:none ^
  -define:GLFW_SHARED=true ^
  -define:BOX3D_SHARED=true ^
  -collection:vlx="%ROOT%" ^
  -collection:third_party="%ROOT%\third_party" ^
  -out:"%ROOT%\build\velux_hot_reload.exe" || goto :err

echo.
echo Built %ROOT%\build\velux_hot_reload.exe
echo Run from the repo root:  build\velux_hot_reload.exe ^<source_dir^>
exit /b 0

:err
echo Build failed
exit /b 1
