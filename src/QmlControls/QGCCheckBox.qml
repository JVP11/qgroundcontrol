import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

CheckBox {
    id:             control
    spacing:        _noText ? 0 : ScreenTools.defaultFontPixelWidth
    focusPolicy:    Qt.ClickFocus
    leftPadding:    0

    Component.onCompleted: {
        if (_noText) {
            rightPadding = 0
        }
    }

    property color  textColor:          qgcPal.buttonText
    property bool   textBold:           false
    property real   textFontPointSize:  ScreenTools.defaultFontPointSize
    property ButtonGroup buttonGroup: null

    property bool _noText: text === ""

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    onButtonGroupChanged: {
        if (buttonGroup) {
            buttonGroup.addButton(control)
        }
    }

    contentItem: Text {
        //implicitWidth:  _noText ? 0 : text.implicitWidth + ScreenTools.defaultFontPixelWidth * 0.25
        //implicitHeight: _noText ? 0 : Math.max(text.implicitHeight, ScreenTools.checkBoxIndicatorSize)
        leftPadding:        control.indicator.width + control.spacing
        verticalAlignment:  Text.AlignVCenter
        text:               control.text
        font.pointSize:     textFontPointSize
        font.bold:          control.textBold
        font.family:        ScreenTools.normalFontFamily
        color:              control.textColor
    }

    // Military-Industrial Checkbox Indicator
    indicator:  Rectangle {
        implicitWidth:  ScreenTools.implicitCheckBoxHeight
        implicitHeight: implicitWidth
        x:              control.leftPadding
        y:              parent.height / 2 - height / 2
        color:          control.enabled ? qgcPal.textField : "transparent"
        border.color:   control.checked ? qgcPal.buttonHighlight : (control.hovered ? qgcPal.buttonBorder : Qt.darker(qgcPal.windowShadeLight, 1.2))
        border.width:   1
        radius:         2  // Sharp corners for tactical look
        opacity:        control.checkedState === Qt.PartiallyChecked ? 0.5 : 1

        // Hover highlight
        Rectangle {
            anchors.fill:   parent
            color:          qgcPal.buttonHighlight
            opacity:        control.hovered ? 0.15 : 0
            radius:         parent.radius

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
        }

        // Check mark with tactical styling
        Rectangle {
            visible:            control.checked
            anchors.centerIn:   parent
            width:              parent.implicitWidth * 0.6
            height:             width
            color:              qgcPal.buttonHighlight
            radius:             1

            // Inner detail for depth
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.4
                height: width
                color: Qt.darker(qgcPal.buttonHighlight, 1.3)
                radius: 1
            }
        }
    }
}
