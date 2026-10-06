/****************************************************************************
 *
 * ASTHRA - Boot Screen
 * Start-up overlay with live system checks
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:     bootScreen
    color:  "#DADADA"
    focus:  true

    /// Set by the host so the map check reflects the real map engine state.
    property bool   mapReady:           false
    property bool   swarmConnected:     false
    property real   minimumDuration:    6000
    property real   maximumDuration:    9000

    signal finished()

    property real   _elapsed:       0
    property bool   _started:       false
    property real   _startTime:     0
    property real   _progress:      0
    property int    _shownChecks:   0
    property bool   _closing:       false

    readonly property color _accent:    "#E03A3A"
    readonly property color _ok:        "#1E8449"
    readonly property color _warn:      "#B9770E"
    readonly property color _dim:       "#7A7A7A"
    readonly property color _text:      "#222222"
    readonly property color _subText:   "#555555"

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    function _usbCount() {
        var lm = QGroundControl.linkManager
        if (lm && typeof lm.usbPrimarySerialPorts === "function")
            return lm.usbPrimarySerialPorts().length
        return 0
    }

    function _vehicleCount() {
        var v = QGroundControl.multiVehicleManager.vehicles
        return v ? v.count : 0
    }

    // state: 0 = pending, 1 = ok, 2 = warning (non-blocking)
    property var _checks: [
        { label: "CORE SYSTEMS",        value: function() { return String(QGroundControl.qgcVersion).split(" ")[0].split("-")[0].toUpperCase() },                         state: function() { return 1 } },
        { label: "MAP ENGINE",          value: function() { return bootScreen.mapReady ? "READY" : "LOADING" },                    state: function() { return bootScreen.mapReady ? 1 : 0 } },
        { label: "USB FLIGHT CTRL",     value: function() { var n = bootScreen._usbCount(); return n > 0 ? n + " DETECTED" : "NONE · UDP 14550 LISTENING" },
                                        state: function() { return bootScreen._usbCount() > 0 ? 1 : 2 } },
        { label: "SWARM BACKEND",       value: function() { return bootScreen.swarmConnected ? "ONLINE" : "OFFLINE (OPTIONAL)" },  state: function() { return bootScreen.swarmConnected ? 1 : 2 } },
        { label: "FLEET",               value: function() { var n = bootScreen._vehicleCount(); return n > 0 ? n + " VEHICLE" + (n > 1 ? "S" : "") : "AWAITING HEARTBEAT" },
                                        state: function() { return bootScreen._vehicleCount() > 0 ? 1 : 2 } },
        { label: "SAFETY INTERLOCK",    value: function() { return "AUTO-ARM DISABLED" },                                          state: function() { return 1 } }
    ]

    function close() {
        if (_closing)
            return
        _closing = true
        tick.stop()
        fadeOut.start()
    }

    Keys.onPressed: (event) => { close(); event.accepted = true }

    MouseArea {
        anchors.fill:   parent
        onClicked:      bootScreen.close()
    }

    // QML finishes loading well before the window is first shown, so time from the first displayed frame.
    Connections {
        target:     bootScreen.Window.window
        enabled:    !bootScreen._started
        function onFrameSwapped() {
            bootScreen._startTime = Date.now()
            bootScreen._started = true
        }
    }

    Timer {
        id:         tick
        interval:   50
        repeat:     true
        running:    bootScreen._started
        onTriggered: {
            bootScreen._elapsed = Date.now() - bootScreen._startTime
            var target = Math.min(1, bootScreen._elapsed / bootScreen.minimumDuration)
            if (!bootScreen.mapReady && bootScreen._elapsed < bootScreen.maximumDuration)
                target = Math.min(target, 0.9)
            bootScreen._progress = target
            bootScreen._shownChecks = Math.min(bootScreen._checks.length, Math.max(0, Math.floor((bootScreen._elapsed - 1200) / 700)))
            if (bootScreen._progress >= 1 && bootScreen._shownChecks >= bootScreen._checks.length)
                bootScreen.close()
        }
    }

    NumberAnimation {
        id:         fadeOut
        target:     bootScreen
        property:   "opacity"
        to:         0
        duration:   450
        easing.type: Easing.InOutQuad
        onFinished: bootScreen.finished()
    }

    // Light backdrop matching the logo artwork
    Canvas {
        anchors.fill:   parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var cy = height * 0.4
            var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(width, height) * 0.7)
            g.addColorStop(0, "#ECECEC")
            g.addColorStop(1, "#CFCFCF")
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
        }
        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()
    }

    // Radar behind the logo
    Item {
        id:                 radar
        width:              Math.min(parent.width, parent.height) * 0.62
        height:             width
        anchors.centerIn:   parent
        anchors.verticalCenterOffset: -parent.height * 0.11
        opacity:            0

        NumberAnimation on opacity { running: bootScreen._started; to: 1; duration: 900; easing.type: Easing.OutQuad }

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var c = width / 2
                ctx.strokeStyle = "#C3C3C3"
                ctx.lineWidth = 1
                for (var r = 1; r <= 4; r++) {
                    ctx.beginPath()
                    ctx.arc(c, c, c * r / 4 - 1, 0, Math.PI * 2)
                    ctx.stroke()
                }
                ctx.strokeStyle = "#B4B4B4"
                for (var d = 0; d < 360; d += 10) {
                    var a = d * Math.PI / 180
                    var inner = d % 30 === 0 ? c - 12 : c - 6
                    ctx.beginPath()
                    ctx.moveTo(c + Math.cos(a) * inner, c + Math.sin(a) * inner)
                    ctx.lineTo(c + Math.cos(a) * (c - 1), c + Math.sin(a) * (c - 1))
                    ctx.stroke()
                }
            }
        }

        Canvas {
            anchors.fill:   parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var c = width / 2
                var g = ctx.createConicalGradient(c, c, 0)
                g.addColorStop(0.0, "rgba(224,58,58,0.30)")
                g.addColorStop(0.14, "rgba(224,58,58,0.0)")
                g.addColorStop(1.0, "rgba(224,58,58,0.0)")
                ctx.fillStyle = g
                ctx.beginPath()
                ctx.moveTo(c, c)
                ctx.arc(c, c, c - 1, 0, Math.PI * 2)
                ctx.fill()
            }
            RotationAnimator on rotation {
                from:       360
                to:         0
                duration:   3000
                loops:      Animation.Infinite
                running:    bootScreen.visible
            }
        }
    }

    Image {
        id:                 logo
        anchors.centerIn:   radar
        source:             "qrc:/asthra/logo"
        height:             radar.height * 0.68
        width:              Math.min(radar.width, height * implicitWidth / Math.max(1, implicitHeight))
        sourceSize.height:  800
        fillMode:           Image.PreserveAspectFit
        smooth:             true
        mipmap:             true
        opacity:            0
        scale:              0.85

        ParallelAnimation {
            running: logo.status === Image.Ready && bootScreen._started
            NumberAnimation { target: logo; property: "opacity"; to: 1; duration: 1100; easing.type: Easing.OutQuad }
            NumberAnimation { target: logo; property: "scale"; to: 1; duration: 1400; easing.type: Easing.OutBack }
        }
    }

    // Institution logo; the source artwork is small, so keep it near native size
    Image {
        id:                 institutionLogo
        anchors.left:       parent.left
        anchors.top:        parent.top
        anchors.margins:    ScreenTools.defaultFontPixelWidth * 2
        source:             "qrc:/asthra/institution"
        width:              Math.min(96, Math.max(64, Math.min(bootScreen.width, bootScreen.height) * 0.08))
        height:             width
        fillMode:           Image.PreserveAspectFit
        smooth:             true
        mipmap:             true
        opacity:            0

        NumberAnimation on opacity { running: institutionLogo.status === Image.Ready && bootScreen._started; to: 1; duration: 900; easing.type: Easing.OutQuad }
    }

    // System checks + progress
    ColumnLayout {
        id:                 checkPanel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:     parent.bottom
        anchors.bottomMargin: parent.height * 0.07
        width:              Math.min(parent.width * 0.7, ScreenTools.defaultFontPixelWidth * 80)
        spacing:            ScreenTools.defaultFontPixelHeight * 0.25

        Repeater {
            model: bootScreen._checks.length
            RowLayout {
                Layout.fillWidth:   true
                spacing:            ScreenTools.defaultFontPixelWidth * 1.5
                opacity:            index < bootScreen._shownChecks ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                // Re-evaluate live values while the screen is up
                property int    _state: (bootScreen._elapsed, bootScreen._checks[index].state())
                property string _value: (bootScreen._elapsed, bootScreen._checks[index].value())

                Text {
                    text:               _state === 1 ? "[ OK ]" : (_state === 2 ? "[ -- ]" : "[ .. ]")
                    color:              _state === 1 ? bootScreen._ok : (_state === 2 ? bootScreen._warn : bootScreen._dim)
                    font.family:        ScreenTools.fixedFontFamily
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.85
                    font.weight:        Font.Bold
                }
                Text {
                    text:               bootScreen._checks[index].label
                    color:              bootScreen._text
                    font.family:        ScreenTools.fixedFontFamily
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.85
                    font.letterSpacing: 1
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 22
                }
                Text {
                    text:               _value
                    color:              _state === 1 ? bootScreen._text : bootScreen._subText
                    font.family:        ScreenTools.fixedFontFamily
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.85
                    horizontalAlignment: Text.AlignRight
                    elide:              Text.ElideLeft
                    Layout.fillWidth:   true
                }
            }
        }

        Item { Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.4 }

        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: 4
            color:                  "#C4C4C4"
            Rectangle {
                width:  parent.width * bootScreen._progress
                height: parent.height
                color:  bootScreen._accent
                Behavior on width { NumberAnimation { duration: 120 } }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text:           bootScreen._progress >= 1 ? "SYSTEM READY" : "INITIALISING"
                color:          bootScreen._progress >= 1 ? bootScreen._ok : bootScreen._subText
                font.family:    ScreenTools.fixedFontFamily
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                font.letterSpacing: 2
                Layout.fillWidth: true
            }
            Text {
                text:           Math.round(bootScreen._progress * 100) + "%"
                color:          bootScreen._subText
                font.family:    ScreenTools.fixedFontFamily
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
            }
        }
    }

    Text {
        anchors.right:          parent.right
        anchors.bottom:         parent.bottom
        anchors.margins:        ScreenTools.defaultFontPixelWidth * 1.5
        text:                   "CLICK OR PRESS ANY KEY TO SKIP"
        color:                  bootScreen._dim
        font.family:            ScreenTools.fixedFontFamily
        font.pixelSize:         ScreenTools.defaultFontPixelHeight * 0.65
        font.letterSpacing:     1
    }
}
