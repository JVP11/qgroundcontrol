/****************************************************************************
 *
 * ASTHRA Spatial 3D — segment between two scene points (meters).
 *
 ****************************************************************************/

import QtQuick
import QtQuick3D

Node {
    id: lineBody

    property vector3d p1: Qt.vector3d(0, 0, 0)
    property vector3d p2: Qt.vector3d(0, 1, 0)
    property real lineWidth: 0.18
    property color color: "#3d9cf0"
    property real opacityFactor: 1

    readonly property vector3d _delta: Qt.vector3d(p2.x - p1.x, p2.y - p1.y, p2.z - p1.z)
    readonly property real _length: Math.sqrt(_delta.x * _delta.x + _delta.y * _delta.y + _delta.z * _delta.z)

    visible: _length > 0.05

    function _cross(a, b) {
        return Qt.vector3d(a.y * b.z - a.z * b.y,
                           a.z * b.x - a.x * b.z,
                           a.x * b.y - a.y * b.x)
    }

    function _norm(v) {
        var n = Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        if (n < 1e-6)
            return Qt.vector3d(0, 1, 0)
        return Qt.vector3d(v.x / n, v.y / n, v.z / n)
    }

    function _rotationBetween(fromVec, toVec) {
        var a = _norm(fromVec)
        var b = _norm(toVec)
        var c = a.x * b.x + a.y * b.y + a.z * b.z
        if (c > 0.9999)
            return Quaternion.fromEulerAngles(Qt.vector3d(0, 0, 0))
        if (c < -0.9999)
            return Quaternion.fromEulerAngles(Qt.vector3d(180, 0, 0))
        var axis = _norm(_cross(a, b))
        return Quaternion.fromAxisAndAngle(axis, Math.acos(Math.max(-1, Math.min(1, c))) * 180 / Math.PI)
    }

    position: p1
    rotation: _rotationBetween(Qt.vector3d(0, 1, 0), _delta)

    Model {
        source: "#Cylinder"
        scale: Qt.vector3d(lineBody.lineWidth / 50, lineBody._length / 100, lineBody.lineWidth / 50)
        position: Qt.vector3d(0, lineBody._length * 0.5, 0)
        materials: PrincipledMaterial {
            baseColor: lineBody.color
            metalness: 0
            roughness: 0.7
            opacity: lineBody.opacityFactor
            alphaMode: lineBody.opacityFactor < 0.99 ? PrincipledMaterial.Blend : PrincipledMaterial.Opaque
        }
    }
}
