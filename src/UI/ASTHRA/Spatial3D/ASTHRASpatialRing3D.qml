/****************************************************************************
 *
 * ASTHRA Spatial 3D — flat circle outline in the XZ plane (meters).
 *
 ****************************************************************************/

import QtQuick
import QtQuick3D

Node {
    id: ring

    property real radius: 10
    property int segments: 48
    property color color: "#3F5566"
    property real lineWidth: 0.1
    property real opacityFactor: 1

    Repeater3D {
        model: ring.segments
        delegate: ASTHRASpatialLine3D {
            required property int index
            readonly property real _a0: index / ring.segments * Math.PI * 2
            readonly property real _a1: (index + 1) / ring.segments * Math.PI * 2
            p1: Qt.vector3d(Math.cos(_a0) * ring.radius, 0, Math.sin(_a0) * ring.radius)
            p2: Qt.vector3d(Math.cos(_a1) * ring.radius, 0, Math.sin(_a1) * ring.radius)
            color: ring.color
            lineWidth: ring.lineWidth
            opacityFactor: ring.opacityFactor
        }
    }
}
