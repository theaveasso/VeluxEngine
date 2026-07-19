@echo off
setlocal enabledelayedexpansion

set "SAMPLE=%~1"
if "%SAMPLE%"=="" set "SAMPLE=04_voxel"

set "ODIN=odin"

call "%~dp0compile_shader.bat" -in shaders\mesh.slang                  -out shaders\out\mesh.spv                   || goto :err
call "%~dp0compile_shader.bat" -in shaders\triangle.slang              -out shaders\out\triangle.spv               || goto :err
call "%~dp0compile_shader.bat" -in samples\04_voxel\assets\voxel.slang -out samples\04_voxel\assets\voxel.spv      || goto :err
call "%~dp0compile_shader.bat" -in samples\05_raymarch\assets\raymarch.slang -out samples\05_raymarch\assets\raymarch.spv || goto :err

"%ODIN%" build samples\%SAMPLE% -debug -o:none ^
  -collection:vlx=framework ^
  -collection:third_party=third_party ^
  -out:samples\%SAMPLE%\%SAMPLE%.exe || goto :err

echo.
echo Built samples\%SAMPLE%\%SAMPLE%.exe (debug symbols alongside it)
echo Run it from its own folder so relative assets resolve:  samples\%SAMPLE%\%SAMPLE%.exe
exit /b 0

:err
echo Build failed
exit /b 1
