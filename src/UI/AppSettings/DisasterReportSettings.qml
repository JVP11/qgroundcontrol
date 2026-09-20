/****************************************************************************
 *
 * ASTHRA - Disaster Report Settings Page
 * Professional settings interface for disaster response mission configuration
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

SettingsPage {
    id: root

    property var _settingsManager: QGroundControl.settingsManager
    property var _appSettings: _settingsManager ? _settingsManager.appSettings : null

    // ASTHRA Disaster Report Settings
    property var disasterReportGenerator: null
    property var missionLogger: null
    property var telemetryLogger: null
    property var cameraFrameCapture: null

    // Settings properties
    property string disasterType: "flood"
    property string commandAuthority: ""
    property string responseTeam: ""
    property bool autoCaptureFrames: true
    property bool captureInOffboard: true
    property bool captureDuringDescent: true
    property int offboardCaptureInterval: 2000
    property int descentCaptureInterval: 1000

    // Header Section
    SettingsGroupLayout {
        Layout.fillWidth:   true
        heading:            qsTr("ASTHRA Disaster Response Configuration")
        headingDescription: qsTr("Configure disaster management mission parameters and reporting options")

        LabelledComboBox {
            Layout.fillWidth:   true
            label:              qsTr("Disaster Type")
            model:              ["flood", "earthquake", "landslide", "fire", "cyclone", "tsunami", "other"]
            currentIndex:       model.indexOf(disasterType)
            onCurrentTextChanged: {
                disasterType = currentText
                if (disasterReportGenerator) {
                    disasterReportGenerator.setDisasterMetadata(disasterType, "", commandAuthority, responseTeam)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 2

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Command Authority")
            }

            QGCTextField {
                Layout.fillWidth: true
                text: commandAuthority
                onTextChanged: {
                    commandAuthority = text
                    if (disasterReportGenerator) {
                        disasterReportGenerator.setDisasterMetadata(disasterType, "", commandAuthority, responseTeam)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 2

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Response Team")
            }

            QGCTextField {
                Layout.fillWidth: true
                text: responseTeam
                onTextChanged: {
                    responseTeam = text
                    if (disasterReportGenerator) {
                        disasterReportGenerator.setDisasterMetadata(disasterType, "", commandAuthority, responseTeam)
                    }
                }
            }
        }
    }

    // Camera Frame Capture Settings
    SettingsGroupLayout {
        Layout.fillWidth:   true
        heading:            qsTr("Camera Frame Capture")
        headingDescription: qsTr("Configure automatic image capture during critical flight phases")

        QGCCheckBoxSlider {
            Layout.fillWidth:   true
            text:               qsTr("Enable Automatic Frame Capture")
            checked:            autoCaptureFrames
            onCheckedChanged: {
                autoCaptureFrames = checked
                if (cameraFrameCapture) {
                    cameraFrameCapture.captureInOffboard = checked && captureInOffboard
                    cameraFrameCapture.captureDuringDescent = checked && captureDuringDescent
                }
            }
        }

        QGCCheckBoxSlider {
            Layout.fillWidth:   true
            text:               qsTr("Capture During OFFBOARD Mode")
            checked:            captureInOffboard
            enabled:            autoCaptureFrames
            onCheckedChanged: {
                captureInOffboard = checked
                if (cameraFrameCapture) {
                    cameraFrameCapture.captureInOffboard = checked
                }
            }
        }

        QGCCheckBoxSlider {
            Layout.fillWidth:   true
            text:               qsTr("Capture During Descent Phase")
            checked:            captureDuringDescent
            enabled:            autoCaptureFrames
            onCheckedChanged: {
                captureDuringDescent = checked
                if (cameraFrameCapture) {
                    cameraFrameCapture.captureDuringDescent = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 2
            enabled: autoCaptureFrames && captureInOffboard

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("OFFBOARD Capture Interval (ms)")
            }

            QGCTextField {
                Layout.fillWidth: true
                text: offboardCaptureInterval.toString()
                onTextChanged: {
                    var interval = parseInt(text)
                    if (!isNaN(interval) && interval > 0) {
                        offboardCaptureInterval = interval
                        if (cameraFrameCapture) {
                            cameraFrameCapture.captureInterval = interval
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 2
            enabled: autoCaptureFrames && captureDuringDescent

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Descent Capture Interval (ms)")
            }

            QGCTextField {
                Layout.fillWidth: true
                text: descentCaptureInterval.toString()
                onTextChanged: {
                    var interval = parseInt(text)
                    if (!isNaN(interval) && interval > 0) {
                        descentCaptureInterval = interval
                        if (cameraFrameCapture) {
                            cameraFrameCapture.descentCaptureInterval = interval
                        }
                    }
                }
            }
        }
    }

    // Telemetry Logging Settings
    SettingsGroupLayout {
        Layout.fillWidth:   true
        heading:            qsTr("Telemetry Logging")
        headingDescription: qsTr("Configure telemetry data capture parameters")

        LabelledLabel {
            label:              qsTr("Sample Rate")
            labelText:          qsTr("1 sample per second")
        }

        LabelledLabel {
            label:              qsTr("Data Captured")
            labelText:          qsTr("GPS, Battery, Link Quality, Sensors, Attitude, Velocity")
        }

        LabelledLabel {
            label:              qsTr("Status")
            labelText:          telemetryLogger && telemetryLogger.sampleTimer && telemetryLogger.sampleTimer.running ?
                               qsTr("Active - Logging") : qsTr("Inactive")
        }
    }

    // Mission Logging Status
    SettingsGroupLayout {
        Layout.fillWidth:   true
        heading:            qsTr("Mission Status")
        headingDescription: qsTr("Current mission logging and capture status")

        LabelledLabel {
            label:              qsTr("Mission Active")
            labelText:          missionLogger && missionLogger.missionActive ? qsTr("Yes") : qsTr("No")
        }

        LabelledLabel {
            label:              qsTr("Mission Start Time")
            labelText:          missionLogger && missionLogger.missionStartTime ?
                               missionLogger.missionStartTime.toLocaleString() : qsTr("Not started")
        }

        LabelledLabel {
            label:              qsTr("Events Logged")
            labelText:          missionLogger ? missionLogger.missionEvents.length.toString() : "0"
        }

        LabelledLabel {
            label:              qsTr("Telemetry Samples")
            labelText:          telemetryLogger ? telemetryLogger.telemetrySamples.length.toString() : "0"
        }

        LabelledLabel {
            label:              qsTr("Frames Captured")
            labelText:          cameraFrameCapture ? cameraFrameCapture.capturedFrames.length.toString() : "0"
        }
    }

            // Fleet Vehicle Connection
            SettingsGroupLayout {
                Layout.fillWidth:   true
                heading:            qsTr("Fleet Connection")
                headingDescription: qsTr("Connect any number of drones. Each must have a unique system ID.")

                QGCButton {
                    Layout.fillWidth:   true
                    text:               qsTr("Open Vehicle Connection Wizard")
                    onClicked: {
                        if (mainWindow) {
                            mainWindow.showTool(qsTr("Vehicle Connection"), "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRADualVehicleConnection.qml", "")
                        }
                    }
                }

                LabelledLabel {
                    label:              qsTr("Connected Vehicles")
                    labelText:          QGroundControl.multiVehicleManager.vehicles.count.toString()
                }
            }

            // Report Generation
            SettingsGroupLayout {
                Layout.fillWidth:   true
                heading:            qsTr("Report Generation")
                headingDescription: qsTr("Generate comprehensive disaster response mission reports")

                QGCButton {
                    Layout.fillWidth:   true
                    text:               qsTr("Open Disaster Report Panel")
                    onClicked: {
                        console.log("ASTHRA: Open disaster report panel")
                    }
                }

                LabelledLabel {
                    label:              qsTr("Report Formats")
                    labelText:          qsTr("JSON, KML, CSV, GeoJSON")
                }
            }

    Component.onCompleted: {
        console.log("ASTHRA: Disaster Report Settings page loaded")
    }
}
