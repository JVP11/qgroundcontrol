/****************************************************************************
 *
 * ASTHRA - Professional Disaster Management Report Panel
 * Industrial-grade UI for viewing and generating disaster response reports
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

    color: qgcPal.window

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth

        // Professional Header with ASTHRA Branding
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: headerLayout.height + ScreenTools.defaultFontPixelHeight * 1.5
            color: qgcPal.windowShadeDark
            radius: ScreenTools.defaultFontPixelWidth * 0.5
            border.color: qgcPal.buttonBorder
            border.width: 1

            RowLayout {
                id: headerLayout
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
                        text: "ASTHRA"
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.3
                        font.weight: Font.Bold
                        font.letterSpacing: 2
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
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
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

        // Mission Metadata Section - Professional Form
        SettingsGroupLayout {
            Layout.fillWidth: true
            heading: "Mission Metadata"
            headingDescription: "Enter disaster response mission information"

            LabelledFactComboBox {
                Layout.fillWidth: true
                label: "Disaster Type"
                model: ["flood", "earthquake", "landslide", "fire", "cyclone", "tsunami", "other"]
                currentIndex: model.indexOf(disasterType)
                onCurrentTextChanged: disasterType = currentText
            }

            LabelledFactTextField {
                Layout.fillWidth: true
                label: "Mission ID"
                text: missionId
                onTextChanged: missionId = text
                placeholderText: "Auto-generated if empty"
            }

            LabelledFactTextField {
                Layout.fillWidth: true
                label: "Command Authority"
                text: commandAuthority
                onTextChanged: commandAuthority = text
            }

            LabelledFactTextField {
                Layout.fillWidth: true
                label: "Response Team"
                text: responseTeam
                onTextChanged: responseTeam = text
            }
        }

        // Report Sections - Professional Scrollable View
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
                ReportSectionCard {
                    sectionNumber: "1"
                    sectionTitle: "Disaster Mission Overview"
                    sectionContent: generatedReport ? formatMissionOverview(generatedReport.section1_MissionOverview) :
                                      "Generate report to view mission overview"
                    hasData: generatedReport && generatedReport.section1_MissionOverview
                }

                // Section 2: Area of Operations
                ReportSectionCard {
                    sectionNumber: "2"
                    sectionTitle: "Area of Operations (AO)"
                    sectionContent: generatedReport ? formatAreaOfOperations(generatedReport.section2_AreaOfOperations) :
                                      "Generate report to view area of operations"
                    hasData: generatedReport && generatedReport.section2_AreaOfOperations
                }

                // Section 3: Flight Log Summary
                ReportSectionCard {
                    sectionNumber: "3"
                    sectionTitle: "Flight Log Summary"
                    sectionContent: generatedReport ? formatFlightLogSummary(generatedReport.section3_FlightLogSummary) :
                                      "Generate report to view flight log"
                    hasData: generatedReport && generatedReport.section3_FlightLogSummary
                }

                // Section 4: Emergency Zone Identification
                ReportSectionCard {
                    sectionNumber: "4"
                    sectionTitle: "Emergency Zone Identification"
                    sectionContent: generatedReport ? formatEmergencyZones(generatedReport.section4_EmergencyZoneIdentification) :
                                      "Generate report to view emergency zones"
                    hasData: generatedReport && generatedReport.section4_EmergencyZoneIdentification
                }

                // Section 5: Disaster Impact Analysis
                ReportSectionCard {
                    sectionNumber: "5"
                    sectionTitle: "Disaster Impact Analysis"
                    sectionContent: generatedReport ? formatDisasterImpact(generatedReport.section5_DisasterImpactAnalysis) :
                                      "Generate report to view impact analysis"
                    hasData: generatedReport && generatedReport.section5_DisasterImpactAnalysis
                }

                // Section 6: System & Telemetry Health
                ReportSectionCard {
                    sectionNumber: "6"
                    sectionTitle: "System & Telemetry Health"
                    sectionContent: generatedReport ? formatSystemHealth(generatedReport.section6_SystemTelemetryHealth) :
                                      "Generate report to view system health"
                    hasData: generatedReport && generatedReport.section6_SystemTelemetryHealth
                }

                // Section 7: Safety & Risk Assessment
                ReportSectionCard {
                    sectionNumber: "7"
                    sectionTitle: "Safety & Risk Assessment"
                    sectionContent: generatedReport ? formatSafetyRisk(generatedReport.section7_SafetyRiskAssessment) :
                                      "Generate report to view risk assessment"
                    hasData: generatedReport && generatedReport.section7_SafetyRiskAssessment
                }

                // Section 8: Mission Outcome
                ReportSectionCard {
                    sectionNumber: "8"
                    sectionTitle: "Mission Outcome & Response Support"
                    sectionContent: generatedReport ? formatMissionOutcome(generatedReport.section8_MissionOutcome) :
                                      "Generate report to view mission outcome"
                    hasData: generatedReport && generatedReport.section8_MissionOutcome
                }

                // Export Options - Professional Button Group
                SettingsGroupLayout {
                    Layout.fillWidth: true
                    heading: "Export Options"
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

    // Professional Report Section Card Component
    component ReportSectionCard: SettingsGroupLayout {
        property string sectionNumber: ""
        property string sectionTitle: ""
        property string sectionContent: ""
        property bool hasData: false

        heading: sectionNumber + ". " + sectionTitle
        headingDescription: hasData ? "" : "No data available - generate report to view"

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: contentText.height + ScreenTools.defaultFontPixelHeight
            color: hasData ? qgcPal.windowShade : qgcPal.windowShadeDark
            radius: ScreenTools.defaultFontPixelWidth * 0.3
            border.color: hasData ? qgcPal.buttonBorder : qgcPal.buttonBorderDisabled
            border.width: 1

            QGCLabel {
                id: contentText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                text: sectionContent
                wrapMode: Text.WordWrap
                color: hasData ? qgcPal.text : qgcPal.textDisabled
                font.family: ScreenTools.fixedFontFamily
            }
        }
    }

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

            console.log("ASTHRA: Would save to:", filePath)
            console.log("ASTHRA: Content length:", content.length)
        }
    }

    property string exportFormat: "json"
    property string _frameMetadataToSave: ""

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

    function exportFrameMetadata() {
        if (!reportGenerator || !reportGenerator.frameCapture) return

        exportFormat = "json"
        var metadata = reportGenerator.frameCapture.exportFrameMetadataJSON()

        saveDialog.nameFilters = ["*.json"]
        saveDialog.open()

        _frameMetadataToSave = metadata
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



