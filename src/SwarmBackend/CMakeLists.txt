find_package(Qt6 REQUIRED COMPONENTS Core Positioning Qml WebSockets)

qt_add_qml_module(SwarmBackendModule
    URI ASTHRA.Swarm
    VERSION 1.0
    RESOURCE_PREFIX /
    QML_FILES
        SwarmMapItems.qml
        SwarmControlPanel.qml
    SOURCES
        SwarmWebSocketClient.cc
        SwarmWebSocketClient.h
        SwarmBackendRegister.cc
)

target_link_libraries(SwarmBackendModule
    PUBLIC
        Qt6::Core
        Qt6::Positioning
        Qt6::Qml
        Qt6::WebSockets
)

target_include_directories(SwarmBackendModule PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
