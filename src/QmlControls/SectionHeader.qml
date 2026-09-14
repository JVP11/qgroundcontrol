import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Military-Industrial Section Header
/// Features tactical styling with angular accents
CheckBox {
    id:             control
    focusPolicy:    Qt.ClickFocus
    checked:        true
    leftPadding:    0

    property var            color:          qgcPal.text
    property bool           showSpacer:     true
    property ButtonGroup    buttonGroup:    null

    property real _sectionSpacer: ScreenTools.defaultFontPixelWidth / 2

    onButtonGroupChanged: {
        if (buttonGroup) {
            buttonGroup.addButton(control)
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    contentItem: ColumnLayout {
        spacing: 2

        Item {
            Layout.preferredHeight: control._sectionSpacer
            width:                  1
            visible:                control.showSpacer
        }

        // Section header with tactical styling
        Rectangle {
            Layout.fillWidth:   true
            height:             sectionLabel.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.4
            color:              "transparent"

            // Left accent bar
            Rectangle {
                id: accentBar
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: parent.height * 0.7
                color: control.checked ? qgcPal.buttonBorder : qgcPal.windowShadeLight

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            QGCLabel {
                id:                     sectionLabel
                anchors.left:           accentBar.right
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                anchors.verticalCenter: parent.verticalCenter
                text:                   control.text.toUpperCase()
                color:                  control.color
                font.weight:            Font.DemiBold
                font.letterSpacing:     1.5
                font.pointSize:         ScreenTools.defaultFontPointSize * 0.9
            }

            QGCColoredImage {
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                width:                  parent.height * 0.4
                height:                 width
                source:                 "/qmlimages/arrow-down.png"
                color:                  qgcPal.text
                visible:                !control.checked
                rotation:               0

                Behavior on rotation {
                    NumberAnimation { duration: 150 }
                }
            }
        }

        // Tactical divider line
        Rectangle {
            Layout.fillWidth:   true
            height:             1
            color:              qgcPal.windowShadeLight

            // Gradient fade on right side
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: qgcPal.buttonBorder }
                GradientStop { position: 0.3; color: qgcPal.windowShadeLight }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    indicator: Item {}
}
