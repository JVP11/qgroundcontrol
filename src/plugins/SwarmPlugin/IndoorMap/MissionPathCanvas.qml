// DJI-style mission path overlay (lines + direction arrows)

import QtQuick

Canvas {
    id: pathCanvas

    property var mapRoot
    property var waypointModel
    property int selectedDroneId: -1
    property var droneStates: []

    z: 4
    anchors.fill: parent

    onPaint: {
        if (!mapRoot || !waypointModel) {
            return
        }
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)

        var count = waypointModel.count
        if (count === 0) {
            return
        }

        function screenForWp(wp) {
            return mapRoot.nedToScreen(wp.x, wp.y)
        }

        // Line from selected drone → first waypoint (approach leg)
        if (selectedDroneId > 0 && droneStates) {
            for (var d = 0; d < droneStates.length; d++) {
                var drone = droneStates[d]
                if (drone.sysid === selectedDroneId && drone.has_local_position !== false) {
                    var p0 = mapRoot.nedToScreen(drone.x, drone.y)
                    var p1 = screenForWp(waypointModel.get(0))
                    ctx.strokeStyle = "#9FE1CB"
                    ctx.lineWidth = 2
                    ctx.setLineDash([6, 8])
                    ctx.beginPath()
                    ctx.moveTo(p0.x, p0.y)
                    ctx.lineTo(p1.x, p1.y)
                    ctx.stroke()
                    ctx.setLineDash([])
                    break
                }
            }
        }

        if (count < 2) {
            return
        }

        // Main mission path
        ctx.strokeStyle = "#7F77DD"
        ctx.lineWidth = 3
        ctx.setLineDash([])
        ctx.beginPath()
        for (var i = 0; i < count; i++) {
            var pt = screenForWp(waypointModel.get(i))
            if (i === 0) {
                ctx.moveTo(pt.x, pt.y)
            } else {
                ctx.lineTo(pt.x, pt.y)
            }
        }
        ctx.stroke()

        // Direction arrows on each segment
        for (var s = 0; s < count - 1; s++) {
            var a = screenForWp(waypointModel.get(s))
            var b = screenForWp(waypointModel.get(s + 1))
            var mx = (a.x + b.x) / 2
            var my = (a.y + b.y) / 2
            var ang = Math.atan2(b.y - a.y, b.x - a.x)
            ctx.save()
            ctx.translate(mx, my)
            ctx.rotate(ang)
            ctx.fillStyle = "#EEEDFE"
            ctx.beginPath()
            ctx.moveTo(8, 0)
            ctx.lineTo(-6, -5)
            ctx.lineTo(-6, 5)
            ctx.closePath()
            ctx.fill()
            ctx.restore()
        }
    }

    function requestRepaint() {
        pathCanvas.requestPaint()
    }

    Connections {
        target: waypointModel
        function onCountChanged() { pathCanvas.requestRepaint() }
    }

    Connections {
        target: mapRoot
        function onWidthChanged() { pathCanvas.requestRepaint() }
        function onHeightChanged() { pathCanvas.requestRepaint() }
    }
}
