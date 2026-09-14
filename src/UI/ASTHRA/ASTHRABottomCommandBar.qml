/****************************************************************************
 *
 * ASTHRA - Bottom Command Bar
 * Operator Actions Panel
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

/// Bottom Command Action Bar - Military Standard
/// Height: 56-64px, text-first buttons, large spacing, red ONLY for ABORT
Rectangle {
    id:             commandBar
    height:         ScreenTools.defaultFontPixelHeight * 4.2  // Slightly taller
    anchors.left:   parent.left
    anchors.right:  parent.right
    anchors.bottom: parent.bottom
    color:          qgcPal.window  // Tactical Black
    border.width:   0
    clip:           true

    // Top border for separation with tactical notches
    Item {
        anchors.top: parent.top
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

    // Bottom highlight line for industrial bevel
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.lighter(qgcPal.window, 1.2)
        opacity: 0.3
    }

    // Military corner brackets - Bottom corners (optimized Rectangle-based for performance)
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
    property real _standardButtonWidth: ScreenTools.defaultFontPixelWidth * 16
    property real _minButtonWidth: ScreenTools.defaultFontPixelWidth * 9
    property real _standardSpacing: ScreenTools.defaultFontPixelWidth * 1.2

    RowLayout {
        anchors.fill:       parent
        anchors.margins:    ScreenTools.defaultFontPixelWidth * 1.0  // More padding
        spacing:            _standardSpacing

        // Left side - View Switching (Text-first, no icons alone)
                QGCButton {
                    text:           "FLY"
                    font.family:    ScreenTools.fixedFontFamily
                    font.weight:    Font.Bold
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.3  // Industrial standard - larger text
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  _standardButtonWidth
                    Layout.minimumWidth:    _minButtonWidth
                    Layout.maximumWidth:    _standardButtonWidth
                    Layout.preferredHeight: parent.height * 0.855
                    primary:        flyView.visible
            onClicked:      mainWindow.showFlyView()
        }

                QGCButton {
                    text:           "PLAN"
                    font.family:    ScreenTools.fixedFontFamily
                    font.weight:    Font.Bold
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.3  // Industrial standard - larger text
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  _standardButtonWidth
                    Layout.minimumWidth:    _minButtonWidth
                    Layout.maximumWidth:    _standardButtonWidth
                    Layout.preferredHeight: parent.height * 0.855
                    primary:        planView.visible

            // Military indicator dot
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 2
                width: 4
                height: 4
                radius: 2
                color: planView.visible ? qgcPal.colorGreen : qgcPal.colorGrey
                border.width: 1
                border.color: Qt.darker(color, 1.3)
            }

            onClicked:      mainWindow.showPlanView()
        }

        QGCButton {
            text:           "3D VIEW"
            font.family:    ScreenTools.fixedFontFamily
            font.weight:    Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.3
            Layout.fillWidth:       true
            Layout.preferredWidth:  _standardButtonWidth
            Layout.minimumWidth:    _minButtonWidth
            Layout.maximumWidth:    _standardButtonWidth
            Layout.preferredHeight: parent.height * 0.855
            primary:        mainWindow.spatial3DOpen

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 2
                width: 4
                height: 4
                radius: 2
                color: mainWindow.spatial3DOpen ? qgcPal.colorGreen : qgcPal.colorGrey
                border.width: 1
                border.color: Qt.darker(color, 1.3)
            }

            onClicked:      mainWindow.toggleSpatial3DView()
            ToolTip.visible: hovered
            ToolTip.delay: 400
            ToolTip.text: mainWindow.spatial3DOpen ? "Hide the 3D pane" : "Show 3D next to the map (look-only)"
        }

        QGCButton {
            text:           "SWARM"
            font.family:    ScreenTools.fixedFontFamily
            font.weight:    Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.3
            Layout.fillWidth:       true
            Layout.preferredWidth:  _standardButtonWidth
            Layout.minimumWidth:    _minButtonWidth
            Layout.maximumWidth:    _standardButtonWidth
            Layout.preferredHeight: parent.height * 0.855
            backgroundColor: qgcPal.colorBlue
            onClicked:      mainWindow.showSwarmCoverage()
            ToolTip.visible: hovered
            ToolTip.delay: 400
            ToolTip.text: "Connect drones and split land on the map"
        }

        QGCButton {
            text:           "ANALYZE"
            font.family:    ScreenTools.fixedFontFamily
            font.weight:    Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.3
            Layout.fillWidth:       true
            Layout.preferredWidth:  _standardButtonWidth
            Layout.minimumWidth:    _minButtonWidth
            Layout.maximumWidth:    _standardButtonWidth
            Layout.preferredHeight: parent.height * 0.85
            onClicked:      mainWindow.showAnalyzeTool()
        }

        Item { Layout.fillWidth: true }

        // Mode Control - Industrial Standard Buttons
        QGCButton {
            text:           "SETTINGS"
            font.family:    ScreenTools.fixedFontFamily
            font.weight:    Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.3  // Industrial standard - larger text
            Layout.fillWidth:       true
            Layout.preferredWidth:  _standardButtonWidth
            Layout.minimumWidth:    _minButtonWidth
            Layout.maximumWidth:    _standardButtonWidth
            Layout.preferredHeight: parent.height * 0.855
            onClicked:      mainWindow.showSettingsTool()
        }

        QGCButton {
            text:           "CONFIG"
            font.family:    ScreenTools.fixedFontFamily
            font.weight:    Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.3  // Industrial standard - larger text
            Layout.fillWidth:       true
            Layout.preferredWidth:  _standardButtonWidth
            Layout.minimumWidth:    _minButtonWidth
            Layout.maximumWidth:    _standardButtonWidth
            Layout.preferredHeight: parent.height * 0.855
            onClicked:      mainWindow.showVehicleConfig()
        }

        QGCButton {
            text:           "RESCUE"
            font.family:    ScreenTools.fixedFontFamily
            font.weight:    Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.3  // Industrial standard - larger text
            Layout.fillWidth:       true
            Layout.preferredWidth:  _standardButtonWidth
            Layout.minimumWidth:    _minButtonWidth
            Layout.maximumWidth:    _standardButtonWidth
            Layout.preferredHeight: parent.height * 0.855
            backgroundColor: qgcPal.colorRed  // Red for rescue/critical
            onClicked:      mainWindow.showRescueReport()
        }

        Item { Layout.fillWidth: true }

        // Right side - Critical Actions (Text-first, confirmation required, red ONLY for ABORT)
        QGCDelayButton {
            id:                 armButton
            enabled:            _activeVehicle && !_activeVehicle.armed
            text:               "ARM"
            font.family:        ScreenTools.fixedFontFamily
            font.weight:        Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.3
            Layout.fillWidth:       true
            Layout.preferredWidth:  _standardButtonWidth
            Layout.minimumWidth:    _minButtonWidth
            Layout.maximumWidth:    _standardButtonWidth
            Layout.preferredHeight: parent.height * 0.85
            onActivated:        {
                if (_activeVehicle) {
                    _activeVehicle.armed = true
                }
            }
        }

        QGCDelayButton {
            id:                 disarmButton
            enabled:            _activeVehicle && _activeVehicle.armed
            text:               "DISARM"
            font.family:        ScreenTools.fixedFontFamily
            font.weight:        Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.3
            Layout.fillWidth:       true
            Layout.preferredWidth:  _standardButtonWidth
            Layout.minimumWidth:    _minButtonWidth
            Layout.maximumWidth:    _standardButtonWidth
            Layout.preferredHeight: parent.height * 0.85
            onActivated:        {
                if (_activeVehicle) {
                    _activeVehicle.armed = false
                }
            }
        }

        QGCDelayButton {
            id:                 rtlButton
            enabled:            _activeVehicle && _activeVehicle.armed
            text:               "RTL"
            font.family:        ScreenTools.fixedFontFamily
            font.weight:        Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.3
            Layout.fillWidth:       true
            Layout.preferredWidth:  _standardButtonWidth
            Layout.minimumWidth:    _minButtonWidth
            Layout.maximumWidth:    _standardButtonWidth
            Layout.preferredHeight: parent.height * 0.85
            onActivated:        {
                if (_activeVehicle && globals && globals.guidedControllerFlyView) {
                    globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionRTL)
                }
            }
        }

        QGCDelayButton {
            id:                 abortButton
            enabled:            _activeVehicle && _activeVehicle.armed
            text:               "ABORT"
            font.family:        ScreenTools.fixedFontFamily
            font.weight:        Font.Bold
            font.pointSize: ScreenTools.defaultFontPointSize * 1.3
            Layout.fillWidth:       true
            Layout.preferredWidth:  _standardButtonWidth
            Layout.minimumWidth:    _minButtonWidth
            Layout.maximumWidth:    _standardButtonWidth
            Layout.preferredHeight: parent.height * 0.85
            backgroundColor:    qgcPal.colorRed  // Red ONLY for ABORT
            onActivated:        {
                if (_activeVehicle && globals && globals.guidedControllerFlyView) {
                    globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionLand)
                }
            }
        }
    }

    // Reference to views for button state
    property var flyView: null
    property var planView: null
    property var globals: null
}

