// Indoor 3D room view using Qt Quick 3D (no WebEngine required)

import QtQuick
import QtQuick3D
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property var swarmBridge

    readonly property real roomW: 12
    readonly property real roomH: 9
    readonly property real roomAlt: 3.5

    function pushDroneJson(json) {
        // Called from RoomView3D; states come from swarmBridge directly
    }

    View3D {
        id: view3d
        anchors.fill: parent
        environment: SceneEnvironment {
            clearColor: "#0d0d1a"
            backgroundMode: SceneEnvironment.Color
        }

        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(0, 10, 14)
            eulerRotation.x: -35
            clipNear: 0.1
        }

        DirectionalLight {
            eulerRotation.x: -45
            eulerRotation.y: 45
            brightness: 1.2
            castsShadow: true
        }

        DirectionalLight {
            eulerRotation.x: -30
            eulerRotation.y: -120
            brightness: 0.4
        }

        // Floor
        Model {
            source: "#Rectangle"
            scale: Qt.vector3d(roomW, roomH, 1)
            eulerRotation.x: -90
            position: Qt.vector3d(0, 0, 0)
            materials: PrincipledMaterial {
                baseColor: "#1a1a3a"
                roughness: 0.9
            }
        }

        // Wireframe room box
        Model {
            source: "#Cube"
            scale: Qt.vector3d(roomW, roomAlt, roomH)
            position: Qt.vector3d(0, roomAlt / 2, 0)
            materials: PrincipledMaterial {
                baseColor: "#334466"
                opacity: 0.15
                alphaMode: PrincipledMaterial.Blend
                roughness: 1
            }
        }

        Repeater3D {
            id: droneRepeater
            model: root.swarmBridge ? root.swarmBridge.droneStates : []

            delegate: Node {
                property var drone: modelData

                // NED → scene: x=right(y), y=up(-z), z=back(-x)
                property vector3d pos: Qt.vector3d(drone.y, -drone.z, -drone.x)

                position: pos
                eulerRotation.y: -drone.yaw * 180 / Math.PI

                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(0.5, 0.08, 0.5)
                    materials: PrincipledMaterial {
                        baseColor: drone.collision_warning ? "#E24B4A"
                            : (drone.armed ? "#1D9E75" : "#444441")
                    }
                }

                Model {
                    source: "#Sphere"
                    scale: Qt.vector3d(3, 3, 3)
                    materials: PrincipledMaterial {
                        baseColor: drone.collision_warning ? "#E24B4A" : "#1D9E75"
                        opacity: drone.collision_warning ? 0.25 : 0.08
                        alphaMode: PrincipledMaterial.Blend
                    }
                }
            }
        }
    }

    QGCLabel {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 8
        color: "#9FE1CB"
        font.family: "monospace"
        font.pixelSize: ScreenTools.smallFontPointSize
        text: {
            if (!root.swarmBridge || !root.swarmBridge.droneStates.length) {
                return qsTr("No swarm data — start coordinator on port 7900")
            }
            var lines = []
            for (var i = 0; i < root.swarmBridge.droneStates.length; i++) {
                var d = root.swarmBridge.droneStates[i]
                lines.push("D" + d.sysid + "  x" + d.x.toFixed(1) + " y" + d.y.toFixed(1) +
                           " z" + (-d.z).toFixed(1) + "m  " + (d.armed ? "ARMED" : "disarm") +
                           "  " + d.battery_pct + "%")
            }
            return lines.join("\n")
        }
    }
}
