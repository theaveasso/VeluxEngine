@echo off
setlocal

set "HERE=%~dp0"
set "HERE=%HERE:~0,-1%"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if not exist "%VSWHERE%" (
  echo error: vswhere.exe not found - install Visual Studio with the C++ workload
  exit /b 1
)

for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -property installationPath`) do set "VS=%%i"
if not defined VS (
  echo error: no Visual Studio installation with the C++ workload
  exit /b 1
)

call "%VS%\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul || exit /b 1

if not exist "%HERE%\lib\shared" mkdir "%HERE%\lib\shared"

pushd "%HERE%\src" || exit /b 1

cl -nologo -MT -TC -O2 -c -std:c17 -I"include" src\*.c >nul || ( popd & exit /b 1 )
lib -nologo *.obj -out:"%HERE%\lib\box3d.lib" || ( popd & exit /b 1 )
del *.obj

cl -nologo -MT -TC -O2 -c -std:c17 -Dbox3d_EXPORTS -I"include" src\*.c >nul || ( popd & exit /b 1 )
link -nologo -DLL *.obj -out:"%HERE%\lib\shared\box3d.dll" -implib:"%HERE%\lib\shared\box3d.lib" || ( popd & exit /b 1 )
del *.obj

popd
exit /b 0
