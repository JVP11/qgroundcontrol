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
    property color fleetColor: "#4A90D9"

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

    // Far away, grow the airframe so it never shrinks below minScreenPx on screen.
    property vector3d cameraPos: Qt.vector3d(0, 0, 0)
    property real viewHeightPx: 0
    property real viewFovDeg: 50
    property real minScreenPx: 34
    readonly property real drawScale: {
        if (viewHeightPx <= 0)
            return modelScale
        var d = cameraPos.minus(enuPos).length()
        var needed = minScreenPx * 2 * d * Math.tan(viewFovDeg * Math.PI / 360) / viewHeightPx / 1.27
        return Math.max(modelScale, Math.min(60, needed))
    }
    readonly property real _boost: drawScale / modelScale
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
            scale: Qt.vector3d(vehNode.drawScale, vehNode.drawScale, vehNode.drawScale)

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
    }

    ASTHRACameraFovCone {
        yawDeg: vehNode.fovYaw
        pitchDeg: vehNode.fovPitch
        fovDeg: vehNode.fovDeg
        lengthM: Math.max(5, Math.min(18, vehNode.enuPos.y * 0.5 + 5))
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
        castsShadows: false
        position: Qt.vector3d(0, -enuPos.y * 0.5, 0)
        scale: Qt.vector3d(0.0012 * vehNode._boost, Math.max(0.01, enuPos.y) / 100, 0.0012 * vehNode._boost)
        materials: PrincipledMaterial {
            baseColor: stale ? "#3D4247" : vehNode.fleetColor
            opacity: 0.45
            alphaMode: PrincipledMaterial.Blend
            roughness: 1
        }
        visible: enuPos.y > 0.3
    }

    // Ground reticle under the drone in its fleet colour
    Node {
        id: reticle
        position: Qt.vector3d(0, -vehNode.enuPos.y + 0.06, 0)
        readonly property real _r: 0.6 * vehNode.drawScale
        readonly property color _c: vehNode.stale ? "#3D4247" : vehNode.fleetColor

        ASTHRASpatialRing3D {
            radius: reticle._r
            segments: 28
            color: reticle._c
            lineWidth: reticle._r * 0.07
        }
        ASTHRASpatialLine3D {
            p1: Qt.vector3d(-reticle._r * 1.5, 0, 0)
            p2: Qt.vector3d(-reticle._r * 0.4, 0, 0)
            color: reticle._c
            lineWidth: reticle._r * 0.05
        }
        ASTHRASpatialLine3D {
            p1: Qt.vector3d(reticle._r * 0.4, 0, 0)
            p2: Qt.vector3d(reticle._r * 1.5, 0, 0)
            color: reticle._c
            lineWidth: reticle._r * 0.05
        }
        ASTHRASpatialLine3D {
            p1: Qt.vector3d(0, 0, -reticle._r * 1.5)
            p2: Qt.vector3d(0, 0, -reticle._r * 0.4)
            color: reticle._c
            lineWidth: reticle._r * 0.05
        }
        ASTHRASpatialLine3D {
            p1: Qt.vector3d(0, 0, reticle._r * 0.4)
            p2: Qt.vector3d(0, 0, reticle._r * 1.5)
            color: reticle._c
            lineWidth: reticle._r * 0.05
        }
    }
}
