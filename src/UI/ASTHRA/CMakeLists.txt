# ============================================================================
# ASTHRA UI Components
# Military-Industrial Locked Layout Components
# ============================================================================

qt_add_library(ASTHRAModule STATIC)

qt_add_qml_module(ASTHRAModule
    URI QGroundControl.UI.ASTHRA
    VERSION 1.0
    RESOURCE_PREFIX /qml
    QML_FILES
        ASTHRATopStatusStrip.qml
        ASTHRALeftControlColumn.qml
        ASTHRARightTelemetryColumn.qml
        ASTHRABottomCommandBar.qml
        ASTHRAOffboardMonitor.qml
        ASTHRAMissionLogger.qml
        ASTHRATelemetryLogger.qml
        ASTHRACameraFrameCapture.qml
        ASTHRADisasterReportGenerator.qml
        ASTHRADisasterReportPanel.qml
        ASTHRASwarmCoveragePanel.qml
        ASTHRASwarmCoverageMap.qml
        ASTHRAOffboardMapMarkers.qml
        ASTHRAOffboardMarker.qml
        ASTHRARescueReportPanel.qml
        ASTHRADualVehicleConnection.qml
        Spatial3D/ASTHRASpatial3DView.qml
        Spatial3D/ASTHRASpatial3DScene.qml
        Spatial3D/ASTHRASpatialCameraController.qml
        Spatial3D/ASTHRASpatialHud.qml
        Spatial3D/ASTHRASpatialCheckStrip.qml
        Spatial3D/ASTHRACameraFovCone.qml
        Spatial3D/ASTHRASpatialVehicleNode.qml
        Spatial3D/ASTHRASpatialLine3D.qml
    IMPORTS
        QtQuick
        QtQuick3D
        QtPositioning
    NO_PLUGIN
)

find_package(Qt6 REQUIRED COMPONENTS Quick3D)
target_link_libraries(ASTHRAModule PRIVATE Qt6::Quick3D)
