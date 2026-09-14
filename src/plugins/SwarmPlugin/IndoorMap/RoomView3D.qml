// Indoor 3D room view — WebEngine (Three.js) or Qt Quick 3D fallback

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root
    color: "#0d0d1a"
    radius: 8
    border.color: "#534AB7"
    border.width: 1

    property var swarmBridge
    signal closeRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            QGCLabel {
                text: qsTr("Indoor 3D view")
                font.bold: true
                Layout.fillWidth: true
            }
            QGCButton {
                text: qsTr("Close")
                onClicked: root.closeRequested()
            }
        }

        Loader {
            id: webLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.swarmBridge && root.swarmBridge.webEngineAvailable
            source: "RoomView3DWebEngine.qml"
            onLoaded: root._pushDronesTo3D()
        }

        Loader {
            id: quick3dLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.swarmBridge && !root.swarmBridge.webEngineAvailable
            source: "RoomView3DQuick.qml"
            onLoaded: {
                if (item) {
                    item.swarmBridge = root.swarmBridge
                }
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: !webLoader.active && !quick3dLoader.active
            text: qsTr("3D view unavailable. Run the ground coordinator (port 7900) for live swarm telemetry.")
        }
    }

    Connections {
        target: root.swarmBridge
        function onDroneStatesChanged() {
            root._pushDronesTo3D()
        }
    }

    function _pushDronesTo3D() {
        if (!root.swarmBridge) {
            return
        }
        if (webLoader.active && webLoader.item && webLoader.item.pushDroneJson) {
            webLoader.item.pushDroneJson(JSON.stringify(root.swarmBridge.droneStates))
        }
    }
}
