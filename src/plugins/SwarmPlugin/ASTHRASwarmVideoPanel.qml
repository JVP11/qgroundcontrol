// Live camera / video feed for swarm operations

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Rectangle {
    id: root
    color: qgcPal.windowShadeDark
    border.width: 1
    border.color: qgcPal.buttonBorder

    QGCPalette { id: qgcPal }

    readonly property bool _streaming: QGroundControl.videoManager
            && QGroundControl.videoManager.streaming
    readonly property bool _hasVideo: QGroundControl.videoManager
            && QGroundControl.videoManager.hasVideo

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
            color: qgcPal.toolbarBackground
            border.width: 1
            border.color: qgcPal.buttonBorder

            RowLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text: qsTr("CAMERA")
                    font.family: ScreenTools.fixedFontFamily
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: _streaming ? qgcPal.colorGreen : qgcPal.colorRed
                }
                QGCLabel {
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: qgcPal.colorGrey
                    text: _streaming ? qsTr("LIVE") : (_hasVideo ? qsTr("READY") : qsTr("NO SIGNAL"))
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                id: videoLoader
                anchors.fill: parent
                active: _hasVideo
                source: "qrc:/qml/QGroundControl/FlyView/FlightDisplayViewVideo.qml"
                onLoaded: {
                    if (item) {
                        item.useSmallFont = true
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: qgcPal.windowShadeDark
                visible: !_hasVideo
                QGCLabel {
                    anchors.centerIn: parent
                    width: parent.width - ScreenTools.defaultFontPixelWidth * 2
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.family: ScreenTools.fixedFontFamily
                    color: qgcPal.colorGrey
                    text: qsTr("No video source.\nSettings → Video → set UDP/RTSP or UVC camera.")
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: ScreenTools.defaultFontPixelHeight * 2
                color: "#99000000"
                visible: _hasVideo && !_streaming
                QGCLabel {
                    anchors.centerIn: parent
                    font.family: ScreenTools.fixedFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: "white"
                    text: {
                        var v = QGroundControl.multiVehicleManager.activeVehicle
                        if (!v) return qsTr("Connect a vehicle for camera telemetry")
                        return qsTr("Vehicle %1 — waiting for stream").arg(v.id)
                    }
                }
            }
        }
    }
}
