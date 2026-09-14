/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

/// Military-Industrial Group Box
GroupBox {
    id: control

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    background: Rectangle {
        y:      control.topPadding - control.padding
        width:  parent.width
        height: parent.height - control.topPadding + control.padding
        color:  qgcPal.windowShade
        radius: 2  // Sharp corners for tactical look
        border.width: 1
        border.color: Qt.darker(qgcPal.windowShadeLight, 1.2)

        // Top accent line
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: qgcPal.buttonBorder
            opacity: 0.5
        }
    }

    label: QGCLabel {
        width:              control.availableWidth
        text:               control.title.toUpperCase()
        font.weight:        Font.DemiBold
        font.letterSpacing: 0.5
    }
}
