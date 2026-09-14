// ASTHRA Swarm Operations — map, path plan, fleet, live video

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.SwarmPlugin

Rectangle {
    id: root
    anchors.fill: parent
    color: qgcPal.window

    property var mainWindow: null
    property alias swarm: swarmBridge

    QGCPalette { id: qgcPal }

    SwarmBridge {
        id: swarmBridge
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SwarmStatusBar {
            Layout.fillWidth: true
            swarmBridge: swarmBridge
            waypointModel: mapView.waypointModel
            selectedDroneId: mapView.selectedDroneId
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            FleetPanel {
                id: fleetPanel
                swarmBridge: swarmBridge
                selectedDroneId: mapView.selectedDroneId
                onDroneSelected: function(sid) { mapView.selectedDroneId = sid }
                onArmAll: _setAllArmed(true)
                onDisarmAll: _setAllArmed(false)
                onConnectRequested: {
                    if (mainWindow && mainWindow.showDualVehicleConnection) {
                        mainWindow.showDualVehicleConnection()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 24
                color: qgcPal.windowShadeDark
                border.width: 1
                border.color: qgcPal.buttonBorder

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    QGCLabel {
                        Layout.fillWidth: true
                        Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                        Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
                        Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.25
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: qgcPal.colorBlue
                        text: qsTr("MISSION MAP — TAP TO ADD WAYPOINTS")
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                        Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
                        Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.15
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: qgcPal.colorGrey
                        wrapMode: Text.WordWrap
                        text: qsTr("Indoor planner (meters). World satellite map → FLY view.")
                    }

                    IndoorMapView {
                        id: mapView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 12
                        swarmBridge: swarmBridge
                        floorPlanPath: "qrc:/qml/QGroundControl/SwarmPlugin/assets/floor_plan.png"
                        roomWidthM: 12.0
                        roomHeightM: 9.0
                        onDroneClicked: function(sid) { mapView.selectedDroneId = sid }
                        onOpen3DView: view3DLoader.active = true
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: Math.min(
                    ScreenTools.defaultFontPixelWidth * 36,
                    root.width * 0.34)
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 26
                Layout.fillHeight: true
                spacing: 1

                ASTHRASwarmVideoPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 10
                    Layout.maximumHeight: ScreenTools.defaultFontPixelHeight * 22
                }

                PathPlannerPanel {
                    id: pathPlanner
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 16
                    swarmBridge: swarmBridge
                    waypointModel: mapView.waypointModel
                    mainWindow: root.mainWindow
                    onUploadMission: function(sysid, wps) { _confirmAndUpload(sysid, wps) }
                    onUndoLastWaypoint: mapView.undoLastWaypoint()
                }
            }
        }
    }

    Loader {
        id: view3DLoader
        active: false
        anchors.fill: parent
        z: 200
        sourceComponent: overlayComponent
    }

    Component {
        id: overlayComponent
        Rectangle {
            color: "#CC000000"
            MouseArea {
                anchors.fill: parent
                onClicked: view3DLoader.active = false
            }
            RoomView3D {
                anchors.centerIn: parent
                width: parent.width * 0.88
                height: parent.height * 0.88
                swarmBridge: swarmBridge
                onCloseRequested: view3DLoader.active = false
            }
        }
    }

    function _confirmAndUpload(sysid, waypoints) {
        if (!waypoints || waypoints.length === 0) {
            if (mainWindow) {
                mainWindow.showMessageDialog(qsTr("Upload Mission"),
                    qsTr("Add at least one waypoint on the map."))
            }
            return
        }
        if (swarmBridge.liveVehicleCount === 0) {
            if (mainWindow) {
                mainWindow.showMessageDialog(qsTr("No Vehicles"),
                    qsTr("Connect vehicles via DUAL or Comm Links first."))
            }
            return
        }
        var targetLabel = sysid < 0
            ? qsTr("all %1 vehicle(s)").arg(swarmBridge.liveVehicleCount)
            : qsTr("Vehicle %1").arg(sysid)
        if (mainWindow) {
            mainWindow.showMessageDialog(
                qsTr("Upload Mission"),
                qsTr("Upload %1 waypoint(s) to %2?\n\nArm and start AUTO/MISSION on each vehicle after upload.")
                    .arg(waypoints.length).arg(targetLabel),
                Dialog.Yes | Dialog.No,
                function() { _doUpload(sysid, waypoints) })
        } else {
            _doUpload(sysid, waypoints)
        }
    }

    function _doUpload(sysid, waypoints) {
        var ok = 0
        var fail = 0
        if (sysid < 0) {
            var vehicles = QGroundControl.multiVehicleManager.vehicles
            if (!vehicles) return
            for (var i = 0; i < vehicles.count; i++) {
                var v = vehicles.get(i)
                if (v && swarmBridge.uploadLocalWaypoints(v.id, waypoints)) ok++
                else fail++
            }
        } else {
            if (swarmBridge.uploadLocalWaypoints(sysid, waypoints)) ok = 1
            else fail = 1
        }
        if (fail > 0 && mainWindow) {
            mainWindow.showMessageDialog(qsTr("Upload"),
                qsTr("Sent to %1 vehicle(s); %2 failed.").arg(ok).arg(fail))
        }
    }

    function _setAllArmed(arm) {
        var vehicles = QGroundControl.multiVehicleManager.vehicles
        if (!vehicles) return
        for (var i = 0; i < vehicles.count; i++) {
            var v = vehicles.get(i)
            if (v) v.armed = arm
        }
    }

    Component.onCompleted: swarmBridge.refreshNow()
}
