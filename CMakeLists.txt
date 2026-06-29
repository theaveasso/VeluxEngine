cmake_minimum_required(VERSION 3.31)

project(VeluxEngine)

set(CMAKE_CXX_STANDARD 			23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Vulkan 				REQUIRED)
find_package(VulkanHeaders 	CONFIG 	REQUIRED)
find_package(glfw3 			CONFIG 	REQUIRED)
find_package(spdlog			CONFIG 	REQUIRED)

add_compile_definitions($<$<CONFIG:Debug>:VLX_DEBUG>)

add_subdirectory(veluxengine)
add_subdirectory(game)
add_subdirectory(launcher)

function (add_slang_shader_target TARGET)
	cmake_parse_arguments("SHADER" "" "" "SOURCES" ${ARGN})
	set(SHADERS_DIR ${CMAKE_CURRENT_LIST_DIR}/assets/shaders)
	set(ENTRY_POINTS -entry vertMain -entry fragMain)
	add_custom_command(
		OUTPUT ${SHADERS_DIR}
		COMMAND ${CMAKE_COMMAND} -E make_directory ${SHADERS_DIR})
	add_custom_command(
		OUTPUT ${SHADERS_DIR}/triangle.spv
        COMMAND ${SLANGC_EXECUTABLE} ${SHADER_SOURCES} -target spirv -profile spirv_1_4 -emit-spirv-directly -fvk-use-entrypoint-name ${ENTRY_POINTS} -o triangle.spv
		WORKING_DIRECTORY ${SHADERS_DIR}
		COMMENT "Compiling Slang Shaders"
		VERBATIM)
	add_custom_target(${TARGET} DEPENDS ${SHADERS_DIR}/triangle.spv)
endfunction()
