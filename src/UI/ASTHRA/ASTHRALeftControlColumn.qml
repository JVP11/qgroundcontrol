/****************************************************************************
 *
 * ASTHRA - Left System Control Column
 * Vehicle and System Control Panel
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Left System Control Column - Military Standard
/// Fixed width (240-260px), rectangular panels, text + small icon, hard borders
    Rectangle {
        id:             controlColumn
        width:          ScreenTools.defaultFontPixelWidth * 32  // Industrial standard - wider for readability
    anchors.left:   parent.left
    anchors.top:    parent.top
    anchors.bottom: parent.bottom
    color:          qgcPal.windowShade  // Battlefield Grey
    border.width:   2  // Stronger border
    border.color:   qgcPal.buttonBorder  // Tactical Steel

    // Right border highlight for depth
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Qt.darker(qgcPal.buttonBorder, 1.4)
    }

    // Top highlight line with tactical pattern
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1

        Rectangle {
            anchors.fill: parent
            color: Qt.lighter(qgcPal.windowShade, 1.15)
            opacity: 0.4
        }

        // Tactical pattern dots
        Repeater {
            model: Math.floor(parent.width / 8)
            Rectangle {
                x: index * 8 + 2
                y: -1
                width: 2
                height: 3
                color: qgcPal.buttonBorder
                opacity: 0.6
            }
        }
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

    function slotOf(index) {
        var veh = fleetVehicle(index)
        return (veh && veh.fleetSlot) ? veh.fleetSlot : (index + 1)
    }

    function batteryOf(veh) {
        return (veh && veh.batteries && veh.batteries.count > 0) ? veh.batteries.get(0) : null
    }

    function batteryNum(veh, name) {
        var b = batteryOf(veh)
        if (!b || !b[name])
            return 0
        var n = Number(b[name].rawValue)
        return isFinite(n) ? n : 0
    }

    function voltageOf(veh) {
        return batteryNum(veh, "voltage")
    }

    function currentOf(veh) {
        return batteryNum(veh, "current")
    }

    function percentOf(veh) {
        return batteryNum(veh, "percentRemaining")
    }

    function failsafeOf(veh) {
        if (!veh)
            return ""
        if (veh.armed && veh.flightMode !== "" &&
                (veh.flightMode === veh.rtlFlightMode || veh.flightMode === veh.smartRTLFlightMode || veh.flightMode === veh.landFlightMode))
            return veh.flightMode.toUpperCase()
        if (!veh.allSensorsHealthy)
            return "SENSOR"
        return ""
    }

    function voltageColor(v) {
        if (v <= 0) return qgcPal.colorGrey
        if (v < 10.5) return qgcPal.colorRed
        if (v < 11.0) return qgcPal.colorOrange
        return qgcPal.colorGreen
    }
            property real _moduleHeight: ScreenTools.defaultFontPixelHeight * 6.0  // Industrial standard - taller modules
            property real _labelWidth: ScreenTools.defaultFontPixelWidth * 12  // Industrial standard - wider labels
            property real _valueWidth: ScreenTools.defaultFontPixelWidth * 14  // Industrial standard - wider values

    clip: true

    Flickable {
        id:                 leftFlick
        anchors.fill:       parent
        anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.6
        clip:               true
        boundsBehavior:     Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        contentWidth:       width
        contentHeight:      leftCol.implicitHeight

        ColumnLayout {
            id:      leftCol
            width:   leftFlick.width
            spacing: ScreenTools.defaultFontPixelWidth * 0.6

        // SYSTEM Section Header
                QGCLabel {
                    text:           "SYSTEM"
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.1  // Industrial standard - larger
                    font.weight:    Font.Bold
                    font.letterSpacing: 2
                    font.family:    ScreenTools.fixedFontFamily
                    color:          qgcPal.text
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
                }

        // Vehicle Selector Module - Military Standard with Industrial Depth
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
                spacing:            ScreenTools.defaultFontPixelWidth * 0.4

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
                        text:           "VEHICLE SELECTOR"
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0  // Industrial standard - larger
                        font.weight:    Font.Bold
                        font.letterSpacing: 1.5
                        font.family:    ScreenTools.fixedFontFamily
                        color:          qgcPal.text
                        Layout.fillWidth: true
                    }
                }

                QGCComboBox {
                    id:                 vehicleCombo
                    Layout.fillWidth:   true
                    model:              []
                    currentIndex:       -1

                    Component.onCompleted: updateModel()

                    Connections {
                        target: QGroundControl.multiVehicleManager.vehicles
                        function onCountChanged() {
                            Qt.callLater(function() {
                                vehicleCombo.updateModel()
                            })
                        }
                    }

                    Connections {
                        target: QGroundControl.multiVehicleManager
                        function onActiveVehicleChanged() {
                            Qt.callLater(function() {
                                var activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
                                vehicleCombo.currentIndex = activeVehicle && activeVehicle.fleetSlot ? (activeVehicle.fleetSlot - 1) : -1
                            })
                        }
                    }

                    function updateModel() {
                        var list = []
                        var vehicles = QGroundControl.multiVehicleManager.vehicles
                        for (var i = 0; i < vehicles.count; i++) {
                            var vehicle = vehicles.get(i)
                            var port = ""
                            try {
                                var pn = vehicle.vehicleLinkManager ? String(vehicle.vehicleLinkManager.primaryLinkName || "") : ""
                                var m = pn.match(/ttyACM\d+|ttyUSB\d+|COM\d+/i)
                                if (m)
                                    port = "  " + m[0]
                            } catch (e) {}
                            list.push("Vehicle " + vehicle.fleetSlot + port + "  SYS " + vehicle.id)
                        }
                        vehicleCombo.model = list
                        var activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
                        vehicleCombo.currentIndex = activeVehicle && activeVehicle.fleetSlot ? (activeVehicle.fleetSlot - 1) : -1
                    }

                    onActivated: (index) => {
                        var vehicle = QGroundControl.multiVehicleManager.vehicles.get(index)
                        if (vehicle)
                            QGroundControl.multiVehicleManager.activeVehicle = vehicle
                    }
                }
            }
        }

        // HEALTH Section Header with tactical divider
        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.3

            // Tactical divider line with notches
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 3

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.6
                    height: 1
                    color: qgcPal.buttonBorder
                }

                // Left notches
                Repeater {
                    model: 2
                    Rectangle {
                        x: parent.width * 0.2 + index * 4
                        y: 0
                        width: 2
                        height: 3
                        color: qgcPal.buttonBorder
                    }
                }

                // Right notches
                Repeater {
                    model: 2
                    Rectangle {
                        x: parent.width * 0.8 - (index * 4) - 2
                        y: 0
                        width: 2
                        height: 3
                        color: qgcPal.buttonBorder
                    }
                }
            }

            QGCLabel {
                text:           "HEALTH"
                font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                font.weight:    Font.Bold
                font.letterSpacing: 2
                font.family:    ScreenTools.fixedFontFamily
                color:          qgcPal.text
            }
        }

        // System Health Module - Military Standard with Industrial Depth
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
                spacing:            ScreenTools.defaultFontPixelWidth * 0.4

                QGCLabel {
                    text:           "STATUS:"
                    font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                    font.weight:    Font.Bold
                    font.letterSpacing: 1.5
                    font.family:    ScreenTools.fixedFontFamily
                    color:          qgcPal.text
                }

                QGCLabel {
                    property bool commLost: (_activeVehicle && _activeVehicle.vehicleLinkManager) ? _activeVehicle.vehicleLinkManager.communicationLost : true
                    property bool healthy: _activeVehicle ? _activeVehicle.allSensorsHealthy : false
                    text: {
                        if (!_activeVehicle) return "STANDBY"
                        if (commLost) return "LINK LOST"
                        return healthy ? "OPERATIONAL" : "READY"
                    }
                    color: {
                        if (!_activeVehicle) return qgcPal.colorGrey
                        if (commLost) return qgcPal.colorRed
                        return healthy ? qgcPal.colorGreen : qgcPal.colorYellow
                    }
                    font.weight: Font.Bold
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                    font.family: ScreenTools.fixedFontFamily
                    Layout.fillWidth: true
                }

                QGCLabel {
                    text:           "ARM:"
                    font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                    font.weight:    Font.Bold
                    font.letterSpacing: 1.5
                    font.family:    ScreenTools.fixedFontFamily
                    color:          qgcPal.text
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.2
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    visible: !_fleetMode

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: _activeVehicle && _activeVehicle.armed ? qgcPal.colorRed : qgcPal.colorGreen
                        border.width: 1
                        border.color: Qt.darker(color, 1.2)
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }

                    QGCLabel {
                        property bool armed: _activeVehicle ? _activeVehicle.armed : false
                        text:       armed ? "ARMED" : "DISARMED"
                        color:      armed ? qgcPal.colorRed : qgcPal.colorGreen
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                        font.family: ScreenTools.fixedFontFamily
                        Layout.fillWidth: true
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 1.2
                    visible: _fleetMode
                    Repeater {
                        model: controlColumn._fleetCount
                        RowLayout {
                            property var veh: controlColumn.fleetVehicle(index)
                            spacing: ScreenTools.defaultFontPixelWidth * 0.3
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: veh && veh.armed ? "#C0392B" : "#2A8B55"
                                border.width: 1
                                border.color: Qt.darker(color, 1.2)
                            }
                            QGCLabel {
                                text: "V" + controlColumn.slotOf(index) + ":"
                                font.family: ScreenTools.fixedFontFamily
                                font.weight: Font.Bold
                                color: controlColumn.fleetColor(index)
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                            }
                            QGCLabel {
                                text: (veh && veh.armed) ? "ARM" : "DIS"
                                color: (veh && veh.armed) ? "#C0392B" : "#2A8B55"
                                font.weight: Font.Bold
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.95
                                font.family: ScreenTools.fixedFontFamily
                            }
                        }
                    }
                }
            }
        }

        // Battery Module - Industrial Standard Tabular Format with Depth
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: Math.max(_moduleHeight * 0.8, batteryContent.implicitHeight + batteryContent.anchors.margins * 2)
            color:              qgcPal.windowShadeDark
            border.width:       2
            border.color:       qgcPal.buttonBorder
            visible:            _fleetCount > 0

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
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1; height: 6; color: qgcPal.colorBlue }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 6; height: 1; color: qgcPal.colorBlue }

            ColumnLayout {
                id:                 batteryContent
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.top:        parent.top
                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.5
                spacing:            ScreenTools.defaultFontPixelWidth * 0.3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.3

                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: controlColumn.voltageColor(controlColumn.voltageOf(_activeVehicle))
                        border.width: 1
                        border.color: Qt.darker(color, 1.2)
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }

                    QGCLabel {
                        text:           "BATTERY" + (_fleetMode ? "  ·  " + _fleetCount + " DRONES" : "")
                        font.pointSize: ScreenTools.defaultFontPointSize
                        font.weight:    Font.Bold
                        font.letterSpacing: 1.5
                        font.family:    ScreenTools.fixedFontFamily
                        color:          qgcPal.buttonBorder
                        elide:          Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Single vehicle
                GridLayout {
                    visible:            !_fleetMode
                    Layout.fillWidth:   true
                    columns:            2
                    columnSpacing:      ScreenTools.defaultFontPixelWidth * 0.5
                    rowSpacing:         ScreenTools.defaultFontPixelWidth * 0.3

                    QGCLabel { text: "VOLT:"; font.weight: Font.DemiBold; font.family: ScreenTools.fixedFontFamily; color: qgcPal.text; opacity: 0.7; Layout.preferredWidth: _labelWidth }
                    QGCLabel {
                        property real voltage: controlColumn.voltageOf(_activeVehicle)
                        text:                   voltage.toFixed(2) + " V"
                        color:                  controlColumn.voltageColor(voltage)
                        font.family:            ScreenTools.fixedFontFamily
                        font.weight:            Font.Bold
                        horizontalAlignment:    Text.AlignRight
                        Layout.fillWidth:       true
                    }
                    QGCLabel { text: "CURRENT:"; font.weight: Font.DemiBold; font.family: ScreenTools.fixedFontFamily; color: qgcPal.text; opacity: 0.7; Layout.preferredWidth: _labelWidth }
                    QGCLabel {
                        property real current: controlColumn.currentOf(_activeVehicle)
                        text:                   current.toFixed(2) + " A"
                        color:                  current > 0 ? qgcPal.text : qgcPal.colorGrey
                        font.family:            ScreenTools.fixedFontFamily
                        font.weight:            Font.Bold
                        horizontalAlignment:    Text.AlignRight
                        Layout.fillWidth:       true
                    }
                    QGCLabel { text: "REMAIN:"; font.weight: Font.DemiBold; font.family: ScreenTools.fixedFontFamily; color: qgcPal.text; opacity: 0.7; Layout.preferredWidth: _labelWidth }
                    QGCLabel {
                        property real pct: controlColumn.percentOf(_activeVehicle)
                        text:                   pct > 0 ? pct.toFixed(0) + " %" : "--"
                        color:                  pct <= 0 ? qgcPal.colorGrey : (pct < 25 ? qgcPal.colorRed : (pct < 50 ? qgcPal.colorYellow : qgcPal.colorGreen))
                        font.family:            ScreenTools.fixedFontFamily
                        font.weight:            Font.Bold
                        horizontalAlignment:    Text.AlignRight
                        Layout.fillWidth:       true
                    }
                }

                // Fleet: one row per vehicle
                GridLayout {
                    visible:            _fleetMode
                    Layout.fillWidth:   true
                    columns:            4
                    columnSpacing:      ScreenTools.defaultFontPixelWidth * 0.5
                    rowSpacing:         ScreenTools.defaultFontPixelWidth * 0.2

                    Repeater {
                        model: ["", "VOLT", "AMP", "%"]
                        QGCLabel {
                            text:                   modelData
                            font.pointSize:         ScreenTools.defaultFontPointSize * 0.8
                            font.weight:            Font.DemiBold
                            font.family:            ScreenTools.fixedFontFamily
                            color:                  qgcPal.text
                            opacity:                0.75
                            horizontalAlignment:    Text.AlignRight
                            Layout.fillWidth:       index > 0
                            Layout.preferredWidth:  index === 0 ? ScreenTools.defaultFontPixelWidth * 3.5 : 1
                        }
                    }

                    Repeater {
                        model: _fleetMode ? controlColumn._fleetCount * 4 : 0
                        QGCLabel {
                            property int    _row:   Math.floor(index / 4)
                            property int    _col:   index % 4
                            property var    _veh:   controlColumn.fleetVehicle(_row)
                            property real   _v:     controlColumn.voltageOf(_veh)
                            property real   _a:     controlColumn.currentOf(_veh)
                            property real   _p:     controlColumn.percentOf(_veh)

                            text: _col === 0 ? "V" + controlColumn.slotOf(_row)
                                 : _col === 1 ? (_v > 0 ? _v.toFixed(1) : "--")
                                 : _col === 2 ? (_a > 0 ? _a.toFixed(1) : "--")
                                 : (_p > 0 ? _p.toFixed(0) : "--")
                            color: _col === 0 ? controlColumn.fleetColor(_row)
                                 : _col === 1 ? controlColumn.voltageColor(_v)
                                 : _col === 3 ? (_p <= 0 ? qgcPal.colorGrey : (_p < 25 ? qgcPal.colorRed : (_p < 50 ? qgcPal.colorYellow : qgcPal.colorGreen)))
                                 : (_a > 0 ? controlColumn.fleetColor(_row) : qgcPal.colorGrey)
                            font.family:            ScreenTools.fixedFontFamily
                            font.weight:            Font.Bold
                            font.pointSize:         ScreenTools.defaultFontPointSize * 0.95
                            horizontalAlignment:    _col === 0 ? Text.AlignLeft : Text.AlignRight
                            elide:                  Text.ElideLeft
                            Layout.fillWidth:       _col > 0
                            Layout.preferredWidth:  _col === 0 ? ScreenTools.defaultFontPixelWidth * 3.5 : 1
                        }
                    }
                }
            }
        }

        // Failsafe Module - Industrial Standard with Depth
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: _moduleHeight * 0.7
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

            visible:            _fleetCount > 0

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
                        color: controlColumn.failsafeOf(_activeVehicle) !== "" ? qgcPal.colorRed : qgcPal.colorGreen
                        border.width: 1
                        border.color: Qt.darker(color, 1.2)
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }

                    QGCLabel {
                        text:           "FAILSAFE"
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
                        property string failsafe: controlColumn.failsafeOf(_activeVehicle)
                        text:       failsafe !== "" ? failsafe : "NORMAL"
                        color:      failsafe !== "" ? qgcPal.colorRed : qgcPal.colorGreen
                        elide:      Text.ElideRight
                        font.weight: Font.Bold
                        font.family: ScreenTools.fixedFontFamily
                        Layout.preferredWidth: _valueWidth
                        visible: !_fleetMode
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth * 1.0
                        visible: _fleetMode
                        Repeater {
                            model: controlColumn._fleetCount
                            QGCLabel {
                                property var veh: controlColumn.fleetVehicle(index)
                                property string failsafe: controlColumn.failsafeOf(veh)
                                text: "V" + controlColumn.slotOf(index) + ": " + (failsafe !== "" ? failsafe : "OK")
                                color: failsafe !== "" ? "#C0392B" : "#2A8B55"
                                font.family: ScreenTools.fixedFontFamily
                                font.weight: Font.Bold
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                            }
                        }
                    }
                }
            }
        }


        // ACTIONS Section Header
        QGCLabel {
            text:           "ACTIONS"
            font.pointSize: ScreenTools.defaultFontPointSize * 0.9
            font.weight:    Font.Bold
            font.letterSpacing: 2
            font.family:    ScreenTools.fixedFontFamily
            color:          qgcPal.text
            Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.3
        }

        // Action Buttons - Military Standard with Industrial Depth
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 8
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
                spacing:            ScreenTools.defaultFontPixelWidth * 0.4

                QGCButton {
                    Layout.fillWidth: true
                    text:           "CONNECT"
                    font.family:    ScreenTools.fixedFontFamily
                    font.weight:    Font.Bold
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                    onClicked:      mainWindow.showSwarmCoverage()
                }

                QGCDelayButton {
                    Layout.fillWidth: true
                    enabled:            _activeVehicle && !_activeVehicle.armed
                    text:               "ARM"
                    font.family:        ScreenTools.fixedFontFamily
                    font.weight:        Font.Bold
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                    onActivated:        {
                        if (_activeVehicle) {
                            _activeVehicle.armed = true
                        }
                    }
                }

                QGCDelayButton {
                    Layout.fillWidth: true
                    enabled:            _activeVehicle && _activeVehicle.armed
                    text:               "DISARM"
                    font.family:        ScreenTools.fixedFontFamily
                    font.weight:        Font.Bold
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                    onActivated:        {
                        if (_activeVehicle) {
                            _activeVehicle.armed = false
                        }
                    }
                }

                QGCDelayButton {
                    Layout.fillWidth: true
                    enabled:            _activeVehicle && _activeVehicle.armed
                    text:               "RTL"
                    font.family:        ScreenTools.fixedFontFamily
                    font.weight:        Font.Bold
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                    onActivated:        {
                        if (_activeVehicle && globals && globals.guidedControllerFlyView) {
                            globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionRTL)
                        }
                    }
                }
            }
        }

        // Swarm Backend Toggle
        QGCButton {
            Layout.fillWidth: true
            Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
            text:           "SWARM"
            font.family:    ScreenTools.fixedFontFamily
            font.weight:    Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.0
            primary:        true
            onClicked:      mainWindow.showSwarmCoverage()
        }

        }
    }

    property var globals: null
}

