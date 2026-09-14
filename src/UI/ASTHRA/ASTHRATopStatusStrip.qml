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
    property var _vehicle1: null
    property var _vehicle2: null
    property var _vehicle3: null
    property bool _dualVehicleMode: false

    function updateVehicles() {
        var count = QGroundControl.multiVehicleManager.vehicles.count
        _vehicle1 = (count > 0) ? QGroundControl.multiVehicleManager.vehicles.get(0) : null
        _vehicle2 = (count > 1) ? QGroundControl.multiVehicleManager.vehicles.get(1) : null
        _vehicle3 = (count > 2) ? QGroundControl.multiVehicleManager.vehicles.get(2) : null
        _dualVehicleMode = count >= 2
        console.log("ASTHRA TopStrip: Vehicle count:", count, "V1:", _vehicle1 ? _vehicle1.id : "null", "V2:", _vehicle2 ? _vehicle2.id : "null", "V3:", _vehicle3 ? _vehicle3.id : "null")
    }

    Component.onCompleted: {
        updateVehicles()
    }

    Connections {
        target: QGroundControl.multiVehicleManager.vehicles
        function onCountChanged() {
            updateVehicles()
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(activeVehicle) {
            updateVehicles()
        }
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

        // Vehicle ID - Military Format: VEHICLE-01 (or V1/V2 in dual mode)
        QGCLabel {
            visible: !_dualVehicleMode
            text:       _activeVehicle ? ("VEHICLE-" + padNumber(_activeVehicle.id, 2)) : "VEHICLE-NONE"
            function padNumber(num, width) {
                var str = num.toString()
                while (str.length < width) str = "0" + str
                return str
            }
            color:      _activeVehicle ? qgcPal.colorGreen : qgcPal.colorGrey
            font.weight: Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.1
            font.family: ScreenTools.fixedFontFamily
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        }

        // Dual Vehicle Display
        RowLayout {
            visible: _dualVehicleMode
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            QGCLabel {
                text:       "V1:" + (_vehicle1 ? padNumber(_vehicle1.id, 2) : "XX")
                color:      _vehicle1 ? qgcPal.colorBlue : qgcPal.colorGrey
                font.weight: Font.Bold
                font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                font.family: ScreenTools.fixedFontFamily
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
            }
            QGCLabel {
                text:       "V2:" + (_vehicle2 ? padNumber(_vehicle2.id, 2) : "XX")
                color:      _vehicle2 ? qgcPal.colorGreen : qgcPal.colorGrey
                font.weight: Font.Bold
                font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                font.family: ScreenTools.fixedFontFamily
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
            }
            QGCLabel {
                visible:    QGroundControl.multiVehicleManager.vehicles.count >= 3
                text:       "V3:" + (_vehicle3 ? padNumber(_vehicle3.id, 2) : "XX")
                color:      _vehicle3 ? qgcPal.colorYellow : qgcPal.colorGrey
                font.weight: Font.Bold
                font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                font.family: ScreenTools.fixedFontFamily
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
            }
            function padNumber(num, width) {
                var str = num.toString()
                while (str.length < width) str = "0" + str
                return str
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

        // Flight Mode - Single or Dual
        QGCLabel {
            visible: !_dualVehicleMode && _activeVehicle
            text:       "MODE: " + (_activeVehicle ? _activeVehicle.flightMode.toUpperCase() : "STANDBY")
            color:      qgcPal.text
            font.weight: Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.1
            font.family: ScreenTools.fixedFontFamily
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 16
            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            elide: Text.ElideRight
        }

        // Dual Vehicle Flight Modes
        RowLayout {
            visible: _dualVehicleMode
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            QGCLabel {
                text:       "M1:" + (_vehicle1 ? _vehicle1.flightMode.toUpperCase().substring(0, 4) : "N/A")
                color:      qgcPal.colorBlue
                font.weight: Font.Bold
                font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                font.family: ScreenTools.fixedFontFamily
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7
            }
            QGCLabel {
                text:       "M2:" + (_vehicle2 ? _vehicle2.flightMode.toUpperCase().substring(0, 4) : "N/A")
                color:      qgcPal.colorGreen
                font.weight: Font.Bold
                font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                font.family: ScreenTools.fixedFontFamily
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7
            }
            QGCLabel {
                visible:    QGroundControl.multiVehicleManager.vehicles.count >= 3
                text:       "M3:" + (_vehicle3 ? _vehicle3.flightMode.toUpperCase().substring(0, 4) : "N/A")
                color:      qgcPal.colorYellow
                font.weight: Font.Bold
                font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                font.family: ScreenTools.fixedFontFamily
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7
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

        // Link Status - Single or Dual
        QGCLabel {
            visible: !_dualVehicleMode
            property bool commLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : true
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

        // Dual Vehicle Link Status
        RowLayout {
            visible: _dualVehicleMode
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            Rectangle {
                width: 4
                height: 4
                radius: 2
                color: _vehicle1 && !_vehicle1.vehicleLinkManager.communicationLost ? qgcPal.colorGreen : qgcPal.colorRed
            }
            Rectangle {
                width: 4
                height: 4
                radius: 2
                color: _vehicle2 && !_vehicle2.vehicleLinkManager.communicationLost ? qgcPal.colorGreen : qgcPal.colorRed
            }
            Rectangle {
                visible: QGroundControl.multiVehicleManager.vehicles.count >= 3
                width: 4
                height: 4
                radius: 2
                color: _vehicle3 && !_vehicle3.vehicleLinkManager.communicationLost ? qgcPal.colorGreen : qgcPal.colorRed
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

