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

    property real _moduleHeight: ScreenTools.defaultFontPixelHeight * 6.5
    property real _labelWidth: ScreenTools.defaultFontPixelWidth * 12

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

    function signed(v, decimals) {
        return (v >= 0 ? "+" : "") + v.toFixed(decimals)
    }

    function fieldValue(veh, key) {
        switch (key) {
        case "roll":    return vehNum(veh, "roll", 0)
        case "pitch":   return vehNum(veh, "pitch", 0)
        case "yaw":     return vehNum(veh, "heading", 0)
        case "alt":     return vehNum(veh, "altitudeRelative", 0)
        case "spd":     return vehNum(veh, "groundSpeed", 0)
        case "vspd":    return vehNum(veh, "climbRate", 0)
        case "hdop":    return (veh && veh.gps) ? factNum(veh.gps.hdop, 0) : 0
        case "vdop":    return (veh && veh.gps) ? factNum(veh.gps.vdop, 0) : 0
        case "sats":    return (veh && veh.gps) ? factNum(veh.gps.count, 0) : 0
        }
        return 0
    }

    // Fleet rows (compact) drop decimals and units so every drone fits in the column width.
    function fieldText(veh, key, compact) {
        if (!veh)
            return "--"
        var v = fieldValue(veh, key)
        switch (key) {
        case "roll":
        case "pitch":   return compact ? signed(v, 1) : signed(v, 2) + "°"
        case "yaw":     return compact ? v.toFixed(0) : v.toFixed(2) + "°"
        case "alt":     return compact ? v.toFixed(1) : v.toFixed(2) + " m"
        case "spd":     return compact ? v.toFixed(1) : v.toFixed(2) + " m/s"
        case "vspd":    return compact ? signed(v, 1) : signed(v, 2) + " m/s"
        case "hdop":
        case "vdop":    return v <= 0 ? "--" : (compact ? v.toFixed(1) : v.toFixed(2))
        case "sats":    return v.toFixed(0)
        }
        return "--"
    }

    function fieldColor(veh, key, base) {
        if (key === "hdop" || key === "vdop") {
            var d = fieldValue(veh, key)
            var good = key === "hdop" ? 1.0 : 1.5
            var ok = key === "hdop" ? 2.0 : 2.5
            if (d <= 0)
                return qgcPal.colorGrey
            return d < good ? qgcPal.colorGreen : (d < ok ? qgcPal.colorYellow : qgcPal.colorOrange)
        }
        return base
    }

    /// Single vehicle: "LABEL: value" rows. Fleet: column header, then one row per vehicle.
    component TelemetryModule: Rectangle {
        id: module
        property string title
        property var    columns: []     // [{ key, label, unit }]
        property Item   tc

        QGCPalette { id: qgcPal }

        Layout.fillWidth:       true
        Layout.preferredHeight: Math.max(tc._moduleHeight * 0.75, content.implicitHeight + content.anchors.margins * 2)
        color:                  qgcPal.windowShadeDark
        border.width:           2
        border.color:           qgcPal.buttonBorder

        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 2; width: 1; height: 6; color: qgcPal.colorBlue }
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 2; width: 6; height: 1; color: qgcPal.colorBlue }
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 2; width: 1; height: 6; color: qgcPal.colorBlue }
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 2; width: 6; height: 1; color: qgcPal.colorBlue }

        Rectangle {
            anchors.fill:       parent
            anchors.margins:    1
            color:              "transparent"
            border.width:       1
            border.color:       Qt.darker(qgcPal.windowShadeDark, 1.2)
        }

        ColumnLayout {
            id:                 content
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.6
            spacing:            ScreenTools.defaultFontPixelWidth * 0.3

            QGCLabel {
                text:               module.title + (tc._fleetMode ? "  ·  " + tc._fleetCount + " DRONES" : "")
                font.pointSize:     ScreenTools.defaultFontPointSize * 0.9
                font.weight:        Font.Bold
                font.letterSpacing: 1.5
                font.family:        ScreenTools.fixedFontFamily
                color:              qgcPal.text
                elide:              Text.ElideRight
                Layout.fillWidth:   true
            }

            Repeater {
                model: tc._fleetMode ? [] : module.columns
                RowLayout {
                    Layout.fillWidth:   true
                    spacing:            ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:                   modelData.label + ":"
                        font.weight:            Font.DemiBold
                        font.family:            ScreenTools.fixedFontFamily
                        color:                  qgcPal.text
                        Layout.preferredWidth:  tc._labelWidth * 0.8
                    }
                    QGCLabel {
                        text:                   tc.fieldText(tc._activeVehicle, modelData.key, false)
                        color:                  tc.fieldColor(tc._activeVehicle, modelData.key, qgcPal.text)
                        font.family:            ScreenTools.fixedFontFamily
                        font.weight:            Font.Bold
                        font.pointSize:         ScreenTools.defaultFontPointSize * 1.1
                        horizontalAlignment:    Text.AlignRight
                        elide:                  Text.ElideLeft
                        Layout.fillWidth:       true
                    }
                }
            }

            GridLayout {
                visible:            tc._fleetMode
                Layout.fillWidth:   true
                columns:            module.columns.length + 1
                columnSpacing:      ScreenTools.defaultFontPixelWidth * 0.5
                rowSpacing:         ScreenTools.defaultFontPixelWidth * 0.2

                QGCLabel {
                    text:                   ""
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 3.5
                }
                Repeater {
                    model: tc._fleetMode ? module.columns : []
                    QGCLabel {
                        text:                   modelData.label + (modelData.unit ? " " + modelData.unit : "")
                        font.pointSize:         ScreenTools.defaultFontPointSize * 0.8
                        font.weight:            Font.DemiBold
                        font.family:            ScreenTools.fixedFontFamily
                        color:                  qgcPal.text
                        opacity:                0.75
                        horizontalAlignment:    Text.AlignRight
                        elide:                  Text.ElideRight
                        Layout.fillWidth:       true
                        Layout.preferredWidth:  1
                    }
                }

                Repeater {
                    model: tc._fleetMode ? tc._fleetCount * (module.columns.length + 1) : 0
                    QGCLabel {
                        property int    _cols:      module.columns.length + 1
                        property int    _row:       Math.floor(index / _cols)
                        property int    _col:       index % _cols
                        property var    _veh:       tc.fleetVehicle(_row)
                        property var    _colDef:    _col > 0 ? module.columns[_col - 1] : null
                        property color  _vColor:    tc.fleetColor(_row)

                        text:                   _col === 0 ? "V" + tc.slotOf(_row)
                                                           : tc.fieldText(_veh, _colDef.key, true)
                        color:                  _col === 0 ? _vColor : tc.fieldColor(_veh, _colDef.key, _vColor)
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
            id:         rightCol
            width:      rightFlick.width
            spacing:    ScreenTools.defaultFontPixelWidth * 0.6

            TelemetryModule {
                tc:      telemetryColumn
                title:   "ATTITUDE"
                columns: [ { key: "roll", label: "ROLL" }, { key: "pitch", label: "PITCH" }, { key: "yaw", label: "YAW" } ]
            }

            TelemetryModule {
                tc:      telemetryColumn
                title:   "ALT / SPEED"
                columns: [ { key: "alt", label: "ALT", unit: "m" }, { key: "spd", label: "SPD" }, { key: "vspd", label: "VSPD" } ]
            }

            TelemetryModule {
                tc:      telemetryColumn
                title:   "GPS"
                columns: [ { key: "hdop", label: "HDOP" }, { key: "vdop", label: "VDOP" }, { key: "sats", label: "SATS" } ]
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: _moduleHeight * 0.7
                color:                  qgcPal.windowShadeDark
                border.width:           2
                border.color:           qgcPal.buttonBorder

                Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 2; width: 1; height: 6; color: qgcPal.colorBlue }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 2; width: 6; height: 1; color: qgcPal.colorBlue }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 2; width: 1; height: 6; color: qgcPal.colorBlue }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 2; width: 6; height: 1; color: qgcPal.colorBlue }

                ColumnLayout {
                    anchors.fill:       parent
                    anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.5
                    spacing:            ScreenTools.defaultFontPixelWidth * 0.5

                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelWidth * 0.3

                        Rectangle {
                            width:              5
                            height:             5
                            radius:             2.5
                            color:              qgcPal.colorGrey
                            border.width:       1
                            border.color:       Qt.darker(color, 1.2)
                            Layout.alignment:   Qt.AlignLeft | Qt.AlignVCenter
                        }

                        QGCLabel {
                            text:               "PAYLOAD STATUS"
                            font.weight:        Font.Bold
                            font.letterSpacing: 1.5
                            font.family:        ScreenTools.fixedFontFamily
                            color:              qgcPal.buttonBorder
                            Layout.fillWidth:   true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            0
                        QGCLabel {
                            text:                   "STATUS:"
                            font.weight:            Font.DemiBold
                            font.family:            ScreenTools.fixedFontFamily
                            color:                  qgcPal.text
                            opacity:                0.7
                            Layout.preferredWidth:  _labelWidth
                        }
                        QGCLabel {
                            text:               "NO DATA"
                            color:              qgcPal.colorGrey
                            font.weight:        Font.Bold
                            font.family:        ScreenTools.fixedFontFamily
                            opacity:            0.7
                            Layout.fillWidth:   true
                        }
                    }
                }
            }
        }
    }
}
