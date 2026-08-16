@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

where git >nul 2>&1 || ( echo error: git not found in PATH & exit /b 1 )
where odin >nul 2>&1 || ( echo error: odin not found in PATH - https://odin-lang.org & exit /b 1 )

if not defined VULKAN_SDK (
  echo error: VULKAN_SDK is not set. Install the LunarG Vulkan SDK.
  exit /b 1
)

echo ==^> submodules
git submodule update --init --recursive || goto :err

set "VMA_LIB=%ROOT%\third_party\odin-vma\external\VulkanMemoryAllocator.lib"
if exist "%VMA_LIB%" (
  echo ==^> VMA already built
) else (
  echo error: %VMA_LIB% is missing.
  echo   odin-vma ships this prebuilt for Windows - re-run: git submodule update --init --recursive
  goto :err
)

set "IMGUI_LIB=%ROOT%\third_party\odin-imgui\imgui_windows_x64.lib"
if exist "%IMGUI_LIB%" (
  echo ==^> imgui already built
) else (
  where python >nul 2>&1 || ( echo error: python not found in PATH & goto :err )
  echo ==^> building imgui -^> imgui_windows_x64.lib
  echo     first run clones dear imgui, glfw, SDL2, SDL3 and Vulkan-Headers; it takes a few minutes
  pushd "%ROOT%\third_party\odin-imgui"
  python build.py || ( popd & goto :err )
  popd
)

set "BOX3D_DLL=%ROOT%\third_party\box3d\lib\shared\box3d.dll"
if exist "%BOX3D_DLL%" (
  echo ==^> box3d already built
) else (
  echo ==^> building box3d -^> box3d.lib + box3d.dll
  call "%ROOT%\third_party\box3d\build_dll.bat" || goto :err
)

echo.
echo setup complete.
echo   velux is a library - there is no executable to build here.
echo   build your game repo, or clone https://github.com/theaveasso/velux-starter
exit /b 0

:err
echo Setup failed
exit /b 1
