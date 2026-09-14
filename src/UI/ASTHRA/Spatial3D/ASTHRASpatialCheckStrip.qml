/****************************************************************************
 *
 * ASTHRA Spatial 3D — industrial PASS / WARN / FAIL check strip.
 * Honesty only. Does not arm, command, or duplicate the telemetry column.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: strip

    property var vehicle: null
    property bool operatorValid: false
    property string originLabel: "Not set"
    property string originKind: ""
    property bool stale: false
    property bool headingEstimated: false
    property bool fovEstimated: true
    property bool gpsWeak: false
    property string altSource: "—"
    property string lookLabel: "—"
    property int gpsLock: 0
    property real hdop: NaN
    property real linkLoss: NaN
    property bool commLost: true
    property bool expanded: true

    readonly property bool _haveV: vehicle !== null && vehicle !== undefined

    readonly property string vehS: _haveV ? "PASS" : "FAIL"
    readonly property string vehD: _haveV ? "linked" : "none"

    readonly property string gpsS: !_haveV ? "FAIL" : (gpsLock < 2 ? "FAIL" : ((gpsLock < 3 || gpsWeak || (!isNaN(hdop) && hdop > 2.5)) ? "WARN" : "PASS"))
    readonly property string gpsD: {
        if (!_haveV)
            return "no vehicle"
        if (gpsLock < 2)
            return "no fix"
        if (gpsLock < 3)
            return "2D"
        if (!isNaN(hdop) && hdop > 2.5)
            return "HDOP " + Number(hdop).toFixed(1)
        if (gpsLock >= 6)
            return "RTK"
        if (gpsLock >= 5)
            return "RTK float"
        if (gpsLock >= 4)
            return "DGPS"
        return "3D"
    }

    readonly property string linkS: !_haveV ? "FAIL" : ((commLost || stale) ? "FAIL" : ((!isNaN(linkLoss) && linkLoss > 15) ? "WARN" : "PASS"))
    readonly property string linkD: !_haveV ? "no link" : ((commLost || stale) ? "STALE" : ((!isNaN(linkLoss) && linkLoss > 15) ? (Number(linkLoss).toFixed(0) + "% loss") : "ok"))

    readonly property string origS: (originKind === "gcs" || originKind === "home") ? "PASS" : (originKind === "vehicle" ? "WARN" : "FAIL")
    readonly property string origD: originKind === "gcs" || originKind === "home" ? originLabel : (originKind === "vehicle" ? "frozen on vehicle" : "not set")

    readonly property string gcsS: operatorValid ? "PASS" : "FAIL"
    readonly property string gcsD: operatorValid ? "this computer" : "GCS POS UNAVAILABLE"

    readonly property string hdgS: !_haveV ? "FAIL" : (headingEstimated ? "WARN" : "PASS")
    readonly property string hdgD: !_haveV ? "—" : (headingEstimated ? "HDG EST (COG)" : "mag")

    readonly property string fovS: !_haveV ? "FAIL" : (fovEstimated ? "WARN" : "PASS")
    readonly property string fovD: !_haveV ? "—" : (fovEstimated ? "ESTIMATED" : lookLabel)

    readonly property string altS: !_haveV ? "FAIL" : ((altSource === "RNG" || altSource === "REL") ? "PASS" : "WARN")
    readonly property string altD: !_haveV ? "—" : (altSource === "RNG" ? "rangefinder" : (altSource === "REL" ? "relative" : (altSource === "AMSL" ? "AMSL only" : altSource)))

    readonly property string poseS: !_haveV ? "FAIL" : (stale ? "FAIL" : (gpsWeak ? "WARN" : "PASS"))
    readonly property string poseD: !_haveV ? "—" : (stale ? "frozen" : (gpsWeak ? "weak GPS" : "live"))

    readonly property string mapS: "PASS"
    readonly property string mapD: "look-only"

    readonly property int failCount: (vehS === "FAIL" ? 1 : 0) + (gpsS === "FAIL" ? 1 : 0) + (linkS === "FAIL" ? 1 : 0) + (origS === "FAIL" ? 1 : 0) + (gcsS === "FAIL" ? 1 : 0) + (hdgS === "FAIL" ? 1 : 0) + (fovS === "FAIL" ? 1 : 0) + (altS === "FAIL" ? 1 : 0) + (poseS === "FAIL" ? 1 : 0)
    readonly property int warnCount: (vehS === "WARN" ? 1 : 0) + (gpsS === "WARN" ? 1 : 0) + (linkS === "WARN" ? 1 : 0) + (origS === "WARN" ? 1 : 0) + (gcsS === "WARN" ? 1 : 0) + (hdgS === "WARN" ? 1 : 0) + (fovS === "WARN" ? 1 : 0) + (altS === "WARN" ? 1 : 0) + (poseS === "WARN" ? 1 : 0)
    readonly property int passCount: 10 - failCount - warnCount
    readonly property string summary: failCount > 0 ? "CHECK FAIL" : (warnCount > 0 ? "CHECK WARN" : "CHECK PASS")
    readonly property color summaryColor: failCount > 0 ? qgcPal.colorRed : (warnCount > 0 ? qgcPal.colorYellow : qgcPal.colorGreen)

    implicitHeight: body.implicitHeight + 12
    color: qgcPal.windowShadeDark
    border.width: 2
    border.color: qgcPal.buttonBorder
    clip: true

    QGCPalette { id: qgcPal }

    function _color(s) {
        if (s === "FAIL")
            return qgcPal.colorRed
        if (s === "WARN")
            return qgcPal.colorYellow
        return qgcPal.colorGreen
    }

    component CheckRow: RowLayout {
        property string key: ""
        property string stateText: "FAIL"
        property string detail: ""
        Layout.fillWidth: true
        spacing: 4
        Rectangle {
            width: 7; height: 7
            color: strip._color(stateText)
            border.width: 1
            border.color: Qt.darker(color, 1.4)
        }
        QGCLabel {
            text: key
            font.family: ScreenTools.fixedFontFamily
            font.pointSize: ScreenTools.smallFontPointSize
            color: "#8B9199"
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5
        }
        QGCLabel {
            text: stateText
            font.family: ScreenTools.fixedFontFamily
            font.bold: true
            font.pointSize: ScreenTools.smallFontPointSize
            color: strip._color(stateText)
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5
        }
        QGCLabel {
            Layout.fillWidth: true
            text: detail
            font.family: ScreenTools.fixedFontFamily
            font.pointSize: ScreenTools.smallFontPointSize
            color: qgcPal.text
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            QGCLabel {
                text: "INDUSTRIAL CHECK"
                font.family: ScreenTools.fixedFontFamily
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.text
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 7; height: 7
                color: strip.summaryColor
                border.width: 1
                border.color: Qt.darker(color, 1.4)
            }
            QGCLabel {
                text: strip.summary
                font.family: ScreenTools.fixedFontFamily
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
                color: strip.summaryColor
            }
            QGCLabel {
                text: strip.expanded ? "LESS" : "MORE"
                font.family: ScreenTools.fixedFontFamily
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.colorBlue
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: strip.expanded = !strip.expanded
                }
            }
        }

        QGCLabel {
            visible: strip.expanded
            Layout.fillWidth: true
            text: passCount + " pass  ·  " + warnCount + " warn  ·  " + failCount + " fail"
            font.family: ScreenTools.fixedFontFamily
            font.pointSize: ScreenTools.smallFontPointSize
            color: "#8B9199"
        }

        Rectangle { visible: strip.expanded; Layout.fillWidth: true; height: 1; color: qgcPal.buttonBorder }

        GridLayout {
            visible: strip.expanded
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 3

            CheckRow { key: "VEH";  stateText: strip.vehS;  detail: strip.vehD }
            CheckRow { key: "GPS";  stateText: strip.gpsS;  detail: strip.gpsD }
            CheckRow { key: "LINK"; stateText: strip.linkS; detail: strip.linkD }
            CheckRow { key: "ORIG"; stateText: strip.origS; detail: strip.origD }
            CheckRow { key: "GCS";  stateText: strip.gcsS;  detail: strip.gcsD }
            CheckRow { key: "HDG";  stateText: strip.hdgS;  detail: strip.hdgD }
            CheckRow { key: "FOV";  stateText: strip.fovS;  detail: strip.fovD }
            CheckRow { key: "ALT";  stateText: strip.altS;  detail: strip.altD }
            CheckRow { key: "POSE"; stateText: strip.poseS; detail: strip.poseD }
            CheckRow { key: "MAP";  stateText: strip.mapS;  detail: strip.mapD }
        }

        QGCLabel {
            Layout.fillWidth: true
            visible: strip.expanded && !_haveV
            text: "Connect a vehicle (CONNECT / SWARM). This pane never arms."
            font.family: ScreenTools.fixedFontFamily
            font.pointSize: ScreenTools.smallFontPointSize
            color: "#8B9199"
            wrapMode: Text.WordWrap
        }
    }
}
