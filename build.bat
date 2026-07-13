@echo off
setlocal enabledelayedexpansion

set "SAMPLE=%~1"
if "%SAMPLE%"=="" set "SAMPLE=03_mesh"

set "ODIN=odin"

if not exist build mkdir build

call "%~dp0compile_shader.bat" -in shaders\mesh.slang     -out shaders\out\mesh.spv     || goto :err
call "%~dp0compile_shader.bat" -in shaders\triangle.slang -out shaders\out\triangle.spv || goto :err

"%ODIN%" build samples\%SAMPLE% -debug -o:none ^
  -collection:vlx=framework ^
  -collection:third_party=third_party ^
  -out:build\%SAMPLE%.exe || goto :err

echo.
echo Built build\%SAMPLE%.exe (debug symbols: build\%SAMPLE%.pdb)
echo Run from the project root so shaders/out/*.spv resolves:  build\%SAMPLE%.exe
exit /b 0

:err
echo Build failed
exit /b 1
