/****************************************************************************
 *
 * ASTHRA Swarm Backend Integration
 * Map items for displaying swarm drones
 *
 ****************************************************************************/

import QtQuick
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import ASTHRA.Swarm

/// Displays swarm drones as markers on the map
Item {
    id: root

    property var map
    property var swarmClient: null

    QGCPalette { id: qgcPal }

    Repeater {
        model: swarmClient ? swarmClient.drones : []

        delegate: MapQuickItem {
            id: droneMarker
            property var drone: modelData
            
            anchorPoint.x: droneIcon.width / 2
            anchorPoint.y: droneIcon.height / 2
            coordinate: drone.coordinate
            visible: drone.coordinate.isValid

            sourceItem: Item {
                id: droneIcon
                width: ScreenTools.defaultFontPixelHeight * 3
                height: ScreenTools.defaultFontPixelHeight * 3

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: drone.armed ? "#E74C3C" : "#3498DB"
                    border.color: "white"
                    border.width: 2
                    opacity: 0.9

                    QGCLabel {
                        anchors.centerIn: parent
                        text: drone.droneId
                        color: "white"
                        font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                    }
                }

                // Direction indicator (simple arrow pointing north for now)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 2
                    width: 0
                    height: 0
                    border.width: 6
                    border.color: "transparent"
                    color: "transparent"
                    
                    Canvas {
                        anchors.centerIn: parent
                        width: 12
                        height: 8
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.fillStyle = drone.armed ? "#E74C3C" : "#3498DB"
                            ctx.beginPath()
                            ctx.moveTo(6, 0)
                            ctx.lineTo(0, 8)
                            ctx.lineTo(12, 8)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                }

                // Battery indicator
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 4
                    width: 30
                    height: 10
                    radius: 2
                    color: "#2C3E50"
                    border.color: "white"
                    border.width: 1
                    visible: drone.batteryPct >= 0

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: Math.max(2, (parent.width - 4) * drone.batteryPct / 100)
                        radius: 1
                        color: {
                            if (drone.batteryPct < 20) return "#E74C3C"
                            if (drone.batteryPct < 50) return "#F39C12"
                            return "#27AE60"
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: droneInfoPopup.open()
                }

                // Info popup on click
                QGCMenu {
                    id: droneInfoPopup
                    
                    QGCLabel {
                        text: qsTr("Drone %1").arg(drone.droneId)
                        font.bold: true
                        padding: ScreenTools.defaultFontPixelWidth
                    }
                    
                    QGCLabel {
                        text: qsTr("Position: %1, %2").arg(drone.lat.toFixed(6)).arg(drone.lng.toFixed(6))
                        padding: ScreenTools.defaultFontPixelWidth
                    }
                    
                    QGCLabel {
                        text: qsTr("Altitude: %1 m").arg(drone.alt.toFixed(1))
                        padding: ScreenTools.defaultFontPixelWidth
                    }
                    
                    QGCLabel {
                        text: qsTr("Battery: %1%").arg(drone.batteryPct >= 0 ? drone.batteryPct : "--")
                        padding: ScreenTools.defaultFontPixelWidth
                    }
                    
                    QGCLabel {
                        text: qsTr("Mode: %1").arg(drone.flightMode)
                        padding: ScreenTools.defaultFontPixelWidth
                    }
                    
                    QGCLabel {
                        text: qsTr("Armed: %1").arg(drone.armed ? qsTr("YES") : qsTr("NO"))
                        color: drone.armed ? qgcPal.colorRed : qgcPal.colorGreen
                        padding: ScreenTools.defaultFontPixelWidth
                    }
                    
                    MenuSeparator {}
                    
                    QGCMenuItem {
                        text: qsTr("ARM")
                        enabled: !drone.armed
                        onTriggered: swarmClient.sendArm(drone.droneId)
                    }
                    
                    QGCMenuItem {
                        text: qsTr("DISARM")
                        enabled: drone.armed
                        onTriggered: swarmClient.sendDisarm(drone.droneId)
                    }
                    
                    QGCMenuItem {
                        text: qsTr("Set GUIDED")
                        onTriggered: swarmClient.sendSetMode(drone.droneId, "GUIDED")
                    }
                    
                    QGCMenuItem {
                        text: qsTr("Set LOITER")
                        onTriggered: swarmClient.sendSetMode(drone.droneId, "LOITER")
                    }
                    
                    QGCMenuItem {
                        text: qsTr("Set RTL")
                        onTriggered: swarmClient.sendSetMode(drone.droneId, "RTL")
                    }
                }
            }
        }
    }
}
