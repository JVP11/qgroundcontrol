/****************************************************************************
 *
 * ASTHRA Spatial 3D — virtual camera modes.
 * Follow / Orbit / Top-down / Operator / Free / Reset
 *
 ****************************************************************************/

import QtQuick
import QtQuick3D

Item {
    id: controller

    property var camera: null
    property string mode: "follow"
    readonly property string modeTitle: {
        switch (mode) {
        case "follow": return "FOLLOW"
        case "orbit": return "ORBIT"
        case "topdown": return "TOP"
        case "operator": return "OPERATOR"
        case "free": return "FREE"
        default: return "FOLLOW"
        }
    }

    property vector3d targetPos: Qt.vector3d(0, 5, 0)
    property real targetHeading: 0
    property vector3d operatorPos: Qt.vector3d(0, 1.7, 0)
    property bool operatorValid: false

    property real followDistance: 22
    property real followHeight: 9
    property real orbitAzimuth: 135
    property real orbitElevation: 28
    property real orbitDistance: 28
    property real topDownHeight: 70

    property vector3d freePos: Qt.vector3d(25, 22, 35)
    property real freeYaw: 30
    property real freePitch: -28

    function reset() {
        mode = "follow"
        followDistance = 22
        followHeight = 9
        orbitAzimuth = targetHeading + 180
        orbitElevation = 28
        orbitDistance = Math.max(22, targetPos.y * 1.4 + 16)
        topDownHeight = Math.max(40, targetPos.y * 4 + 40)
        apply()
    }

    function setMode(newMode) {
        if (newMode === "reset") {
            reset()
            return
        }
        if (newMode === "orbit" && mode !== "orbit") {
            orbitAzimuth = targetHeading + 180
            orbitDistance = Math.max(18, followDistance + targetPos.y * 0.3)
        }
        mode = newMode
        apply()
    }

    function apply() {
        if (!camera)
            return
        switch (mode) {
        case "follow":
            _applyFollow()
            break
        case "orbit":
            _applyOrbit()
            break
        case "topdown":
            _applyTopDown()
            break
        case "operator":
            _applyOperator()
            break
        case "free":
            camera.position = freePos
            camera.eulerRotation = Qt.vector3d(freePitch, freeYaw, 0)
            break
        }
    }

    function _lookAt(pos) {
        if (!camera)
            return
        var dx = pos.x - camera.position.x
        var dy = pos.y - camera.position.y
        var dz = pos.z - camera.position.z
        var yaw = Math.atan2(dx, dz) * 180 / Math.PI
        var horiz = Math.sqrt(dx * dx + dz * dz)
        var pitch = -Math.atan2(dy, horiz) * 180 / Math.PI
        camera.eulerRotation = Qt.vector3d(pitch, yaw, 0)
    }

    function _applyFollow() {
        var h = targetHeading * Math.PI / 180
        var dist = followDistance + Math.max(0, targetPos.y) * 0.45
        var ht = followHeight + Math.max(0, targetPos.y) * 0.22
        camera.position = Qt.vector3d(
                    targetPos.x - Math.sin(h) * dist,
                    targetPos.y + ht,
                    targetPos.z + Math.cos(h) * dist)
        _lookAt(targetPos)
    }

    function _applyOrbit() {
        var az = orbitAzimuth * Math.PI / 180
        var el = orbitElevation * Math.PI / 180
        var d = Math.max(8, orbitDistance)
        camera.position = Qt.vector3d(
                    targetPos.x + Math.cos(el) * Math.sin(az) * d,
                    targetPos.y + Math.sin(el) * d,
                    targetPos.z + Math.cos(el) * Math.cos(az) * d)
        _lookAt(targetPos)
    }

    function _applyTopDown() {
        var h = Math.max(25, topDownHeight)
        camera.position = Qt.vector3d(targetPos.x, targetPos.y + h, targetPos.z)
        camera.eulerRotation = Qt.vector3d(-90, -targetHeading, 0)
    }

    function _applyOperator() {
        if (!operatorValid) {
            _applyFollow()
            return
        }
        camera.position = Qt.vector3d(operatorPos.x, operatorPos.y + 1.6, operatorPos.z)
        _lookAt(targetPos)
    }

    function onDrag(dx, dy) {
        if (mode === "free") {
            freeYaw -= dx * 0.25
            freePitch = Math.max(-89, Math.min(-5, freePitch - dy * 0.2))
            apply()
            return
        }
        if (mode !== "orbit")
            setMode("orbit")
        orbitAzimuth += dx * 0.35
        orbitElevation = Math.max(8, Math.min(80, orbitElevation + dy * 0.25))
        apply()
    }

    function onPan(dx, dy) {
        if (mode !== "free")
            setMode("free")
        var yaw = freeYaw * Math.PI / 180
        var right = Qt.vector3d(Math.cos(yaw), 0, -Math.sin(yaw))
        var fwd = Qt.vector3d(-Math.sin(yaw), 0, -Math.cos(yaw))
        freePos = Qt.vector3d(
                    freePos.x - right.x * dx * 0.08 + fwd.x * dy * 0.08,
                    freePos.y,
                    freePos.z - right.z * dx * 0.08 + fwd.z * dy * 0.08)
        camera.position = freePos
        camera.eulerRotation = Qt.vector3d(freePitch, freeYaw, 0)
    }

    function onWheel(delta) {
        var step = delta > 0 ? 0.9 : 1.12
        if (mode === "follow") {
            followDistance = Math.max(8, Math.min(200, followDistance * step))
        } else if (mode === "orbit") {
            orbitDistance = Math.max(8, Math.min(400, orbitDistance * step))
        } else if (mode === "topdown") {
            topDownHeight = Math.max(15, Math.min(500, topDownHeight * step))
        } else if (mode === "free") {
            var yaw = freeYaw * Math.PI / 180
            var pitch = freePitch * Math.PI / 180
            var dist = (delta > 0 ? 2.5 : -2.5)
            freePos = Qt.vector3d(
                        freePos.x - Math.sin(yaw) * Math.cos(pitch) * dist,
                        freePos.y + Math.sin(pitch) * dist,
                        freePos.z - Math.cos(yaw) * Math.cos(pitch) * dist)
        }
        apply()
    }
}
