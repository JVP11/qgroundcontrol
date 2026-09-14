import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Military-Industrial Settings Group Layout
/// Features tactical styling with angular accents
ColumnLayout {
    id:                 control
    spacing:            _margins / 2
    implicitWidth:      _contentLayout.implicitWidth + (_margins * 2)
    implicitHeight:     _contentLayout.implicitHeight + (_margins * 2)

    default property alias contentItem: _contentLayout.data

    property alias contentSpacing: _contentLayout.spacing

    property string defaultBorderColor  : QGroundControl.globalPalette.groupBorder
    property string outerBorderColor    : defaultBorderColor

    property string defaultHeadingPointSize:    ScreenTools.defaultFontPointSize + 1
    property string headingPointSize:           defaultHeadingPointSize

    property string heading
    property string headingDescription
    property bool   showDividers:       true
    property bool   showBorder:         true

    property real _margins: ScreenTools.defaultFontPixelHeight / 2

    // Military-Industrial Header Section
    ColumnLayout {
        Layout.leftMargin:  _margins
        Layout.fillWidth:   true
        spacing:            2
        visible:            heading !== ""

        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth / 2

            // Tactical accent bar
            Rectangle {
                width: 3
                height: headingLabel.height
                color: QGroundControl.globalPalette.buttonBorder
            }

        QGCLabel {
                id:             headingLabel
                text:           heading.toUpperCase()
            font.pointSize: headingPointSize
                font.weight:    Font.DemiBold
                font.letterSpacing: 1
            }
        }

        QGCLabel {
            Layout.fillWidth:   true
            Layout.leftMargin:  ScreenTools.defaultFontPixelWidth + 3
            text:               headingDescription
            wrapMode:           Text.WordWrap
            font.pointSize:     ScreenTools.smallFontPointSize
            visible:            headingDescription !== ""
            opacity:            0.7
        }
    }

    Rectangle {
        id:                 outerRect
        Layout.fillWidth:   true
        implicitWidth:      _contentLayout.implicitWidth + (showBorder ? _margins * 2 : 0)
        implicitHeight:     _contentLayout.implicitHeight + (showBorder ? _margins * 2: 0)
        color:              "transparent"
        border.color:       outerBorderColor
        border.width:       showBorder ? 1 : 0
        radius:             2  // Sharp corners for tactical look

        // Top-left corner accent
        Rectangle {
            visible: showBorder
            anchors.top: parent.top
            anchors.left: parent.left
            width: 8
            height: 2
            color: QGroundControl.globalPalette.buttonBorder
        }
        Rectangle {
            visible: showBorder
            anchors.top: parent.top
            anchors.left: parent.left
            width: 2
            height: 8
            color: QGroundControl.globalPalette.buttonBorder
        }

        Repeater {
            model: showDividers ? Math.max(0, _contentLayout.visibleChildren.length - 1) : 0

            Rectangle {
                x:                  showBorder ? _margins : 0
                y:                  _contentItem.y + _contentItem.height + _margins + (showBorder ? _margins : 0)
                width:              parent.width - (showBorder ? _margins * 2 : 0)
                height:             1
                color:              QGroundControl.globalPalette.groupBorder
                opacity:            0.5

                property var _contentItem: _contentLayout.visibleChildren[index]
            }
        }

        ColumnLayout {
            id:                 _contentLayout
            x:                  showBorder ? _margins : 0
            y:                  showBorder ? _margins : 0
            width:              parent.width - (showBorder ? _margins * 2 : 0)
            spacing:            _margins * (showDividers ? 2 : 1)
        }
    }
}
