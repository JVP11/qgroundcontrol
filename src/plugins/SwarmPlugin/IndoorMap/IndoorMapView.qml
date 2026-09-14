// Indoor map — live vehicle positions + DJI-style mission path

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property var    swarmBridge
    property string floorPlanPath: ""
    property real   roomWidthM:  10.0
    property real   roomHeightM:  8.0

    property int    selectedDroneId: -1
    property real   collisionRadiusM: 1.5
    property bool   show3DButton: true

    signal droneClicked(int sysid)
    signal open3DView()
    signal waypointAdded(real x, real y, real z)

    readonly property var displayStates: swarmBridge ? swarmBridge.droneStates : []

    readonly property real ppm: {
        var pw = mapImage.paintedWidth > 0 ? mapImage.paintedWidth : width * 0.85
        var ph = mapImage.paintedHeight > 0 ? mapImage.paintedHeight : height * 0.85
        return Math.max(8, Math.min(pw / roomWidthM, ph / roomHeightM))
    }
    readonly property real originX: (width  - mapImage.paintedWidth)  / 2
    readonly property real originY: (height - mapImage.paintedHeight) / 2

    function nedToScreen(nx, ny) {
        return Qt.point(
            originX + mapImage.paintedWidth  / 2 + ny * ppm,
            originY + mapImage.paintedHeight / 2 - nx * ppm
        )
    }

    function screenToNed(sx, sy) {
        var ny = (sx - originX - mapImage.paintedWidth / 2) / ppm
        var nx = -(sy - originY - mapImage.paintedHeight / 2) / ppm
        return Qt.point(nx, ny)
    }

    QGCPalette { id: qgcPal }

    function undoLastWaypoint() {
        if (waypointModel.count > 0) {
            waypointModel.remove(waypointModel.count - 1)
            pathCanvas.requestRepaint()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#161a22"
    }

    Canvas {
        id: gridCanvas
        anchors.fill: parent
        z: 0
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = "#161a22"
            ctx.fillRect(0, 0, width, height)
            var step = Math.max(20, root.ppm)
            ctx.strokeStyle = "#2e3848"
            ctx.lineWidth = 1
            for (var gx = 0; gx < width; gx += step) {
                ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke()
            }
            for (var gy = 0; gy < height; gy += step) {
                ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
            }
            var ox = root.originX
            var oy = root.originY
            var pw = mapImage.paintedWidth > 0 ? mapImage.paintedWidth : width * 0.85
            var ph = mapImage.paintedHeight > 0 ? mapImage.paintedHeight : height * 0.85
            ctx.strokeStyle = "#7F77DD"
            ctx.lineWidth = 2
            ctx.strokeRect(ox, oy, pw, ph)
        }
    }

    Image {
        id: mapImage
        anchors.fill: parent
        source: root.floorPlanPath
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: status === Image.Ready ? 0.92 : 0
        z: 1
        onStatusChanged: gridCanvas.requestPaint()
        onPaintedWidthChanged: gridCanvas.requestPaint()
        onPaintedHeightChanged: gridCanvas.requestPaint()
    }

    MissionPathCanvas {
        id: pathCanvas
        mapRoot: root
        waypointModel: waypointModel
        selectedDroneId: root.selectedDroneId
        droneStates: root.displayStates
    }

    Connections {
        target: root.swarmBridge
        function onDroneStatesChanged() { pathCanvas.requestRepaint() }
    }

    Repeater {
        model: waypointModel
        delegate: WaypointMarker {
            property point sc: root.nedToScreen(model.x, model.y)
            x: sc.x - width / 2
            y: sc.y - height / 2
            index: model.index
            altitude: model.z
            onMoved: function(dx, dy) {
                model.x += dy / root.ppm
                model.y += dx / root.ppm
                pathCanvas.requestRepaint()
            }
        }
    }

    ListModel { id: waypointModel }

    Repeater {
        model: root.displayStates

        delegate: Item {
            property var drone: modelData
            property bool hasPos: drone.has_local_position !== false
            property point sc: hasPos ? root.nedToScreen(drone.x, drone.y) : Qt.point(-100, -100)
            visible: hasPos

            x: sc.x - 20
            y: sc.y - 20
            width: 40
            height: 40

            Rectangle {
                id: bubble
                property real rad: root.collisionRadiusM * root.ppm * 2
                width: rad
                height: rad
                radius: rad / 2
                color: "transparent"
                border.color: drone.collision_warning ? "#E24B4A" : "#1D9E7540"
                border.width: drone.collision_warning ? 2 : 1
                anchors.centerIn: parent
                opacity: 0.5
            }

            Rectangle {
                id: body
                width: 32
                height: 32
                radius: 16
                anchors.centerIn: parent
                color: {
                    if (!drone.armed) return "#444441"
                    if (drone.collision_warning) return "#E24B4A"
                    if (drone.sysid === root.selectedDroneId) return "#7F77DD"
                    return "#1D9E75"
                }
                border.color: Qt.lighter(color, 1.4)
                border.width: drone.sysid === root.selectedDroneId ? 2 : 1

                Rectangle {
                    width: 3
                    height: 11
                    radius: 1
                    color: "white"
                    opacity: 0.9
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    transform: Rotation {
                        origin.x: 1.5
                        origin.y: (body.height / 2) - 2
                        angle: -drone.yaw * 180 / Math.PI
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "D" + drone.sysid
                    color: "white"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: body.bottom
                anchors.topMargin: 3
                text: drone.battery_pct + "%"
                color: "#9FE1CB"
                font.pixelSize: 10
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: body.top
                anchors.bottomMargin: 3
                text: (-drone.z).toFixed(1) + "m"
                color: "#B5D4F4"
                font.pixelSize: 10
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.droneClicked(drone.sysid)
            }
        }
    }

    // DJI-style: tap map to add waypoint
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: function(mouse) {
            var ned = root.screenToNed(mouse.x, mouse.y)
            waypointModel.append({ x: ned.x, y: ned.y, z: -1.5 })
            root.waypointAdded(ned.x, ned.y, -1.5)
            pathCanvas.requestRepaint()
        }
    }

    QGCLabel {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: ScreenTools.defaultFontPixelWidth
        color: qgcPal.colorGrey
        font.pointSize: ScreenTools.smallFontPointSize
        font.family: ScreenTools.fixedFontFamily
        text: qsTr("TAP MAP — ADD WAYPOINTS  |  LINE = PLANNED ROUTE")
    }

    Item {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        Rectangle {
            width: root.ppm * 2
            height: 3
            color: "white"
            opacity: 0.6
            anchors.bottom: scaleLabel.top
            anchors.bottomMargin: 4
        }
        Text {
            id: scaleLabel
            text: "2 m"
            color: "white"
            opacity: 0.6
            font.pixelSize: 11
            anchors.bottom: parent.bottom
        }
    }

    QGCButton {
        visible: root.show3DButton
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 12
        text: qsTr("3D view")
        onClicked: root.open3DView()
    }
}
