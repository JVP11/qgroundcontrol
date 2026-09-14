// ASTHRA Swarm — industrial status strip

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root

    property var swarmBridge
    property var waypointModel
    property int selectedDroneId: -1

    height: ScreenTools.defaultFontPixelHeight * 2.8
    color: qgcPal.toolbarBackground
    border.width: 1
    border.color: qgcPal.buttonBorder

    QGCPalette { id: qgcPal }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelWidth * 2

        QGCLabel {
            text: qsTr("ASTHRA SWARM")
            font.family: ScreenTools.fixedFontFamily
            font.weight: Font.Bold
            font.pointSize: ScreenTools.smallFontPointSize
            color: qgcPal.text
        }

        Rectangle { width: 1; height: parent.height * 0.5; color: qgcPal.buttonBorder }

        QGCLabel {
            text: {
                var n = swarmBridge ? swarmBridge.liveVehicleCount : 0
                return qsTr("VEHICLES: %1").arg(n)
            }
            font.family: ScreenTools.fixedFontFamily
            color: swarmBridge && swarmBridge.liveVehicleCount > 0 ? qgcPal.colorGreen : qgcPal.colorRed
        }

        QGCLabel {
            text: {
                var c = waypointModel ? waypointModel.count : 0
                return qsTr("WAYPOINTS: %1").arg(c)
            }
            font.family: ScreenTools.fixedFontFamily
            color: qgcPal.text
        }

        QGCLabel {
            visible: root.selectedDroneId > 0
            text: qsTr("SELECTED: D%1").arg(root.selectedDroneId)
            font.family: ScreenTools.fixedFontFamily
            color: qgcPal.colorBlue
        }

        Item { Layout.fillWidth: true }

        QGCLabel {
            text: {
                if (!swarmBridge) return ""
                if (swarmBridge.liveVehicleCount > 0 && waypointModel && waypointModel.count > 0) {
                    return qsTr("READY TO UPLOAD")
                }
                if (swarmBridge.liveVehicleCount === 0) {
                    return qsTr("CONNECT VEHICLES (DUAL / LINKS)")
                }
                return qsTr("TAP MAP TO ADD WAYPOINTS")
            }
            font.family: ScreenTools.fixedFontFamily
            font.weight: Font.Bold
            color: qgcPal.colorOrange
        }
    }
}
