/****************************************************************************
 *
 * ASTHRA Spatial 3D — optional tactical panel (split with 2D map).
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: spatialView

    property var planMasterController: null

    color:          qgcPal.windowShade
    border.width:   2
    border.color:   qgcPal.buttonBorder
    clip:           true

    QGCPalette { id: qgcPal }

    readonly property var _active: QGroundControl.multiVehicleManager.activeVehicle
    readonly property real _rangeM: {
        if (!_active)
            return NaN
        if (_active.distanceToGCS && !isNaN(_active.distanceToGCS.value))
            return _active.distanceToGCS.value
        if (_active.coordinate && _active.coordinate.isValid && scene.gpsRef && scene.gpsRef.isValid)
            return _active.coordinate.distanceTo(scene.gpsRef)
        return NaN
    }

    ASTHRASpatialCameraController {
        id: camCtl
    }

    Item {
        anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 3
        width: 10; height: 10; z: 30
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 2; height: 10; color: qgcPal.colorBlue }
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 10; height: 2; color: qgcPal.colorBlue }
    }
    Item {
        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 3
        width: 10; height: 10; z: 30
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 2; height: 10; color: qgcPal.colorBlue }
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 10; height: 2; color: qgcPal.colorBlue }
    }
    Item {
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 3
        width: 10; height: 10; z: 30
        Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 2; height: 10; color: qgcPal.colorBlue }
        Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 10; height: 2; color: qgcPal.colorBlue }
    }
    Item {
        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 3
        width: 10; height: 10; z: 30
        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 2; height: 10; color: qgcPal.colorBlue }
        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 10; height: 2; color: qgcPal.colorBlue }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.6
            color: qgcPal.window

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                color: qgcPal.buttonBorder
            }
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.lighter(qgcPal.window, 1.2)
                opacity: 0.3
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: "3D VIEW"
                    font.family: ScreenTools.fixedFontFamily
                    font.bold: true
                    font.pointSize: ScreenTools.defaultFontPointSize
                    color: qgcPal.text
                }

                QGCLabel {
                    text: "·  " + camCtl.modeTitle
                    font.family: ScreenTools.fixedFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: "#8B9199"
                }

                Rectangle {
                    width: 7; height: 7
                    color: checkStrip.summaryColor
                    border.width: 1
                    border.color: Qt.darker(color, 1.4)
                }

                QGCLabel {
                    text: checkStrip.summary
                    font.family: ScreenTools.fixedFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: checkStrip.summaryColor
                }

                Item { Layout.fillWidth: true }

                QGCButton {
                    text: "CLOSE"
                    font.family: ScreenTools.fixedFontFamily
                    font.weight: Font.Bold
                    font.pointSize: ScreenTools.smallFontPointSize
                    Layout.preferredHeight: parent.height * 0.72
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                    onClicked: mainWindow.toggleSpatial3DView()
                    ToolTip.visible: hovered
                    ToolTip.delay: 400
                    ToolTip.text: "Hide 3D and use the full map"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Mode rail
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 12
                color: qgcPal.window
                border.width: 0

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: qgcPal.buttonBorder
                }

                Flickable {
                    id: railFlick
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    contentWidth: width
                    contentHeight: railCol.height

                    ColumnLayout {
                        id: railCol
                        width: railFlick.width
                        height: Math.max(implicitHeight, railFlick.height)
                        spacing: 6

                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "VIEW"
                        font.family: ScreenTools.fixedFontFamily
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: "#8B9199"
                    }

                    QGCButton {
                        text: "FOLLOW"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        primary: camCtl.mode === "follow"
                        onClicked: camCtl.setMode("follow")
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        ToolTip.text: "Stay behind the drone"
                    }
                    QGCButton {
                        text: "ORBIT"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        primary: camCtl.mode === "orbit"
                        onClicked: camCtl.setMode("orbit")
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        ToolTip.text: "Drag on the plot to rotate around the drone"
                    }
                    QGCButton {
                        text: "TOP"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        primary: camCtl.mode === "topdown"
                        onClicked: camCtl.setMode("topdown")
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        ToolTip.text: "Look straight down"
                    }
                    QGCButton {
                        text: "OPERATOR"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        enabled: scene.operatorValid
                        primary: camCtl.mode === "operator"
                        onClicked: camCtl.setMode("operator")
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        ToolTip.text: scene.operatorValid ? "Look from this computer's GPS position" : "Needs this computer's GPS (not available)"
                    }
                    QGCButton {
                        text: "FREE"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        primary: camCtl.mode === "free"
                        onClicked: camCtl.setMode("free")
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        ToolTip.text: "Look around. Right-drag to pan, wheel to zoom"
                    }

                    Item { Layout.fillHeight: true }

                    QGCButton {
                        text: "RESET"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        onClicked: camCtl.reset()
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        ToolTip.text: "Return to follow view"
                    }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ASTHRASpatial3DScene {
                    id: scene
                    anchors.fill: parent
                    planMasterController: spatialView.planMasterController
                    cameraController: camCtl
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    hoverEnabled: true
                    property real _lastX: 0
                    property real _lastY: 0
                    onPressed: function (mouse) {
                        _lastX = mouse.x
                        _lastY = mouse.y
                    }
                    onPositionChanged: function (mouse) {
                        if (!pressed)
                            return
                        var dx = mouse.x - _lastX
                        var dy = mouse.y - _lastY
                        _lastX = mouse.x
                        _lastY = mouse.y
                        if (mouse.buttons & Qt.RightButton || mouse.buttons & Qt.MiddleButton)
                            camCtl.onPan(dx, dy)
                        else
                            camCtl.onDrag(dx, dy)
                    }
                    onWheel: function (wheel) {
                        camCtl.onWheel(wheel.angleDelta.y)
                        wheel.accepted = true
                    }
                }

                ASTHRASpatialCheckStrip {
                    id: checkStrip
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 8
                    width: Math.min(parent.width - 16, ScreenTools.defaultFontPixelWidth * 54)
                    vehicle: _active
                    operatorValid: scene.operatorValid
                    originLabel: scene.originLabel
                    originKind: scene.originKind
                    stale: scene.stale
                    headingEstimated: scene.headingEstimated
                    fovEstimated: scene.fovEstimated
                    gpsWeak: scene.gpsWeak
                    altSource: scene.altSource
                    lookLabel: scene.lookLabel
                    gpsLock: _active && _active.gps ? _active.gps.lock.rawValue : 0
                    hdop: _active && _active.gps ? _active.gps.hdop.value : NaN
                    linkLoss: _active && _active.mavlinkLossPercent !== undefined ? _active.mavlinkLossPercent : NaN
                    commLost: !_active || (_active.vehicleLinkManager && _active.vehicleLinkManager.communicationLost)
                    z: 20
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    height: hintLabel.implicitHeight + 10
                    width: hintLabel.implicitWidth + 16
                    color: qgcPal.window
                    opacity: 0.92
                    border.width: 1
                    border.color: qgcPal.buttonBorder
                    visible: parent.width > 440

                    QGCLabel {
                        id: hintLabel
                        anchors.centerIn: parent
                        text: "Drag orbit  ·  Wheel zoom  ·  Right-drag pan"
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: "#8B9199"
                    }
                }

                ASTHRASpatialHud {
                    id: hud
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    width: Math.min(parent.width - 16, ScreenTools.defaultFontPixelWidth * 40)
                    height: Math.min(implicitHeight, Math.max(0, parent.height - 16))
                    clip: true
                    vehicle: _active
                    originLabel: scene.originLabel
                    rangeM: spatialView._rangeM
                    altM: {
                        if (!_active)
                            return NaN
                        if (scene.altSource === "RNG" && _active.distanceSensors)
                            return _active.distanceSensors.rotationPitch270.value
                        if (_active.altitudeRelative)
                            return _active.altitudeRelative.value
                        return NaN
                    }
                    altSource: scene.altSource
                    headingDeg: _active && _active.heading ? _active.heading.value : NaN
                    headingEstimated: scene.headingEstimated
                    fovEstimated: scene.fovEstimated
                    stale: scene.stale
                    operatorValid: scene.operatorValid
                    lookLabel: scene.lookLabel
                    rangeLegend: scene.rangeLegend
                }
            }
        }
    }

    Component.onCompleted: camCtl.reset()
}
