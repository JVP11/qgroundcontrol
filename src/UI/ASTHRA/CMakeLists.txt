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
        ASTHRABootScreen.qml
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
        Spatial3D/ASTHRADroneBody.qml
        Spatial3D/ASTHRADronePropeller.qml
    RESOURCES
        Spatial3D/meshes/asthra_drone_body.mesh
        Spatial3D/meshes/asthra_drone_prop.mesh
    IMPORTS
        QtQuick
        QtQuick3D
        QtPositioning
    NO_PLUGIN
)

find_package(Qt6 REQUIRED COMPONENTS Quick3D)
target_link_libraries(ASTHRAModule PRIVATE Qt6::Quick3D)

# Boot screen logos: drop images/asthra_logo.* and images/institution_logo.* (png/svg/jpg) here and rebuild
set(ASTHRA_BRANDING_FILES)
foreach(_asthra_logo IN ITEMS asthra_logo:logo institution_logo:institution)
    string(REPLACE ":" ";" _asthra_logo "${_asthra_logo}")
    list(GET _asthra_logo 0 _asthra_logo_name)
    list(GET _asthra_logo 1 _asthra_logo_alias)
    file(GLOB _asthra_logo_files CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/images/${_asthra_logo_name}.*")
    if(_asthra_logo_files)
        list(GET _asthra_logo_files 0 _asthra_logo_file)
        set_source_files_properties("${_asthra_logo_file}" PROPERTIES QT_RESOURCE_ALIAS "${_asthra_logo_alias}")
        list(APPEND ASTHRA_BRANDING_FILES "${_asthra_logo_file}")
    endif()
endforeach()
if(ASTHRA_BRANDING_FILES)
    qt_add_resources(ASTHRAModule "asthra_branding"
        PREFIX "/asthra"
        FILES ${ASTHRA_BRANDING_FILES}
    )
endif()
