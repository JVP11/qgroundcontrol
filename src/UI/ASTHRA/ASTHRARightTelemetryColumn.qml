/****************************************************************************
 *
 * ASTHRA - Right Telemetry & Data Column
 * Continuous Data Monitoring Panel
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Right Telemetry & Data Column - Military Instrumentation
/// Stacked data blocks, table-like, section headers, fixed spacing, no animations
    Rectangle {
        id:             telemetryColumn
        width:          ScreenTools.defaultFontPixelWidth * 32  // Industrial standard - wider for readability
    anchors.right:  parent.right
    anchors.top:    parent.top
    anchors.bottom: parent.bottom
    color:          qgcPal.windowShade  // Battlefield Grey
    border.width:   2  // Stronger border
    border.color:   qgcPal.buttonBorder  // Tactical Steel

    // Left border highlight for depth
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Qt.darker(qgcPal.buttonBorder, 1.4)
    }

    // Top highlight line
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.lighter(qgcPal.windowShade, 1.15)
        opacity: 0.4
    }

    // Military corner brackets - All corners (optimized Rectangle-based for performance)
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 3
        width: 10
        height: 10
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 2; height: 10; color: qgcPal.buttonBorder }
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 10; height: 2; color: qgcPal.buttonBorder }
    }

    Item {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 3
        width: 10
        height: 10
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 2; height: 10; color: qgcPal.buttonBorder }
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 10; height: 2; color: qgcPal.buttonBorder }
    }

    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 3
        width: 10
        height: 10
        Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 2; height: 10; color: qgcPal.buttonBorder }
        Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 10; height: 2; color: qgcPal.buttonBorder }
    }

    Item {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 3
        width: 10
        height: 10
        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 2; height: 10; color: qgcPal.buttonBorder }
        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 10; height: 2; color: qgcPal.buttonBorder }
    }

    QGCPalette { id: qgcPal }

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _vehicles: QGroundControl.multiVehicleManager.vehicles
    property int _fleetCount: _vehicles ? _vehicles.count : 0
    property bool _fleetMode: _fleetCount >= 2

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

    function factNum(obj, fallback) {
        if (fallback === undefined)
            fallback = 0
        if (!obj)
            return fallback
        var v = obj.rawValue
        if (v === undefined || v === null)
            v = obj.value
        var n = Number(v)
        return isFinite(n) ? n : fallback
    }

    function vehNum(veh, name, fallback) {
        if (!veh)
            return fallback === undefined ? 0 : fallback
        return factNum(veh[name], fallback === undefined ? 0 : fallback)
    }

    function slotOf(index) {
        var veh = fleetVehicle(index)
        return (veh && veh.fleetSlot) ? veh.fleetSlot : (index + 1)
    }

    property real _moduleHeight: ScreenTools.defaultFontPixelHeight * 6.5  // Industrial standard - taller modules
    property real _labelWidth: ScreenTools.defaultFontPixelWidth * 12  // Industrial standard - wider labels
    property real _valueWidth: ScreenTools.defaultFontPixelWidth * 14  // Industrial standard - wider values

    // Industrial Standard Padding Function
    function padString(str, width) {
        var s = str.toString()
        while (s.length < width) s = " " + s
        return s
    }

    // Get vehicle for display (for dual mode, show both)
    function getVehicle(index) {
        if (_fleetMode)
            return fleetVehicle(index)
        return _activeVehicle
    }

    clip: true

    Flickable {
        id:                 rightFlick
        anchors.fill:       parent
        anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.6
        clip:               true
        boundsBehavior:     Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        contentWidth:       width
        contentHeight:      rightCol.implicitHeight

        ColumnLayout {
            id:      rightCol
            width:   rightFlick.width
            spacing: ScreenTools.defaultFontPixelWidth * 0.6

        // ATTITUDE Block - Stacked Data Format with Industrial Depth
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: _moduleHeight * 0.9
            color:              qgcPal.windowShadeDark  // Industrial Slate
            border.width:       2  // Stronger border
            border.color:       qgcPal.buttonBorder  // Tactical Steel

            // Military corner brackets on panel
            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 2
                width: 6
                height: 6
            }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1; height: 6; color: qgcPal.colorBlue }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 6; height: 1; color: qgcPal.colorBlue }

            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 2
                width: 6
                height: 6
            }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1; height: 6; color: qgcPal.colorBlue }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 6; height: 1; color: qgcPal.colorBlue }

            // Tactical crosshair indicator in top-right
            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 4
                width: 12
                height: 12

                // Horizontal line
                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 1
                    color: qgcPal.colorGreen
                    opacity: 0.6
                }

                // Vertical line
                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: 8
                    color: qgcPal.colorGreen
                    opacity: 0.6
                }
            }

            // Inner bevel effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: "transparent"
                border.width: 1
                border.color: Qt.darker(qgcPal.windowShadeDark, 1.2)
            }

            // Top highlight for inset effect
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 2
                height: 1
                color: Qt.lighter(qgcPal.windowShadeDark, 1.1)
                opacity: 0.3
            }

            ColumnLayout {
                anchors.fill:       parent
                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.5
                spacing:            ScreenTools.defaultFontPixelWidth * 0.3  // Tight spacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.3
                    QGCLabel {
                        text:           "ATTITUDE"
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                        font.weight:    Font.Bold
                        font.letterSpacing: 1.5
                        font.family:    ScreenTools.fixedFontFamily
                        color:          qgcPal.text
                        Layout.fillWidth: !_fleetMode
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            text:           "V" + telemetryColumn.slotOf(index)
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.8
                            font.weight:    Font.Bold
                            font.family:    ScreenTools.fixedFontFamily
                            color:          telemetryColumn.fleetColor(index)
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4
                        }
                    }
                }

                // Table-like format: ROLL   +0.00°  (V1)  +0.00° (V2)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:       "ROLL:"
                        font.weight: Font.DemiBold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                        font.family: ScreenTools.fixedFontFamily
                        color:      qgcPal.text
                        Layout.preferredWidth: _labelWidth * 0.8
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }
                    QGCLabel {
                        visible: !_fleetMode
                        Layout.fillWidth: true
                        property real roll: telemetryColumn.vehNum(_activeVehicle, "roll", 0)
                        text:       (roll >= 0 ? "+" : "") + padString(roll.toFixed(2), 6) + "°"
                        color:      qgcPal.text
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                            property real roll: {
                                var veh = telemetryColumn.fleetVehicle(index)
                                return telemetryColumn.vehNum(telemetryColumn.fleetVehicle(index), "roll", 0)
                            }
                            text:       (roll >= 0 ? "+" : "") + padString(roll.toFixed(2), 6) + "°"
                            color:      telemetryColumn.fleetColor(index)
                            font.family: ScreenTools.fixedFontFamily
                            font.weight: Font.Bold
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // PITCH   +0.00°  (V1)  +0.00° (V2)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:       "PITCH:"
                        font.weight: Font.DemiBold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                        font.family: ScreenTools.fixedFontFamily
                        color:      qgcPal.text
                        Layout.preferredWidth: _labelWidth * 0.8
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }
                    QGCLabel {
                        visible: !_fleetMode
                        Layout.fillWidth: true
                        property real pitch: telemetryColumn.vehNum(_activeVehicle, "pitch", 0)
                        text:       (pitch >= 0 ? "+" : "") + padString(pitch.toFixed(2), 6) + "°"
                        color:      qgcPal.text
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                            property real pitch: {
                                var veh = telemetryColumn.fleetVehicle(index)
                                return telemetryColumn.vehNum(telemetryColumn.fleetVehicle(index), "pitch", 0)
                            }
                            text:       (pitch >= 0 ? "+" : "") + padString(pitch.toFixed(2), 6) + "°"
                            color:      telemetryColumn.fleetColor(index)
                            font.family: ScreenTools.fixedFontFamily
                            font.weight: Font.Bold
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // YAW    +0.00°  (V1)  +0.00° (V2)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:       "YAW:"
                        font.weight: Font.DemiBold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                        font.family: ScreenTools.fixedFontFamily
                        color:      qgcPal.text
                        Layout.preferredWidth: _labelWidth * 0.8
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }
                    QGCLabel {
                        visible: !_fleetMode
                        Layout.fillWidth: true
                        property real yaw: telemetryColumn.vehNum(_activeVehicle, "heading", 0)
                        text:       padString(yaw.toFixed(2), 6) + "°"
                        color:      qgcPal.text
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                            property real yaw: {
                                var veh = telemetryColumn.fleetVehicle(index)
                                return telemetryColumn.vehNum(telemetryColumn.fleetVehicle(index), "heading", 0)
                            }
                            text:       padString(yaw.toFixed(2), 6) + "°"
                            color:      telemetryColumn.fleetColor(index)
                            font.family: ScreenTools.fixedFontFamily
                            font.weight: Font.Bold
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }

        // ALT / SPEED Block - Stacked Data Format with Industrial Depth
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: _moduleHeight * 0.9
            color:              qgcPal.windowShadeDark
            border.width:       2
            border.color:       qgcPal.buttonBorder

            // Inner bevel effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: "transparent"
                border.width: 1
                border.color: Qt.darker(qgcPal.windowShadeDark, 1.2)
            }

            // Top highlight for inset effect
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 2
                height: 1
                color: Qt.lighter(qgcPal.windowShadeDark, 1.1)
                opacity: 0.3
            }

            ColumnLayout {
                anchors.fill:       parent
                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.5
                spacing:            ScreenTools.defaultFontPixelWidth * 0.3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.3

                    // Military status dot
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: _activeVehicle ? qgcPal.colorGreen : qgcPal.colorGrey
                        border.width: 1
                        border.color: Qt.darker(color, 1.2)
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }

                    QGCLabel {
                        text:           "ALT / SPEED"
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                        font.weight:    Font.Bold
                        font.letterSpacing: 1.5
                        font.family:    ScreenTools.fixedFontFamily
                        color:          qgcPal.text
                        Layout.fillWidth: !_fleetMode
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            text:           "V" + telemetryColumn.slotOf(index)
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.8
                            font.weight:    Font.Bold
                            font.family:    ScreenTools.fixedFontFamily
                            color:          telemetryColumn.fleetColor(index)
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4
                        }
                    }
                }

                // ALT    0.00 m  (V1)  0.00 m (V2)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:       "ALT:"
                        font.weight: Font.DemiBold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                        font.family: ScreenTools.fixedFontFamily
                        color:      qgcPal.text
                        Layout.preferredWidth: _labelWidth * 0.8
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }
                    QGCLabel {
                        visible: !_fleetMode
                        Layout.fillWidth: true
                        property real altitude: telemetryColumn.vehNum(_activeVehicle, "altitudeRelative", 0)
                        text:       padString(altitude.toFixed(2), 7) + " m"
                        color:      qgcPal.text
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                            property real altitude: {
                                var veh = telemetryColumn.fleetVehicle(index)
                                return telemetryColumn.vehNum(telemetryColumn.fleetVehicle(index), "altitudeRelative", 0)
                            }
                            text:       padString(altitude.toFixed(2), 7) + " m"
                            color:      telemetryColumn.fleetColor(index)
                            font.family: ScreenTools.fixedFontFamily
                            font.weight: Font.Bold
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // SPD    0.00 m/s  (V1)  0.00 m/s (V2)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:       "SPD:"
                        font.weight: Font.DemiBold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                        font.family: ScreenTools.fixedFontFamily
                        color:      qgcPal.text
                        Layout.preferredWidth: _labelWidth * 0.8
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }
                    QGCLabel {
                        visible: !_fleetMode
                        Layout.fillWidth: true
                        property real speed: telemetryColumn.vehNum(_activeVehicle, "groundSpeed", 0)
                        text:       padString(speed.toFixed(2), 7) + " m/s"
                        color:      qgcPal.text
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                            property real speed: {
                                var veh = telemetryColumn.fleetVehicle(index)
                                return telemetryColumn.vehNum(telemetryColumn.fleetVehicle(index), "groundSpeed", 0)
                            }
                            text:       padString(speed.toFixed(2), 7) + " m/s"
                            color:      telemetryColumn.fleetColor(index)
                            font.family: ScreenTools.fixedFontFamily
                            font.weight: Font.Bold
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // VSPD   0.00 m/s  (V1)  0.00 m/s (V2)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:       "VSPD:"
                        font.weight: Font.DemiBold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                        font.family: ScreenTools.fixedFontFamily
                        color:      qgcPal.text
                        Layout.preferredWidth: _labelWidth * 0.8
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }
                    QGCLabel {
                        visible: !_fleetMode
                        Layout.fillWidth: true
                        property real vSpeed: telemetryColumn.vehNum(_activeVehicle, "climbRate", 0)
                        text:       (vSpeed >= 0 ? "+" : "") + padString(vSpeed.toFixed(2), 6) + " m/s"
                        color:      vSpeed > 0 ? qgcPal.colorGreen : (vSpeed < 0 ? qgcPal.colorRed : qgcPal.text)
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                            property real vSpeed: {
                                var veh = telemetryColumn.fleetVehicle(index)
                                return telemetryColumn.vehNum(telemetryColumn.fleetVehicle(index), "climbRate", 0)
                            }
                            text:       (vSpeed >= 0 ? "+" : "") + padString(vSpeed.toFixed(2), 6) + " m/s"
                            color:      vSpeed > 0 ? qgcPal.colorGreen : (vSpeed < 0 ? qgcPal.colorRed : telemetryColumn.fleetColor(index))
                            font.family: ScreenTools.fixedFontFamily
                            font.weight: Font.Bold
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }

        // GPS Block - Stacked Data Format with Industrial Depth
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: _moduleHeight * 0.8
            color:              qgcPal.windowShadeDark
            border.width:       2
            border.color:       qgcPal.buttonBorder

            // Military corner brackets on panel
            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 2
                width: 6
                height: 6
            }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1; height: 6; color: qgcPal.colorBlue }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 6; height: 1; color: qgcPal.colorBlue }

            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 2
                width: 6
                height: 6
            }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1; height: 6; color: qgcPal.colorBlue }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 6; height: 1; color: qgcPal.colorBlue }

            // Inner bevel effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: "transparent"
                border.width: 1
                border.color: Qt.darker(qgcPal.windowShadeDark, 1.2)
            }

            // Top highlight for inset effect
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 2
                height: 1
                color: Qt.lighter(qgcPal.windowShadeDark, 1.1)
                opacity: 0.3
            }

            ColumnLayout {
                anchors.fill:       parent
                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.5
                spacing:            ScreenTools.defaultFontPixelWidth * 0.3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.3
                    QGCLabel {
                        text:           "GPS"
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                        font.weight:    Font.Bold
                        font.letterSpacing: 1.5
                        font.family:    ScreenTools.fixedFontFamily
                        color:          qgcPal.text
                        Layout.fillWidth: !_fleetMode
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            text:           "V" + telemetryColumn.slotOf(index)
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.8
                            font.weight:    Font.Bold
                            font.family:    ScreenTools.fixedFontFamily
                            color:          telemetryColumn.fleetColor(index)
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4
                        }
                    }
                }

                // HDOP   0.000
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:       "HDOP:"
                        font.weight: Font.DemiBold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                        font.family: ScreenTools.fixedFontFamily
                        color:      qgcPal.text
                        Layout.preferredWidth: _labelWidth * 0.8
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }
                    QGCLabel {
                        visible: !_fleetMode
                        Layout.fillWidth: true
                        property real hdop: (_activeVehicle && _activeVehicle.gpsHDOP) ? _activeVehicle.gpsHDOP.value : 0
                        text:       padString(hdop.toFixed(3), 6)
                        color:      hdop <= 0 ? qgcPal.colorGrey : (hdop < 1.0 ? qgcPal.colorGreen : (hdop < 2.0 ? qgcPal.colorYellow : qgcPal.colorOrange))
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                            property real hdop: {
                                var veh = telemetryColumn.fleetVehicle(index)
                                return (veh && veh.gpsHDOP) ? veh.gpsHDOP.value : 0
                            }
                            text:       padString(hdop.toFixed(3), 6)
                            color:      hdop <= 0 ? qgcPal.colorGrey : (hdop < 1.0 ? qgcPal.colorGreen : (hdop < 2.0 ? qgcPal.colorYellow : qgcPal.colorOrange))
                            font.family: ScreenTools.fixedFontFamily
                            font.weight: Font.Bold
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // VDOP   0.000
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:       "VDOP:"
                        font.weight: Font.DemiBold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                        font.family: ScreenTools.fixedFontFamily
                        color:      qgcPal.text
                        Layout.preferredWidth: _labelWidth * 0.8
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }
                    QGCLabel {
                        visible: !_fleetMode
                        Layout.fillWidth: true
                        property real vdop: (_activeVehicle && _activeVehicle.gpsVDOP) ? _activeVehicle.gpsVDOP.value : 0
                        text:       padString(vdop.toFixed(3), 6)
                        color:      vdop <= 0 ? qgcPal.colorGrey : (vdop < 1.5 ? qgcPal.colorGreen : (vdop < 2.5 ? qgcPal.colorYellow : qgcPal.colorOrange))
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    Repeater {
                        model: _fleetMode ? telemetryColumn._fleetCount : 0
                        QGCLabel {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                            property real vdop: {
                                var veh = telemetryColumn.fleetVehicle(index)
                                return (veh && veh.gpsVDOP) ? veh.gpsVDOP.value : 0
                            }
                            text:       padString(vdop.toFixed(3), 6)
                            color:      vdop <= 0 ? qgcPal.colorGrey : (vdop < 1.5 ? qgcPal.colorGreen : (vdop < 2.5 ? qgcPal.colorYellow : qgcPal.colorOrange))
                            font.family: ScreenTools.fixedFontFamily
                            font.weight: Font.Bold
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }

        // Payload Status Module - Industrial Standard with Depth
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: _moduleHeight * 0.7
            color:              qgcPal.windowShadeDark
            border.width:       2
            border.color:       qgcPal.buttonBorder

            // Military corner brackets on panel
            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 2
                width: 6
                height: 6
            }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1; height: 6; color: qgcPal.colorBlue }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 6; height: 1; color: qgcPal.colorBlue }

            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 2
                width: 6
                height: 6
            }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1; height: 6; color: qgcPal.colorBlue }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 6; height: 1; color: qgcPal.colorBlue }

            // Inner bevel effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: "transparent"
                border.width: 1
                border.color: Qt.darker(qgcPal.windowShadeDark, 1.2)
            }

            // Top highlight for inset effect
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 2
                height: 1
                color: Qt.lighter(qgcPal.windowShadeDark, 1.1)
                opacity: 0.3
            }

            ColumnLayout {
                anchors.fill:       parent
                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.5
                spacing:            ScreenTools.defaultFontPixelWidth * 0.5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.3

                    // Military status dot
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: qgcPal.colorGrey  // Default grey for payload
                        border.width: 1
                        border.color: Qt.darker(color, 1.2)
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }

                    QGCLabel {
                        text:           "PAYLOAD STATUS"
                        font.pointSize: ScreenTools.defaultFontPointSize
                        font.weight:    Font.Bold
                        font.letterSpacing: 1.5
                        font.family:    ScreenTools.fixedFontFamily
                        color:          qgcPal.buttonBorder
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    QGCLabel {
                        text:       "STATUS:"
                        font.weight: Font.DemiBold
                        font.family: ScreenTools.fixedFontFamily
                        color:      qgcPal.text
                        opacity:    0.7
                        Layout.preferredWidth: _labelWidth
                    }
                    QGCLabel {
                        text:       "NO DATA"
                        color:      qgcPal.colorGrey
                        font.weight: Font.Bold
                        font.family: ScreenTools.fixedFontFamily
                        opacity:    0.7
                        Layout.preferredWidth: _valueWidth
                    }
                }
            }
        }

        }
    }
}

