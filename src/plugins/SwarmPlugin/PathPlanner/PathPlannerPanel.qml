// ASTHRA Path planner — industrial mission builder

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root

    property var swarmBridge
    property var waypointModel
    property var mainWindow: null

    signal uploadMission(int sysid, var waypoints)
    signal clearMission()
    signal undoLastWaypoint()

    readonly property int  _wpCount: waypointModel ? waypointModel.count : 0
    readonly property bool _hasWaypoints: _wpCount > 0
    readonly property bool _canUpload: swarmBridge && swarmBridge.liveVehicleCount > 0 && _hasWaypoints

    color: qgcPal.windowShade
    border.width: 1
    border.color: qgcPal.buttonBorder

    QGCPalette { id: qgcPal }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.4

        QGCLabel {
            text: qsTr("MISSION PLANNER")
            font.family: ScreenTools.fixedFontFamily
            font.weight: Font.Bold
        }

        QGCLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pointSize: ScreenTools.smallFontPointSize
            color: qgcPal.colorGrey
            text: qsTr("Tap the map to add waypoints. Purple line = planned route.")
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.buttonBorder }

        RowLayout {
            Layout.fillWidth: true
            QGCButton {
                text: qsTr("UNDO")
                enabled: _hasWaypoints
                onClicked: root.undoLastWaypoint()
            }
            Item { Layout.fillWidth: true }
            QGCLabel {
                font.family: ScreenTools.fixedFontFamily
                color: qgcPal.text
                text: {
                    if (_wpCount < 2) {
                        return _wpCount === 1 ? qsTr("1 waypoint") : qsTr("0 waypoints")
                    }
                    var d = 0
                    for (var i = 1; i < _wpCount; i++) {
                        var a = waypointModel.get(i - 1)
                        var b = waypointModel.get(i)
                        var dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z
                        d += Math.sqrt(dx * dx + dy * dy + dz * dz)
                    }
                    return qsTr("%1 wp · %2 m").arg(_wpCount).arg(d.toFixed(1))
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: wpList
                width: parent.width
                implicitHeight: contentHeight
                model: waypointModel
                spacing: 4

                delegate: Rectangle {
                    width: wpList.width
                    height: ScreenTools.defaultFontPixelHeight * 4.6
                    radius: 4
                    color: qgcPal.windowShadeDark
                    border.color: qgcPal.buttonBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: qgcPal.colorBlue
                                QGCLabel {
                                    anchors.centerIn: parent
                                    text: (index + 1).toString()
                                    font.bold: true
                                }
                            }
                            QGCLabel {
                                Layout.fillWidth: true
                                font.family: ScreenTools.fixedFontFamily
                                text: qsTr("x %1  y %2").arg(model.x.toFixed(1)).arg(model.y.toFixed(1))
                            }
                            QGCButton {
                                text: qsTr("DEL")
                                onClicked: waypointModel.remove(index)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            QGCLabel {
                                text: qsTr("ALT")
                                font.pointSize: ScreenTools.smallFontPointSize
                            }
                            Slider {
                                Layout.fillWidth: true
                                from: 0.5
                                to: 8.0
                                stepSize: 0.1
                                value: -model.z
                                onMoved: model.z = -value
                            }
                            QGCLabel {
                                text: (-model.z).toFixed(1) + " m"
                                font.bold: true
                                color: qgcPal.colorBlue
                            }
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.buttonBorder }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("TARGET") }
            QGCComboBox {
                id: targetCombo
                Layout.fillWidth: true
                model: {
                    var opts = [qsTr("All connected vehicles")]
                    var states = swarmBridge ? swarmBridge.droneStates : []
                    for (var i = 0; i < states.length; i++) {
                        opts.push(qsTr("Vehicle %1").arg(states[i].sysid))
                    }
                    return opts
                }
            }
        }

        QGCDelayButton {
            Layout.fillWidth: true
            text: qsTr("UPLOAD MISSION")
            enabled: _canUpload
            onActivated: {
                var wps = []
                for (var i = 0; i < _wpCount; i++) {
                    wps.push(waypointModel.get(i))
                }
                var sysid = -1
                if (targetCombo.currentIndex > 0 && swarmBridge) {
                    var states = swarmBridge.droneStates
                    var idx = targetCombo.currentIndex - 1
                    if (idx >= 0 && idx < states.length) {
                        sysid = states[idx].sysid
                    }
                }
                root.uploadMission(sysid, wps)
            }
        }

        QGCButton {
            Layout.fillWidth: true
            text: qsTr("CLEAR PLAN")
            enabled: _hasWaypoints
            onClicked: {
                waypointModel.clear()
                root.clearMission()
            }
        }
    }
}
