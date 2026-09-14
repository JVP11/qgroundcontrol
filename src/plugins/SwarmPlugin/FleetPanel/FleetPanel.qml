// ASTHRA Fleet panel — industrial vehicle list and actions

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root

    property var swarmBridge
    property int selectedDroneId: -1

    signal droneSelected(int sysid)
    signal armAll()
    signal disarmAll()
    signal holdAll()
    signal rtlAll()
    signal connectRequested()

    implicitWidth: ScreenTools.defaultFontPixelWidth * 28
    Layout.preferredWidth: implicitWidth
    Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 22
    Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 34
    Layout.fillHeight: true
    color: qgcPal.windowShade

    border.width: 1
    border.color: qgcPal.buttonBorder

    QGCPalette { id: qgcPal }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.5

        RowLayout {
            Layout.fillWidth: true
            QGCLabel {
                text: qsTr("FLEET")
                font.family: ScreenTools.fixedFontFamily
                font.weight: Font.Bold
                Layout.fillWidth: true
            }
            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: swarmBridge && swarmBridge.liveVehicleCount > 0
                       ? qgcPal.colorGreen : qgcPal.colorRed
            }
            QGCLabel {
                text: {
                    if (!swarmBridge) return qsTr("OFFLINE")
                    var n = swarmBridge.liveVehicleCount
                    if (n > 0) return qsTr("%1 LIVE").arg(n)
                    return qsTr("NO LINK")
                }
                font.family: ScreenTools.fixedFontFamily
                font.pointSize: ScreenTools.smallFontPointSize
                color: swarmBridge && swarmBridge.liveVehicleCount > 0
                       ? qgcPal.colorGreen : qgcPal.colorGrey
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: swarmBridge && swarmBridge.coordinatorConnected
            spacing: 4
            Repeater {
                model: ["formation", "hold", "rtl"]
                delegate: QGCButton {
                    Layout.fillWidth: true
                    text: modelData.toUpperCase()
                    font.pointSize: ScreenTools.smallFontPointSize
                    primary: swarmBridge && swarmBridge.swarmMode === modelData
                    onClicked: {
                        swarmBridge.setMode(modelData)
                        if (modelData === "hold") root.holdAll()
                        if (modelData === "rtl") root.rtlAll()
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.buttonBorder }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            QGCLabel {
                anchors.centerIn: parent
                width: parent.width - ScreenTools.defaultFontPixelWidth * 2
                visible: !swarmBridge || swarmBridge.droneStates.length === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("No vehicles connected.\n\nUse DUAL or Comm Links to connect drones, then positions appear on the map.")
                color: qgcPal.colorGrey
                font.family: ScreenTools.fixedFontFamily
            }

            ListView {
                anchors.fill: parent
                visible: swarmBridge && swarmBridge.droneStates.length > 0
                model: swarmBridge ? swarmBridge.droneStates : []
                spacing: 6
                clip: true

                delegate: Rectangle {
                    property var drone: modelData
                    property bool selected: drone.sysid === root.selectedDroneId
                    property bool hasPos: drone.has_local_position !== false

                    width: ListView.view.width
                    height: ScreenTools.defaultFontPixelHeight * 5.5
                    radius: 4
                    color: selected ? qgcPal.colorBlue : qgcPal.windowShadeDark
                    border.color: selected ? qgcPal.colorBlue : qgcPal.buttonBorder
                    border.width: selected ? 2 : 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.droneSelected(drone.sysid)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.6
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            QGCLabel {
                                text: qsTr("VEHICLE %1").arg(drone.sysid)
                                font.family: ScreenTools.fixedFontFamily
                                font.weight: Font.Bold
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                width: 48
                                height: 18
                                radius: 3
                                color: drone.armed ? qgcPal.colorGreen : qgcPal.colorGrey
                                QGCLabel {
                                    anchors.centerIn: parent
                                    text: drone.armed ? qsTr("ARMED") : qsTr("SAFE")
                                    font.pointSize: ScreenTools.smallFontPointSize * 0.85
                                    font.bold: true
                                }
                            }
                        }

                        QGCLabel {
                            text: drone.mode
                            font.family: ScreenTools.fixedFontFamily
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: qgcPal.colorGrey
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            QGCLabel {
                                text: drone.battery_pct < 0 ? qsTr("BAT --%") : qsTr("BAT %1%").arg(drone.battery_pct)
                                font.family: ScreenTools.fixedFontFamily
                                color: drone.battery_pct < 0 ? qgcPal.colorGrey
                                     : (drone.battery_pct < 25 ? qgcPal.colorRed : qgcPal.colorGreen)
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: qgcPal.buttonBorder
                                visible: drone.battery_pct >= 0
                                Rectangle {
                                    width: parent.width * Math.min(1, drone.battery_pct / 100)
                                    height: parent.height
                                    radius: 2
                                    color: drone.battery_pct < 25 ? qgcPal.colorRed : qgcPal.colorGreen
                                }
                            }
                        }

                        QGCLabel {
                            visible: hasPos
                            text: qsTr("NED  x%1  y%2  alt %3m")
                                .arg(drone.x.toFixed(1))
                                .arg(drone.y.toFixed(1))
                                .arg((-drone.z).toFixed(1))
                            font.family: ScreenTools.fixedFontFamily
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: qgcPal.text
                        }
                        QGCLabel {
                            visible: !hasPos
                            text: qsTr("Waiting for position (LOCAL_POSITION_NED or GPS fix)…")
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: qgcPal.colorOrange
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.buttonBorder }

        QGCButton {
            Layout.fillWidth: true
            text: qsTr("CONNECT VEHICLES")
            onClicked: root.connectRequested()
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: ScreenTools.defaultFontPixelWidth * 0.5
            rowSpacing: ScreenTools.defaultFontPixelWidth * 0.5

            QGCDelayButton {
                Layout.fillWidth: true
                text: qsTr("ARM ALL")
                enabled: swarmBridge && swarmBridge.liveVehicleCount > 0
                onActivated: root.armAll()
            }
            QGCDelayButton {
                Layout.fillWidth: true
                text: qsTr("DISARM ALL")
                enabled: swarmBridge && swarmBridge.liveVehicleCount > 0
                onActivated: root.disarmAll()
            }
        }
    }
}
