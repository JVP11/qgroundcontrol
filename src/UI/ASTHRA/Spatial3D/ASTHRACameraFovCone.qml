/****************************************************************************
 *
 * ASTHRA Spatial 3D — camera FOV cone. Gimbal-true or heading-estimated.
 *
 ****************************************************************************/

import QtQuick
import QtQuick3D

Node {
    id: fovRoot

    property real yawDeg: 0
    property real pitchDeg: 0
    property real fovDeg: 70
    property real lengthM: 12
    property bool estimated: true
    property bool coneVisible: true

    visible: coneVisible && lengthM > 0.5

    // Cone mesh points +Y. Rotate to vehicle look: heading 0 = north = -Z.
    eulerRotation.y: -yawDeg

    Node {
        eulerRotation.x: -90 + pitchDeg

        Model {
            source: "#Cone"
            // Qt built-in cone is 100 units; put base at origin, extend along +Y (look).
            position: Qt.vector3d(0, fovRoot.lengthM * 0.5, 0)
            scale: {
                var half = Math.max(0.4, fovRoot.lengthM * Math.tan((fovRoot.fovDeg * 0.5) * Math.PI / 180))
                return Qt.vector3d(half / 50, fovRoot.lengthM / 100, half / 50)
            }
            materials: PrincipledMaterial {
                baseColor: fovRoot.estimated ? "#D4A017" : "#2D4A5F"
                metalness: 0
                roughness: 1
                opacity: 0.14
                alphaMode: PrincipledMaterial.Blend
            }
        }

        Model {
            visible: fovRoot.estimated
            source: "#Cube"
            position: Qt.vector3d(0, fovRoot.lengthM * 0.22, 0)
            scale: Qt.vector3d(0.008, 0.008, 0.008)
            materials: PrincipledMaterial {
                baseColor: "#D4A017"
                roughness: 0.5
                metalness: 0.05
            }
        }
    }
}
