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

    // Drawn larger than life (real span 1.27 m) so drones stay readable from the default camera distance.
    property real modelScale: 1.8
    property real _propSpin: 0

    // Hub positions in model metres; 1/3 and 2/4 are diagonal pairs and counter-rotate.
    readonly property var _propHubs: [
        { pos: Qt.vector3d( 0.4142, 0.125, -0.4165), dir:  1 },
        { pos: Qt.vector3d( 0.4142, 0.205,  0.4120), dir: -1 },
        { pos: Qt.vector3d(-0.4142, 0.205,  0.4120), dir:  1 },
        { pos: Qt.vector3d(-0.4142, 0.125, -0.4165), dir: -1 }
    ]

    NumberAnimation on _propSpin {
        from:       0
        to:         360
        duration:   180
        loops:      Animation.Infinite
        running:    vehNode.visible && vehNode.vehicle && vehNode.vehicle.armed && !vehNode.stale
    }

    Node {
        opacity: stale ? 0.35 : (gpsWeak ? 0.55 : (isActive ? 1 : 0.5))
        eulerRotation: Qt.vector3d(_pitch, -_heading, -_roll)

        Node {
            scale: Qt.vector3d(vehNode.modelScale, vehNode.modelScale, vehNode.modelScale)

            ASTHRADroneBody { }

            Repeater3D {
                model: vehNode._propHubs
                delegate: ASTHRADronePropeller {
                    required property var modelData
                    position: modelData.pos
                    eulerRotation: Qt.vector3d(0, vehNode._propSpin * modelData.dir, 0)
                }
            }
        }

        // Status disc under the airframe: green active, amber estimated heading, grey stale/weak GPS
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(0, -0.36 * vehNode.modelScale, 0)
            scale: Qt.vector3d(0.013 * vehNode.modelScale, 0.0003, 0.013 * vehNode.modelScale)
            materials: PrincipledMaterial {
                baseColor: vehNode.bodyColor
                opacity: 0.32
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
