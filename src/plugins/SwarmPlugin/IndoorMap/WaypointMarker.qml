// Waypoint marker for indoor path planner map

import QtQuick

Item {
    id: root
    width: 28
    height: 28

    property int index: 0
    property real altitude: 1.5

    signal moved(real dx, real dy)

    property real _dragStartX: 0
    property real _dragStartY: 0

    Rectangle {
        anchors.centerIn: parent
        width: 24
        height: 24
        radius: 12
        color: "#534AB7"
        border.color: "#EEEDFE"
        border.width: 2

        Text {
            anchors.centerIn: parent
            text: root.index + 1
            color: "#EEEDFE"
            font.pixelSize: 11
            font.bold: true
        }
    }

    DragHandler {
        target: parent
        onActiveChanged: {
            if (active) {
                root._dragStartX = root.x
                root._dragStartY = root.y
            }
        }
        onTranslationChanged: {
            root.x = root._dragStartX + translation.x
            root.y = root._dragStartY + translation.y
            root.moved(translation.x, translation.y)
        }
    }
}
