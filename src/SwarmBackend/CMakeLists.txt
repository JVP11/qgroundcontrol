find_package(Qt6 REQUIRED COMPONENTS Core Positioning Qml WebSockets)

target_sources(
    ${CMAKE_PROJECT_NAME}
    PRIVATE SwarmBackendRegister.cc
            SwarmWebSocketClient.cc
            SwarmWebSocketClient.h
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE Qt6::WebSockets)

qt_add_library(SwarmBackendModule STATIC)

qt_add_qml_module(SwarmBackendModule
    URI ASTHRA.Swarm
    VERSION 1.0
    RESOURCE_PREFIX /
    QML_FILES
        SwarmMapItems.qml
        SwarmControlPanel.qml
    NO_PLUGIN
)

target_link_libraries(SwarmBackendModule
    PUBLIC
        Qt6::Core
        Qt6::Positioning
        Qt6::Qml
)
