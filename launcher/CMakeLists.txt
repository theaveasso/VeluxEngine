add_library(velux_launcher STATIC velux_entry.cpp)
target_link_libraries(velux_launcher PUBLIC velux_engine)

add_executable(velux_app velux_app_stub.cpp)
target_link_libraries(velux_app PRIVATE velux_launcher game)
