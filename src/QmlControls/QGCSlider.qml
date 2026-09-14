import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Slider {
    property bool zeroCentered: false ///< Value indicator starts display from zero instead of min value
    property bool displayValue: false ///< true: Show value on handle
    property bool showBoundaryValues: false ///< true: Show min/max values at slider ends

    id: control
    implicitHeight: ScreenTools.implicitSliderHeight + (showBoundaryValues ? minLabel.contentHeight : 0)
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    wheelEnabled: false

    property real _implicitBarLength: Math.round(ScreenTools.defaultFontPixelWidth * 20)
    property real _barHeight: Math.round(ScreenTools.defaultFontPixelHeight / 3)

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    // Military-Industrial Slider Track
    background: Rectangle {
        x: control.horizontal ? control.leftPadding : control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.horizontal ? control.topPadding + control.availableHeight / 2 - height / 2 : control.topPadding
        implicitWidth: control.horizontal ? control._implicitBarLength : control._barHeight
        implicitHeight: control.horizontal ? control._barHeight : control._implicitBarLength
        width: control.horizontal ? control.availableWidth : implicitWidth
        height: control.horizontal ? implicitHeight : control.availableHeight
        radius: 1  // Sharp corners for tactical look
        color: qgcPal.windowShadeDark
        border.width: 1
        border.color: Qt.darker(qgcPal.windowShadeLight, 1.2)

        // Filled portion (tactical cyan)
        Rectangle {
            width: control.horizontal ? control.visualPosition * parent.width : parent.width
            height: control.horizontal ? parent.height : control.visualPosition * parent.height
            radius: 1
            color: qgcPal.buttonBorder
            opacity: 0.7
        }
    }

    // Military-Industrial Slider Handle
    handle: Rectangle {
        x: control.horizontal ?
               control.leftPadding + control.visualPosition * (control.availableWidth - width) :
               control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.horizontal ?
               control.topPadding + control.availableHeight / 2 - height / 2 :
               control.topPadding + control.visualPosition * (control.availableHeight - height)
        implicitWidth: _radius * 2
        implicitHeight: _radius * 2
        color: qgcPal.button
        border.color: control.pressed ? qgcPal.buttonHighlight : qgcPal.buttonBorder
        border.width: 2
        radius: 2  // Sharp corners

        property real _radius: ScreenTools.defaultFontPixelHeight / 2

        // Inner detail for depth
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.4
            height: parent.height * 0.4
            color: qgcPal.buttonBorder
            radius: 1
        }

        Label {
            text: control.value.toFixed(control.to <= 1 ? 1 : 0)
            visible: control.displayValue
            anchors.centerIn: parent
            font.family: ScreenTools.normalFontFamily
            font.pointSize: ScreenTools.smallFontPointSize
            font.weight: Font.DemiBold
            color: qgcPal.buttonText
        }

        Behavior on border.color {
            ColorAnimation { duration: 100 }
        }
    }

    QGCLabel {
        id: minLabel
        anchors.left: parent.left
        anchors.leftMargin: control.leftPadding
        anchors.bottom: parent.bottom
        text: control.from.toFixed(1)
        font.pointSize: ScreenTools.smallFontPointSize
        color: qgcPal.buttonText
        visible: control.showBoundaryValues
    }

    QGCLabel {
        id: maxLabel
        anchors.right: parent.right
        anchors.rightMargin: control.rightPadding
        anchors.bottom: parent.bottom
        text: control.to.toFixed(1)
        font.pointSize: ScreenTools.smallFontPointSize
        color: qgcPal.buttonText
        visible: control.showBoundaryValues
    }
}
