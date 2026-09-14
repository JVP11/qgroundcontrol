/****************************************************************************
 *
 * ASTHRA Spatial 3D — one UAV: body, attitude, altitude stem, FOV cone.
 *
 ****************************************************************************/

import QtQuick
import QtQuick3D

Node {
    id: vehNode

    property var vehicle: null
    property bool isActive: true
    property bool stale: false
    property bool gpsWeak: false
    property bool headingEstimated: false
    property bool fovEstimated: true
    property real fovYaw: 0
    property real fovPitch: 0
    property real fovDeg: 70
    property bool showFov: true
    property vector3d enuPos: Qt.vector3d(0, 0, 0)
    property real groundSpeed: 0
    property real courseDeg: 0

    readonly property real _heading: headingEstimated && vehicle && vehicle.gps
                                     ? vehicle.gps.courseOverGround.value
                                     : ((vehicle && vehicle.heading) ? vehicle.heading.value : 0)
    readonly property real _pitch: (vehicle && vehicle.pitch) ? vehicle.pitch.value : 0
    readonly property real _roll: (vehicle && vehicle.roll) ? vehicle.roll.value : 0

    visible: vehicle !== null && vehicle !== undefined
    position: enuPos

    readonly property color bodyColor: {
        if (stale)
            return "#3D4247"
        if (!isActive)
            return "#2A3036"
        if (gpsWeak)
            return "#8B9199"
        return headingEstimated ? "#D4A017" : "#2A8B55"
    }

    Node {
        opacity: stale ? 0.35 : (gpsWeak ? 0.55 : (isActive ? 1 : 0.5))
        eulerRotation: Qt.vector3d(_pitch, -_heading, -_roll)

        Model {
            source: "#Cube"
            scale: Qt.vector3d(0.010, 0.006, 0.022)
            materials: PrincipledMaterial {
                baseColor: vehNode.bodyColor
                metalness: 0.08
                roughness: 0.72
            }
        }

        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 0, -1.4)
            scale: Qt.vector3d(0.006, 0.005, 0.008)
            materials: PrincipledMaterial {
                baseColor: vehNode.isActive ? "#F0F2F4" : vehNode.bodyColor
                metalness: 0.05
                roughness: 0.65
            }
        }

        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 0.08, 0)
            scale: Qt.vector3d(0.026, 0.0012, 0.008)
            materials: PrincipledMaterial {
                baseColor: vehNode.bodyColor
                opacity: 0.55
                alphaMode: PrincipledMaterial.Blend
                roughness: 1
            }
        }
    }

    ASTHRACameraFovCone {
        yawDeg: vehNode.fovYaw
        pitchDeg: vehNode.fovPitch
        fovDeg: vehNode.fovDeg
        lengthM: Math.max(8, Math.min(40, vehNode.enuPos.y * 0.8 + 10))
        estimated: vehNode.fovEstimated
        coneVisible: vehNode.showFov && vehNode.isActive && !vehNode.stale
    }

    ASTHRASpatialLine3D {
        visible: vehNode.isActive && vehNode.groundSpeed > 0.4 && !vehNode.stale
        p1: Qt.vector3d(0, 0.08, 0)
        p2: {
            var len = Math.max(2.5, Math.min(18, vehNode.groundSpeed * 1.2))
            var h = vehNode.courseDeg * Math.PI / 180
            return Qt.vector3d(Math.sin(h) * len, 0.08, -Math.cos(h) * len)
        }
        color: "#D4A017"
        lineWidth: 0.12
        opacityFactor: 0.85
    }

    Model {
        source: "#Cylinder"
        position: Qt.vector3d(0, -enuPos.y * 0.5, 0)
        scale: Qt.vector3d(0.0035, Math.max(0.01, enuPos.y) / 100, 0.0035)
        materials: PrincipledMaterial {
            baseColor: stale ? "#3D4247" : "#2D4A5F"
            opacity: 0.7
            alphaMode: PrincipledMaterial.Blend
            roughness: 1
        }
        visible: enuPos.y > 0.3
    }

    Model {
        source: "#Cube"
        position: Qt.vector3d(0, -enuPos.y + 0.03, 0)
        scale: Qt.vector3d(0.016, 0.0005, 0.016)
        materials: PrincipledMaterial {
            baseColor: "#000000"
            opacity: 0.4
            alphaMode: PrincipledMaterial.Blend
            roughness: 1
        }
        visible: enuPos.y > 0.2
    }
}
