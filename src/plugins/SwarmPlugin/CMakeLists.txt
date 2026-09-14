# ============================================================================
# ASTHRA Swarm Plugin (from qgc-swarm)
# ============================================================================

set(SWARM_PLUGIN_QML
    SwarmScreen.qml
    SwarmStatusBar.qml
    ASTHRASwarmVideoPanel.qml
    IndoorMap/IndoorMapView.qml
    IndoorMap/WaypointMarker.qml
    IndoorMap/MissionPathCanvas.qml
    IndoorMap/RoomView3D.qml
    IndoorMap/RoomView3DQuick.qml
    FleetPanel/FleetPanel.qml
    PathPlanner/PathPlannerPanel.qml
)

find_package(Qt6 QUIET COMPONENTS WebEngineQuick WebEngineCore)
if(TARGET Qt6::WebEngineQuick)
    list(APPEND SWARM_PLUGIN_QML IndoorMap/RoomView3DWebEngine.qml)
endif()

qt_add_library(SwarmPluginModule STATIC)

qt_add_qml_module(SwarmPluginModule
    URI QGroundControl.SwarmPlugin
    VERSION 1.0
    RESOURCE_PREFIX /qml
    QML_FILES
        ${SWARM_PLUGIN_QML}
    RESOURCES
        assets/floor_plan.png
        resources/3d-view-index.html
    NO_PLUGIN
)

# Bridge uses Vehicle/MissionManager — build with main app, register via Q_COREAPP_STARTUP_FUNCTION
target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/Bridge/SwarmBridge.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/Bridge/SwarmBridge.h
        ${CMAKE_CURRENT_SOURCE_DIR}/Bridge/SwarmPluginRegister.cc
)

target_include_directories(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/Bridge
)

if(TARGET Qt6::WebEngineQuick)
    target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE Qt6::WebEngineQuick Qt6::WebEngineCore)
    target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE QGC_SWARM_WEBENGINE=1)
endif()

if(QGC_VIEWER3D)
    find_package(Qt6 REQUIRED COMPONENTS Quick3D)
    target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE Qt6::Quick3D)
endif()
