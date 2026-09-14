/****************************************************************************
 *
 * ASTHRA Swarm Backend — overlay panel on the FLY map.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import ASTHRA.Swarm

Rectangle {
    id: root

    property var swarmClient: null

    color:          qgcPal.window
    border.width:   2
    border.color:   qgcPal.buttonBorder
    clip:           true
    width:          ScreenTools.defaultFontPixelWidth * 28
    implicitHeight: mainColumn.implicitHeight + ScreenTools.defaultFontPixelHeight
    height:         implicitHeight

    QGCPalette { id: qgcPal }

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.4

        RowLayout {
            Layout.fillWidth: true
            QGCLabel {
                text: qsTr("SWARM")
                font.family: ScreenTools.fixedFontFamily
                font.bold: true
                Layout.fillWidth: true
            }
            Rectangle {
                width: 8; height: 8
                color: swarmClient && swarmClient.connected ? qgcPal.colorGreen : qgcPal.colorRed
                border.width: 1
                border.color: Qt.darker(color, 1.4)
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            text: swarmClient && swarmClient.connected ? qsTr("Backend connected") : qsTr("Backend offline — start swarm-backend")
            font.family: ScreenTools.fixedFontFamily
            font.pointSize: ScreenTools.smallFontPointSize
            color: swarmClient && swarmClient.connected ? qgcPal.colorGreen : qgcPal.colorGrey
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            QGCButton {
                text: qsTr("CONNECT")
                Layout.fillWidth: true
                enabled: swarmClient && !swarmClient.connected
                onClicked: swarmClient.connectToBackend()
            }
            QGCButton {
                text: qsTr("STOP")
                Layout.fillWidth: true
                enabled: swarmClient && swarmClient.connected
                onClicked: swarmClient.disconnectFromBackend()
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.buttonBorder }

        QGCLabel {
            text: qsTr("Drones: %1").arg(swarmClient && swarmClient.drones ? swarmClient.drones.length : 0)
            font.family: ScreenTools.fixedFontFamily
            font.bold: true
        }

        QGCLabel {
            visible: !swarmClient || !swarmClient.drones || swarmClient.drones.length === 0
            Layout.fillWidth: true
            text: qsTr("No swarm drones yet. Connect vehicles with DUAL, or start swarm-backend with serial links.")
            font.family: ScreenTools.fixedFontFamily
            font.pointSize: ScreenTools.smallFontPointSize
            color: "#8B9199"
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: swarmClient ? swarmClient.drones : []

            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: droneInfo.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.6
                height: implicitHeight
                color: qgcPal.windowShadeDark
                border.width: 1
                border.color: qgcPal.buttonBorder

                property var drone: modelData

                ColumnLayout {
                    id: droneInfo
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel {
                            text: qsTr("DRONE %1").arg(drone.droneId)
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                        }
                        QGCLabel {
                            text: drone.armed ? qsTr("ARMED") : qsTr("DISARMED")
                            color: drone.armed ? qgcPal.colorRed : qgcPal.colorGreen
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        QGCLabel {
                            text: drone.batteryPct >= 0 ? qsTr("%1%").arg(drone.batteryPct) : "--"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            color: {
                                if (drone.batteryPct < 0) return qgcPal.text
                                if (drone.batteryPct < 20) return qgcPal.colorRed
                                if (drone.batteryPct < 50) return qgcPal.colorYellow
                                return qgcPal.colorGreen
                            }
                        }
                    }

                    QGCLabel {
                        text: qsTr("MODE  %1").arg(drone.flightMode && drone.flightMode.length ? drone.flightMode : "—")
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                    }

                    QGCLabel {
                        text: qsTr("GPS   %1, %2  %3 m")
                              .arg(drone.lat.toFixed(5))
                              .arg(drone.lng.toFixed(5))
                              .arg(drone.alt.toFixed(1))
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        QGCButton {
                            text: qsTr("ARM")
                            Layout.fillWidth: true
                            enabled: swarmClient && swarmClient.connected && !drone.armed
                            onClicked: swarmClient.sendArm(drone.droneId)
                        }
                        QGCButton {
                            text: qsTr("DISARM")
                            Layout.fillWidth: true
                            enabled: swarmClient && swarmClient.connected && drone.armed
                            onClicked: swarmClient.sendDisarm(drone.droneId)
                        }
                    }
                }
            }
        }
    }
}
