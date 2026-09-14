import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Military-Industrial styled push button control
/// Angular design with tactical aesthetics
Button {
    property bool primary: false
    property bool showBorder: true  // Always show border for military look
    property real backRadius: 2     // Sharp corners for tactical appearance
    property real heightFactor: 0.5
    property string iconSource: ""
    property real fontWeight: Font.DemiBold // Slightly bolder for readability
    property real pointSize: ScreenTools.defaultFontPointSize

    property alias wrapMode: text.wrapMode
    property alias horizontalAlignment: text.horizontalAlignment
    property alias backgroundColor: backRect.color
    property alias textColor: text.color

    id: control
    hoverEnabled: !ScreenTools.isMobile
    topPadding: _verticalPadding
    bottomPadding: _verticalPadding
    leftPadding: _horizontalPadding
    rightPadding: _horizontalPadding
    focusPolicy: Qt.ClickFocus
    font.family: ScreenTools.normalFontFamily
    text: ""

    property bool _showHighlight: enabled && (pressed | checked)
    property int _horizontalPadding: ScreenTools.defaultFontPixelWidth * 2
    property int _verticalPadding: Math.round(ScreenTools.defaultFontPixelHeight * heightFactor) - (iconSource === "" ? 0 : (_iconHeight - ScreenTools.defaultFontPixelHeight)  / 2)
    property real _iconHeight: text.height * 1.5

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    background: Rectangle {
        id: backRect
        radius: backRadius
        implicitWidth: ScreenTools.implicitButtonWidth
        implicitHeight: ScreenTools.implicitButtonHeight
        border.width: 1
        border.color: _showHighlight ? qgcPal.buttonHighlight : (control.enabled && control.hovered ? qgcPal.buttonBorder : Qt.darker(qgcPal.buttonBorder, 1.3))
        color: primary ? qgcPal.primaryButton : qgcPal.button

        // Tactical gradient overlay for depth
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(backRect.color, 1.1) }
            GradientStop { position: 0.5; color: backRect.color }
            GradientStop { position: 1.0; color: Qt.darker(backRect.color, 1.15) }
        }

        // Top highlight line for beveled effect
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 1
            color: Qt.lighter(backRect.color, 1.3)
            opacity: 0.5
            radius: backRadius
        }

        // Highlight overlay on press/hover
        Rectangle {
            anchors.fill: parent
            color: qgcPal.buttonHighlight
            opacity: _showHighlight ? 0.9 : control.enabled && control.hovered ? 0.15 : 0
            radius: parent.radius

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
        }

        // Corner accent (tactical detail)
        Rectangle {
            visible: primary
            anchors.right: parent.right
            anchors.top: parent.top
            width: 4
            height: 4
            color: qgcPal.buttonHighlight
        }
    }

    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth

        QGCColoredImage {
            id: icon
            Layout.alignment: Qt.AlignHCenter
            source: control.iconSource
            height: _iconHeight
            width: height
            color: text.color
            fillMode: Image.PreserveAspectFit
            sourceSize.height: height
            visible: control.iconSource !== ""
        }

        QGCLabel {
            id: text
            Layout.alignment: Qt.AlignHCenter
            text: control.text
            font.pointSize: control.pointSize
            font.family: control.font.family
            font.weight: fontWeight
            font.letterSpacing: 0.5  // Slight letter spacing for military look
            color: _showHighlight ? qgcPal.buttonHighlightText : (primary ? qgcPal.primaryButtonText : qgcPal.buttonText)
            visible: control.text !== ""
        }
    }
}
