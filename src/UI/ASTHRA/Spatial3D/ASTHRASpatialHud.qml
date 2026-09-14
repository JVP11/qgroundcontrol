/****************************************************************************
 *
 * ASTHRA Spatial 3D — compact honesty HUD. Does not duplicate telemetry column.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: hud

    property var vehicle: null
    property string originLabel: "ORIGIN UNSET"
    property real rangeM: NaN
    property real altM: NaN
    property string altSource: "—"
    property real headingDeg: NaN
    property bool headingEstimated: false
    property bool fovEstimated: true
    property bool stale: false
    property bool operatorValid: false
    property string lookLabel: "—"
    property string rangeLegend: "25/50/100"
    property bool expanded: false

    implicitHeight: contentCol.implicitHeight + 16
    clip: true

    QGCPalette { id: qgcPal }

    readonly property bool _haveV: vehicle !== null && vehicle !== undefined
    readonly property int _gpsLock: _haveV && vehicle.gps ? vehicle.gps.lock.rawValue : 0
    readonly property string _gpsText: {
        if (!_haveV)
            return "NO VEHICLE"
        if (vehicle.gps && vehicle.gps.lock.enumStringValue)
            return String(vehicle.gps.lock.enumStringValue).toUpperCase()
        return "GPS —"
    }
    readonly property string _sats: _haveV && vehicle.gps ? Number(vehicle.gps.count.value).toFixed(0) : "—"
    readonly property string _hdop: _haveV && vehicle.gps ? Number(vehicle.gps.hdop.value).toFixed(1) : "—"
    readonly property bool _commLost: _haveV && vehicle.vehicleLinkManager ? vehicle.vehicleLinkManager.communicationLost : true
    readonly property string _link: {
        if (!_haveV)
            return "NO LINK"
        if (_commLost || stale)
            return "STALE"
        var loss = vehicle.mavlinkLossPercent
        if (loss !== undefined && loss !== null)
            return "LINK " + Number(loss).toFixed(0) + "%"
        return "LINK OK"
    }

    function _fmt(n, digits, suffix) {
        if (n === undefined || n === null || isNaN(n))
            return "—"
        return Number(n).toFixed(digits) + suffix
    }

    function _valColor(warn, critical) {
        if (critical)
            return qgcPal.colorRed
        if (warn)
            return qgcPal.colorYellow
        return qgcPal.text
    }

    Rectangle {
        anchors.fill: parent
        color: qgcPal.windowShadeDark
        border.width: 2
        border.color: qgcPal.buttonBorder

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.lighter(qgcPal.windowShadeDark, 1.15)
            opacity: 0.4
        }
    }

    Item {
        anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 2
        width: 8; height: 8
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1.5; height: 8; color: qgcPal.colorBlue }
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 8; height: 1.5; color: qgcPal.colorBlue }
    }
    Item {
        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 2
        width: 8; height: 8
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1.5; height: 8; color: qgcPal.colorBlue }
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 8; height: 1.5; color: qgcPal.colorBlue }
    }
    Item {
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 2
        width: 8; height: 8
        Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 1.5; height: 8; color: qgcPal.colorBlue }
        Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 8; height: 1.5; color: qgcPal.colorBlue }
    }
    Item {
        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 2
        width: 8; height: 8
        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 1.5; height: 8; color: qgcPal.colorBlue }
        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 8; height: 1.5; color: qgcPal.colorBlue }
    }

    ColumnLayout {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            QGCLabel {
                text: "STATUS"
                font.family: ScreenTools.fixedFontFamily
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.text
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 7; height: 7
                color: (stale || _commLost) ? qgcPal.colorRed : (_haveV ? qgcPal.colorGreen : qgcPal.colorGrey)
                border.width: 1
                border.color: Qt.darker(color, 1.4)
            }
            QGCLabel {
                text: hud.expanded ? "LESS" : "MORE"
                font.family: ScreenTools.fixedFontFamily
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.colorBlue
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: hud.expanded = !hud.expanded
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.buttonBorder }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "ORIGIN"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel { Layout.fillWidth: true; text: hud.originLabel; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: hud._valColor(!hud.operatorValid, hud.originLabel === "Not set"); elide: Text.ElideRight }
        }
        RowLayout {
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "RANGE"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel { Layout.fillWidth: true; text: hud._fmt(hud.rangeM, 0, " m"); font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: hud._valColor(hud.stale, false) }
        }
        RowLayout {
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "ALT"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel { Layout.fillWidth: true; text: hud._fmt(hud.altM, 1, " m") + "  " + hud.altSource; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: hud._valColor(hud.stale || hud.altSource === "AMSL", false) }
        }
        RowLayout {
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "GPS"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel { Layout.fillWidth: true; text: _gpsText; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: hud._valColor(_gpsLock < 3, !_haveV) }
        }
        RowLayout {
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "LOOK"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel { Layout.fillWidth: true; text: hud.lookLabel + (hud.fovEstimated ? "  EST" : ""); font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: hud._valColor(hud.fovEstimated, false) }
        }
        RowLayout {
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "GCS"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel { Layout.fillWidth: true; text: hud.operatorValid ? "POS OK" : "GCS POS UNAVAILABLE"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: hud._valColor(!hud.operatorValid, !hud.operatorValid) }
        }
        RowLayout {
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "LINK"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel {
                Layout.fillWidth: true
                text: _link
                font.family: ScreenTools.fixedFontFamily
                font.bold: stale || _commLost
                font.pointSize: ScreenTools.smallFontPointSize
                color: (stale || _commLost || !_haveV) ? qgcPal.colorRed : qgcPal.colorGreen
            }
        }

        RowLayout {
            visible: hud.expanded
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "HEADING"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel { Layout.fillWidth: true; text: hud._fmt(hud.headingDeg, 0, "°") + (hud.headingEstimated ? "  estimated" : ""); font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: hud._valColor(hud.headingEstimated, false) }
        }
        RowLayout {
            visible: hud.expanded
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "FOV"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel {
                Layout.fillWidth: true
                text: hud.fovEstimated ? "Heading (estimated)" : "Gimbal"
                font.family: ScreenTools.fixedFontFamily
                font.pointSize: ScreenTools.smallFontPointSize
                color: hud._valColor(hud.fovEstimated, false)
            }
        }
        RowLayout {
            visible: hud.expanded
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "SATS"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel { Layout.fillWidth: true; text: _sats + "   HDOP " + _hdop; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: hud._valColor(_gpsLock < 3, false) }
        }

        Rectangle { visible: hud.expanded; Layout.fillWidth: true; height: 1; color: qgcPal.buttonBorder }

        RowLayout {
            visible: hud.expanded
            Layout.fillWidth: true
            QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8; text: "KEY"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199" }
            QGCLabel { Layout.fillWidth: true; text: "N steel  ·  E amber  ·  rings " + hud.rangeLegend + " m"; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize; color: "#8B9199"; elide: Text.ElideRight; wrapMode: Text.WordWrap }
        }
    }
}
