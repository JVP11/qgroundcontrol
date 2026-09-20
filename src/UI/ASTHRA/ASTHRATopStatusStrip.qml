/****************************************************************************
 *
 * ASTHRA - Top Status Strip
 * Military-Industrial System Awareness Bar
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Top Command Status Strip - Military Standard
/// Thin command strip (32-36px), flat background, ALL CAPS, status colors only
    Rectangle {
        id:             statusStrip
        height:         ScreenTools.defaultFontPixelHeight * 3.5  // Industrial standard - larger for readability
    anchors.left:   parent.left
    anchors.right:  parent.right
    anchors.top:    parent.top
    color:          qgcPal.window  // Tactical Black
    border.width:   0
    clip:           true

    // Bottom border for separation with tactical notches
    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2

        Rectangle {
            anchors.fill: parent
            color: qgcPal.buttonBorder
        }

        // Tactical notches along the border
        Repeater {
            model: Math.floor(parent.width / 30)
            Rectangle {
                x: index * 30 + 5
                y: -1
                width: 3
                height: 4
                color: qgcPal.buttonBorder
            }
        }
    }

    // Top highlight line for industrial bevel
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.lighter(qgcPal.window, 1.2)
        opacity: 0.3
    }

    // Military corner brackets - Top Left (optimized Rectangle-based)
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 2
        width: 8
        height: 8
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1.5; height: 8; color: qgcPal.buttonBorder }
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 8; height: 1.5; color: qgcPal.buttonBorder }
    }

    // Military corner brackets - Top Right (optimized Rectangle-based)
    Item {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 2
        width: 8
        height: 8
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1.5; height: 8; color: qgcPal.buttonBorder }
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 8; height: 1.5; color: qgcPal.buttonBorder }
    }

    QGCPalette { id: qgcPal }

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _vehicles: QGroundControl.multiVehicleManager.vehicles
    property int _fleetCount: _vehicles ? _vehicles.count : 0
    property bool _fleetMode: _fleetCount >= 2

    function padNumber(num, width) {
        var str = String(num)
        while (str.length < width)
            str = "0" + str
        return str
    }

    function fleetColor(index) {
        var colors = ["#4A90D9", "#2A8B55", "#C9A227", "#D97706", "#C0392B", "#534AB7"]
        var i = parseInt(index, 10)
        if (isNaN(i) || i < 0)
            i = 0
        return colors[i % colors.length]
    }

    function fleetVehicle(index) {
        if (!_vehicles || index < 0 || index >= _vehicles.count)
            return null
        return _vehicles.get(index)
    }

    function radioTag(veh) {
        if (!veh)
            return "XX"
        var n = ""
        try {
            n = (veh.vehicleLinkManager && veh.vehicleLinkManager.primaryLinkName) ? String(veh.vehicleLinkManager.primaryLinkName) : ""
        } catch (e) {}
        var m = n.match(/ttyACM\d+|ttyUSB\d+|COM\d+/i)
        if (m)
            return m[0]
        return padNumber(veh.id, 2)
    }

    property real _standardSpacing: ScreenTools.defaultFontPixelWidth * 1.2  // Tight spacing
    property real _labelWidth: ScreenTools.defaultFontPixelWidth * 7  // Compact labels

    RowLayout {
        anchors.fill:       parent
        anchors.leftMargin:  ScreenTools.defaultFontPixelWidth * 1.0
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.0
        anchors.topMargin:  ScreenTools.defaultFontPixelHeight * 0.3
        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.3
        spacing:            _standardSpacing

        // ASTHRA Branding - Text-only, military standard with tactical brackets
        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth * 0.3
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

            // Left tactical bracket (optimized)
            Item {
                width: 6
                height: parent.height * 0.6
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1.5; height: parent.height; color: qgcPal.colorBlue }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 6; height: 1.5; color: qgcPal.colorBlue }
            }

            QGCLabel {
                text:               "ASTHRA"
                font.pointSize:     ScreenTools.defaultFontPointSize * 1.2  // Industrial standard - larger
                font.weight:        Font.Bold
                font.letterSpacing: 1.5
                font.family:        ScreenTools.fixedFontFamily
                color:              qgcPal.text
            }

            // Right tactical bracket (optimized)
            Item {
                width: 6
                height: parent.height * 0.6
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1.5; height: parent.height; color: qgcPal.colorBlue }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 6; height: 1.5; color: qgcPal.colorBlue }
            }
        }

        // Separator - Industrial style with depth
        Rectangle {
            width:  2
            height: parent.height * 0.7
            color:   qgcPal.buttonBorder
            Layout.alignment: Qt.AlignVCenter
            // Inner shadow effect
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Qt.darker(qgcPal.buttonBorder, 1.3)
            }
        }

        // Vehicle ID - one drone, or V1..VN for the whole fleet
        QGCLabel {
            visible: !_fleetMode
            text:       _activeVehicle ? ("VEHICLE-" + padNumber(_activeVehicle.id, 2)) : "VEHICLE-NONE"
            color:      _activeVehicle ? qgcPal.colorGreen : qgcPal.colorGrey
            font.weight: Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.1
            font.family: ScreenTools.fixedFontFamily
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        }

        Flickable {
            visible: _fleetMode
            Layout.fillWidth: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 22
            Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 36
            Layout.fillHeight: true
            contentWidth: fleetIdRow.implicitWidth
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            RowLayout {
                id: fleetIdRow
                height: parent.height
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                Repeater {
                    model: statusStrip._fleetCount
                    QGCLabel {
                        property var veh: statusStrip.fleetVehicle(index)
                        text:       "V" + (veh && veh.fleetSlot ? veh.fleetSlot : (index + 1)) + ":" + statusStrip.radioTag(veh)
                        color:      veh ? statusStrip.fleetColor(index) : "#808080"
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                        font.family: ScreenTools.fixedFontFamily
                    }
                }
            }
        }

        // Separator
        Rectangle {
            width:  2
            height: parent.height * 0.7
            color:   qgcPal.buttonBorder
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Qt.darker(qgcPal.buttonBorder, 1.3)
            }
        }

        QGCLabel {
            visible: !_fleetMode && _activeVehicle
            text:       "MODE: " + (_activeVehicle && _activeVehicle.flightMode ? _activeVehicle.flightMode.toUpperCase() : "STANDBY")
            color:      qgcPal.text
            font.weight: Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.1
            font.family: ScreenTools.fixedFontFamily
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 16
            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            elide: Text.ElideRight
        }

        Flickable {
            visible: _fleetMode
            Layout.fillWidth: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20
            Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 32
            Layout.fillHeight: true
            contentWidth: fleetModeRow.implicitWidth
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            RowLayout {
                id: fleetModeRow
                height: parent.height
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                Repeater {
                    model: statusStrip._fleetCount
                    QGCLabel {
                        property var veh: statusStrip.fleetVehicle(index)
                        text:       "M" + (index + 1) + ":" + (veh && veh.flightMode ? veh.flightMode.toUpperCase().substring(0, 4) : "N/A")
                        color:      statusStrip.fleetColor(index)
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                        font.family: ScreenTools.fixedFontFamily
                    }
                }
            }
        }

        // Separator
        Rectangle {
            width:  2
            height: parent.height * 0.7
            color:   qgcPal.buttonBorder
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Qt.darker(qgcPal.buttonBorder, 1.3)
            }
        }

        QGCLabel {
            visible: !_fleetMode
            property bool commLost: (_activeVehicle && _activeVehicle.vehicleLinkManager) ? _activeVehicle.vehicleLinkManager.communicationLost : true
            text:       "LINK: " + (commLost ? "DISCONNECTED" : "CONNECTED")
            color:      commLost ? qgcPal.colorRed : qgcPal.colorGreen
            font.weight: Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.1
            font.family: ScreenTools.fixedFontFamily
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18
            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            elide: Text.ElideRight
        }

        RowLayout {
            visible: _fleetMode
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            Repeater {
                model: statusStrip._fleetCount
                Rectangle {
                    property var veh: statusStrip.fleetVehicle(index)
                    width: 4
                    height: 4
                    radius: 2
                    color: veh && veh.vehicleLinkManager && !veh.vehicleLinkManager.communicationLost ? "#2A8B55" : "#C0392B"
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Separator
        Rectangle {
            width:  2
            height: parent.height * 0.7
            color:   qgcPal.buttonBorder
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Qt.darker(qgcPal.buttonBorder, 1.3)
            }
        }

        // System Time - Military Format: TIME: 14:28:15
                QGCLabel {
                    id: timeLabel
                    text:       "TIME: " + Qt.formatDateTime(new Date(), "HH:mm:ss")
                    color:      qgcPal.text
                    font.family: ScreenTools.fixedFontFamily
                    font.weight: Font.Bold
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.1  // Industrial standard - larger
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 15
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: timeLabel.text = "TIME: " + Qt.formatDateTime(new Date(), "HH:mm:ss")
            }
        }
    }
}

