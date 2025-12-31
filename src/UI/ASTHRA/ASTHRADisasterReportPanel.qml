/****************************************************************************
 *
 * ASTHRA - Disaster Management Report Panel
 * UI component for viewing and generating disaster response reports
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools

Rectangle {
    id: reportPanel
    color: qgcPal.window

    property var missionLogger: null
    property var telemetryLogger: null
    property var offboardMonitor: null
    property var activeVehicle: null
    property var missionController: null
    property var reportGenerator: null

    // Disaster metadata input
    property string disasterType: "flood"
    property string missionId: ""
    property string commandAuthority: ""
    property string responseTeam: ""

    // Report generation state
    property bool reportGenerating: false
    property var generatedReport: null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight

        // Professional Header with Status
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: headerRow.height + ScreenTools.defaultFontPixelHeight
            color: qgcPal.windowShadeDark
            radius: ScreenTools.defaultFontPixelWidth * 0.5
            border.color: qgcPal.buttonBorder
            border.width: 1

            RowLayout {
                id: headerRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: ScreenTools.defaultFontPixelWidth

                // ASTHRA Branding
                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    
                    Rectangle {
                        width: 4
                        height: ScreenTools.defaultFontPixelHeight * 1.5
                        color: qgcPal.colorBlue
                    }

                    QGCLabel {
                        text: "ASTHRA DISASTER REPORT"
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.3
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                        color: qgcPal.text
                    }

                    Rectangle {
                        width: 4
                        height: ScreenTools.defaultFontPixelHeight * 1.5
                        color: qgcPal.colorBlue
                    }
                }

                Item { Layout.fillWidth: true }

                // Status Indicator
                Rectangle {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.2
                    radius: ScreenTools.defaultFontPixelWidth * 0.3
                    color: reportGenerating ? qgcPal.colorOrange : 
                           (generatedReport ? qgcPal.colorGreen : qgcPal.windowShade)
                    border.color: qgcPal.buttonBorder
                    border.width: 1

                    QGCLabel {
                        anchors.centerIn: parent
                        text: reportGenerating ? "GENERATING..." : 
                              (generatedReport ? "READY" : "IDLE")
                        font.pointSize: ScreenTools.smallFontPointSize
                        font.weight: Font.Bold
                        color: qgcPal.text
                    }
                }

                QGCButton {
                    text: "Generate Report"
                    enabled: !reportGenerating && missionLogger && telemetryLogger
                    onClicked: generateReport()
                }
            }
        }

        // Disaster Metadata Section - Professional Form
        SettingsGroupLayout {
            Layout.fillWidth: true
            heading: "Mission Metadata"
            headingDescription: "Enter disaster response mission information"

            LabelledComboBox {
                Layout.fillWidth: true
                label: "Disaster Type"
                model: ["flood", "earthquake", "landslide", "fire", "cyclone", "tsunami", "other"]
                currentIndex: model.indexOf(disasterType)
                onCurrentTextChanged: disasterType = currentText
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth * 2

                QGCLabel {
                    Layout.fillWidth: true
                    text: "Mission ID"
                }

                QGCTextField {
                    Layout.fillWidth: true
                    text: missionId
                    onTextChanged: missionId = text
                    placeholderText: "Auto-generated if empty"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth * 2

                QGCLabel {
                    Layout.fillWidth: true
                    text: "Command Authority"
                }

                QGCTextField {
                    Layout.fillWidth: true
                    text: commandAuthority
                    onTextChanged: commandAuthority = text
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth * 2

                QGCLabel {
                    Layout.fillWidth: true
                    text: "Response Team"
                }

                QGCTextField {
                    Layout.fillWidth: true
                    text: responseTeam
                    onTextChanged: responseTeam = text
                }
            }
        }

        // Report Sections View - Professional Scrollable
        QGCFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: sectionsColumn.width
            contentHeight: sectionsColumn.height

            ColumnLayout {
                id: sectionsColumn
                width: reportPanel.width - ScreenTools.defaultFontPixelWidth * 2
                spacing: ScreenTools.defaultFontPixelHeight * 0.5

                // Section 1: Mission Overview
                SettingsGroupLayout {
                    Layout.fillWidth: true
                    heading: "1. Disaster Mission Overview"
                    headingDescription: generatedReport && generatedReport.section1_MissionOverview ? "" : "Generate report to view"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentText.height + ScreenTools.defaultFontPixelHeight
                        color: generatedReport && generatedReport.section1_MissionOverview ? qgcPal.windowShade : qgcPal.windowShadeDark
                        radius: ScreenTools.defaultFontPixelWidth * 0.3
                        border.color: generatedReport && generatedReport.section1_MissionOverview ? qgcPal.buttonBorder : qgcPal.buttonBorderDisabled
                        border.width: 1

                        QGCLabel {
                            id: contentText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                            text: generatedReport ? formatMissionOverview(generatedReport.section1_MissionOverview) : "No data available"
                            wrapMode: Text.WordWrap
                            color: generatedReport && generatedReport.section1_MissionOverview ? qgcPal.text : qgcPal.textDisabled
                            font.family: ScreenTools.fixedFontFamily
                        }
                    }
                }

                // Section 2: Area of Operations
                SettingsGroupLayout {
                    Layout.fillWidth: true
                    heading: "2. Area of Operations (AO)"
                    headingDescription: generatedReport && generatedReport.section2_AreaOfOperations ? "" : "Generate report to view"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentText2.height + ScreenTools.defaultFontPixelHeight
                        color: generatedReport && generatedReport.section2_AreaOfOperations ? qgcPal.windowShade : qgcPal.windowShadeDark
                        radius: ScreenTools.defaultFontPixelWidth * 0.3
                        border.color: generatedReport && generatedReport.section2_AreaOfOperations ? qgcPal.buttonBorder : qgcPal.buttonBorderDisabled
                        border.width: 1

                        QGCLabel {
                            id: contentText2
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                            text: generatedReport ? formatAreaOfOperations(generatedReport.section2_AreaOfOperations) : "No data available"
                            wrapMode: Text.WordWrap
                            color: generatedReport && generatedReport.section2_AreaOfOperations ? qgcPal.text : qgcPal.textDisabled
                            font.family: ScreenTools.fixedFontFamily
                        }
                    }
                }

                // Section 3: Flight Log Summary
                SettingsGroupLayout {
                    Layout.fillWidth: true
                    heading: "3. Flight Log Summary"
                    headingDescription: generatedReport && generatedReport.section3_FlightLogSummary ? "" : "Generate report to view"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentText3.height + ScreenTools.defaultFontPixelHeight
                        color: generatedReport && generatedReport.section3_FlightLogSummary ? qgcPal.windowShade : qgcPal.windowShadeDark
                        radius: ScreenTools.defaultFontPixelWidth * 0.3
                        border.color: generatedReport && generatedReport.section3_FlightLogSummary ? qgcPal.buttonBorder : qgcPal.buttonBorderDisabled
                        border.width: 1

                        QGCLabel {
                            id: contentText3
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                            text: generatedReport ? formatFlightLogSummary(generatedReport.section3_FlightLogSummary) : "No data available"
                            wrapMode: Text.WordWrap
                            color: generatedReport && generatedReport.section3_FlightLogSummary ? qgcPal.text : qgcPal.textDisabled
                            font.family: ScreenTools.fixedFontFamily
                        }
                    }
                }

                // Section 4: Emergency Zone Identification
                SettingsGroupLayout {
                    Layout.fillWidth: true
                    heading: "4. Emergency Zone Identification"
                    headingDescription: generatedReport && generatedReport.section4_EmergencyZoneIdentification ? "" : "Generate report to view"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentText4.height + ScreenTools.defaultFontPixelHeight
                        color: generatedReport && generatedReport.section4_EmergencyZoneIdentification ? qgcPal.windowShade : qgcPal.windowShadeDark
                        radius: ScreenTools.defaultFontPixelWidth * 0.3
                        border.color: generatedReport && generatedReport.section4_EmergencyZoneIdentification ? qgcPal.buttonBorder : qgcPal.buttonBorderDisabled
                        border.width: 1

                        QGCLabel {
                            id: contentText4
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                            text: generatedReport ? formatEmergencyZones(generatedReport.section4_EmergencyZoneIdentification) : "No data available"
                            wrapMode: Text.WordWrap
                            color: generatedReport && generatedReport.section4_EmergencyZoneIdentification ? qgcPal.text : qgcPal.textDisabled
                            font.family: ScreenTools.fixedFontFamily
                        }
                    }
                }

                // Section 5: Disaster Impact Analysis
                SettingsGroupLayout {
                    Layout.fillWidth: true
                    heading: "5. Disaster Impact Analysis"
                    headingDescription: generatedReport && generatedReport.section5_DisasterImpactAnalysis ? "" : "Generate report to view"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentText5.height + ScreenTools.defaultFontPixelHeight
                        color: generatedReport && generatedReport.section5_DisasterImpactAnalysis ? qgcPal.windowShade : qgcPal.windowShadeDark
                        radius: ScreenTools.defaultFontPixelWidth * 0.3
                        border.color: generatedReport && generatedReport.section5_DisasterImpactAnalysis ? qgcPal.buttonBorder : qgcPal.buttonBorderDisabled
                        border.width: 1

                        QGCLabel {
                            id: contentText5
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                            text: generatedReport ? formatDisasterImpact(generatedReport.section5_DisasterImpactAnalysis) : "No data available"
                            wrapMode: Text.WordWrap
                            color: generatedReport && generatedReport.section5_DisasterImpactAnalysis ? qgcPal.text : qgcPal.textDisabled
                            font.family: ScreenTools.fixedFontFamily
                        }
                    }
                }

                // Section 6: System & Telemetry Health
                SettingsGroupLayout {
                    Layout.fillWidth: true
                    heading: "6. System & Telemetry Health"
                    headingDescription: generatedReport && generatedReport.section6_SystemTelemetryHealth ? "" : "Generate report to view"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentText6.height + ScreenTools.defaultFontPixelHeight
                        color: generatedReport && generatedReport.section6_SystemTelemetryHealth ? qgcPal.windowShade : qgcPal.windowShadeDark
                        radius: ScreenTools.defaultFontPixelWidth * 0.3
                        border.color: generatedReport && generatedReport.section6_SystemTelemetryHealth ? qgcPal.buttonBorder : qgcPal.buttonBorderDisabled
                        border.width: 1

                        QGCLabel {
                            id: contentText6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                            text: generatedReport ? formatSystemHealth(generatedReport.section6_SystemTelemetryHealth) : "No data available"
                            wrapMode: Text.WordWrap
                            color: generatedReport && generatedReport.section6_SystemTelemetryHealth ? qgcPal.text : qgcPal.textDisabled
                            font.family: ScreenTools.fixedFontFamily
                        }
                    }
                }

                // Section 7: Safety & Risk Assessment
                SettingsGroupLayout {
                    Layout.fillWidth: true
                    heading: "7. Safety & Risk Assessment"
                    headingDescription: generatedReport && generatedReport.section7_SafetyRiskAssessment ? "" : "Generate report to view"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentText7.height + ScreenTools.defaultFontPixelHeight
                        color: generatedReport && generatedReport.section7_SafetyRiskAssessment ? qgcPal.windowShade : qgcPal.windowShadeDark
                        radius: ScreenTools.defaultFontPixelWidth * 0.3
                        border.color: generatedReport && generatedReport.section7_SafetyRiskAssessment ? qgcPal.buttonBorder : qgcPal.buttonBorderDisabled
                        border.width: 1

                        QGCLabel {
                            id: contentText7
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                            text: generatedReport ? formatSafetyRisk(generatedReport.section7_SafetyRiskAssessment) : "No data available"
                            wrapMode: Text.WordWrap
                            color: generatedReport && generatedReport.section7_SafetyRiskAssessment ? qgcPal.text : qgcPal.textDisabled
                            font.family: ScreenTools.fixedFontFamily
                        }
                    }
                }

                // Section 8: Mission Outcome
                SettingsGroupLayout {
                    Layout.fillWidth: true
                    heading: "8. Mission Outcome & Response Support"
                    headingDescription: generatedReport && generatedReport.section8_MissionOutcome ? "" : "Generate report to view"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentText8.height + ScreenTools.defaultFontPixelHeight
                        color: generatedReport && generatedReport.section8_MissionOutcome ? qgcPal.windowShade : qgcPal.windowShadeDark
                        radius: ScreenTools.defaultFontPixelWidth * 0.3
                        border.color: generatedReport && generatedReport.section8_MissionOutcome ? qgcPal.buttonBorder : qgcPal.buttonBorderDisabled
                        border.width: 1

                        QGCLabel {
                            id: contentText8
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                            text: generatedReport ? formatMissionOutcome(generatedReport.section8_MissionOutcome) : "No data available"
                            wrapMode: Text.WordWrap
                            color: generatedReport && generatedReport.section8_MissionOutcome ? qgcPal.text : qgcPal.textDisabled
                            font.family: ScreenTools.fixedFontFamily
                        }
                    }
                }

                // Export Options - Professional Button Group
                SettingsGroupLayout {
                    Layout.fillWidth: true
                    heading: "9. Export Options"
                    headingDescription: "Export report in various formats for emergency authorities"

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: ScreenTools.defaultFontPixelWidth
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.5

                        QGCButton {
                            Layout.fillWidth: true
                            text: "Export JSON"
                            enabled: generatedReport !== null
                            onClicked: exportReport("json")
                        }

                        QGCButton {
                            Layout.fillWidth: true
                            text: "Export KML"
                            enabled: generatedReport !== null
                            onClicked: exportReport("kml")
                        }

                        QGCButton {
                            Layout.fillWidth: true
                            text: "Export CSV"
                            enabled: generatedReport !== null
                            onClicked: exportReport("csv")
                        }

                        QGCButton {
                            Layout.fillWidth: true
                            text: "Export GeoJSON"
                            enabled: generatedReport !== null
                            onClicked: exportReport("geojson")
                        }

                        QGCButton {
                            Layout.fillWidth: true
                            text: "Export Frame Metadata"
                            enabled: generatedReport !== null && reportGenerator && reportGenerator.frameCapture
                            onClicked: exportFrameMetadata()
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    function exportFrameMetadata() {
        if (!reportGenerator || !reportGenerator.frameCapture) return

        exportFormat = "json"
        var metadata = reportGenerator.frameCapture.exportFrameMetadataJSON()
        
        saveDialog.nameFilters = ["*.json"]
        saveDialog.open()
        
        // Store metadata for saving
        _frameMetadataToSave = metadata
    }

    property string _frameMetadataToSave: ""

    FileDialog {
        id: saveDialog
        fileMode: FileDialog.SaveFile
        onAccepted: {
            var filePath = selectedFile.toString().replace("file://", "")
            var content = ""
            
            switch (exportFormat) {
                case "json":
                    content = reportGenerator.exportJSON()
                    break
                case "kml":
                    content = reportGenerator.exportKML()
                    break
                case "csv":
                    content = reportGenerator.exportCSV()
                    break
                case "geojson":
                    content = reportGenerator.exportGeoJSON()
                    break
            }
            
            // Write file (would need C++ helper for actual file writing)
            console.log("Would save to:", filePath)
            console.log("Content length:", content.length)
        }
    }

    property string exportFormat: "json"

    function generateReport() {
        if (!reportGenerator || !missionLogger || !telemetryLogger) {
            console.log("ASTHRA: Cannot generate report - missing components")
            return
        }

        reportGenerating = true

        // Set disaster metadata
        reportGenerator.setDisasterMetadata(disasterType, missionId || "", commandAuthority, responseTeam)

        // Generate report
        generatedReport = reportGenerator.generateFullReport()
        
        reportGenerating = false
    }

    function exportReport(format) {
        if (!reportGenerator || !generatedReport) return

        exportFormat = format
        var extension = format === "json" ? "json" : 
                       format === "kml" ? "kml" :
                       format === "csv" ? "csv" : "geojson"
        
        saveDialog.nameFilters = ["*." + extension]
        saveDialog.open()
    }

    // Formatting functions for display
    function formatMissionOverview(overview) {
        if (!overview) return "No data"
        return "Disaster Type: " + overview.disasterType + "\n" +
               "Mission ID: " + overview.missionId + "\n" +
               "Start Time (UTC): " + (overview.dateTimeUTC.start || "N/A") + "\n" +
               "End Time (UTC): " + (overview.dateTimeUTC.end || "N/A") + "\n" +
               "UAV Platform: " + overview.uavPlatform.type + " (ID: " + overview.uavPlatform.id + ")\n" +
               "Payload: " + overview.payload.join(", ") + "\n" +
               "Operating System: " + overview.operatingSystem + "\n" +
               "Command Authority: " + overview.commandAuthority + "\n" +
               "Response Team: " + overview.responseTeam
    }

    function formatAreaOfOperations(ao) {
        if (!ao) return "No data"
        return "Coverage Area: " + (ao.coverageArea ? ao.coverageArea.toFixed(2) + " km²" : "N/A") + "\n" +
               "Boundaries: " + (ao.disasterZoneBoundaries ? 
                   "Lat " + ao.disasterZoneBoundaries.minLatitude.toFixed(6) + " to " + ao.disasterZoneBoundaries.maxLatitude.toFixed(6) + "\n" +
                   "Lon " + ao.disasterZoneBoundaries.minLongitude.toFixed(6) + " to " + ao.disasterZoneBoundaries.maxLongitude.toFixed(6) : "N/A") + "\n" +
               "Waypoints: " + (ao.waypoints ? ao.waypoints.length : 0)
    }

    function formatFlightLogSummary(summary) {
        if (!summary) return "No data"
        var result = "Launch Location: " + (summary.launchLocation ? 
            summary.launchLocation.latitude.toFixed(6) + ", " + summary.launchLocation.longitude.toFixed(6) : "N/A") + "\n" +
               "Recovery Location: " + (summary.recoveryLocation ? 
            summary.recoveryLocation.latitude.toFixed(6) + ", " + summary.recoveryLocation.longitude.toFixed(6) : "N/A") + "\n" +
               "Flight Duration: " + (summary.flightDuration ? summary.flightDuration.formatted : "N/A") + "\n" +
               "Distance Covered: " + (summary.distanceCovered ? summary.distanceCovered.formatted : "N/A") + "\n" +
               "Altitude: " + (summary.altitudeProfile ? 
            summary.altitudeProfile.min.toFixed(1) + " - " + summary.altitudeProfile.max.toFixed(1) + " m (avg: " + summary.altitudeProfile.average.toFixed(1) + " m)" : "N/A") + "\n" +
               "Speed: " + (summary.speedProfile ? 
            summary.speedProfile.min.toFixed(1) + " - " + summary.speedProfile.max.toFixed(1) + " m/s (avg: " + summary.speedProfile.average.toFixed(1) + " m/s)" : "N/A")
        
        // Add captured frames information
        if (summary.capturedFrames) {
            result += "\n\nCaptured Frames:\n"
            result += "Total Frames: " + summary.capturedFrames.totalFrames + "\n"
            result += "Descent Frames: " + summary.capturedFrames.descentFrames + "\n"
            result += "OFFBOARD Frames: " + summary.capturedFrames.offboardFrames
        }
        
        return result
    }

    function formatEmergencyZones(zones) {
        if (!zones || !zones.zones) return "No emergency zones detected"
        return "Total Zones: " + zones.totalZones + "\n" +
               "Critical: " + zones.criticalZones + ", High: " + zones.highZones + 
               ", Medium: " + zones.mediumZones + ", Low: " + zones.lowZones + "\n\n" +
               zones.zones.map(function(z) {
                   return z.zoneId + ": " + z.severity + " - " + z.type + " at " + 
                          z.coordinates.latitude.toFixed(6) + ", " + z.coordinates.longitude.toFixed(6) + 
                          " (radius: " + z.radius + " m)"
               }).join("\n")
    }

    function formatDisasterImpact(impact) {
        if (!impact) return "No data"
        return "Structural Damage Indicators: " + (impact.structuralDamage.indicators ? impact.structuralDamage.indicators.length : 0) + "\n" +
               "Flood Affected Areas: " + (impact.floodData.affectedAreas ? impact.floodData.affectedAreas.length : 0) + "\n" +
               "Fire Affected Areas: " + (impact.fireData.affectedAreas ? impact.fireData.affectedAreas.length : 0) + "\n" +
               "Blocked Routes: " + (impact.blockedRoutes.locations ? impact.blockedRoutes.locations.length : 0) + "\n" +
               "Survivor Detections: " + (impact.survivorPresence.detections ? impact.survivorPresence.detections.length : 0)
    }

    function formatSystemHealth(health) {
        if (!health) return "No data"
        return "GPS Signal Integrity: " + (health.gps ? health.gps.signalIntegrity : "N/A") + "\n" +
               "Average Satellites: " + (health.gps ? health.gps.averageSatellites.toFixed(1) : "N/A") + "\n" +
               "Battery Health: " + (health.battery ? health.battery.healthStatus : "N/A") + "\n" +
               "Link Stability: " + (health.communication ? health.communication.stability : "N/A") + "\n" +
               "Failsafe Events: " + (health.failsafeEvents ? health.failsafeEvents.length : 0)
    }

    function formatSafetyRisk(risk) {
        if (!risk) return "No data"
        return "Overall Risk Level: " + (risk.overallRiskLevel || "Unknown") + "\n" +
               "Altitude Violations: " + (risk.uavOperationalRisks.altitudeViolations ? risk.uavOperationalRisks.altitudeViolations.count : 0) + "\n" +
               "Speed Violations: " + (risk.uavOperationalRisks.speedViolations ? risk.uavOperationalRisks.speedViolations.count : 0) + "\n" +
               "Battery Critical Zones: " + (risk.uavOperationalRisks.batteryCriticalZones ? risk.uavOperationalRisks.batteryCriticalZones.count : 0) + "\n" +
               "Near-Miss Events: " + (risk.airspaceConflicts.nearMissEvents ? risk.airspaceConflicts.nearMissEvents.length : 0)
    }

    function formatMissionOutcome(outcome) {
        if (!outcome) return "No data"
        return "Mission Success: " + (outcome.missionSuccess || "Unknown") + "\n" +
               "Coverage Completeness: " + (outcome.coverageCompleteness ? outcome.coverageCompleteness.assessment + " (" + outcome.coverageCompleteness.percentage.toFixed(1) + "%)" : "N/A") + "\n" +
               "Priority Zones: " + (outcome.priorityZones ? outcome.priorityZones.length : 0) + "\n" +
               "Recommendations: " + (outcome.recommendations ? outcome.recommendations.length : 0) + " items"
    }

}

