/****************************************************************************
 *
 * ASTHRA - Rescue Report Panel
 * Displays OFFBOARD events and generates rescue reports
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Rescue Report Panel - Displays OFFBOARD events and generates reports
Rectangle {
    id: rescuePanel
    width: ScreenTools.defaultFontPixelWidth * 50
    height: ScreenTools.defaultFontPixelHeight * 40
    color: qgcPal.windowShade
    border.width: 2
    border.color: qgcPal.buttonBorder
    
    QGCPalette { id: qgcPal }
    
    property var missionLogger: null
    property var offboardMonitor: null
    
    function refreshReport() {
        console.log("ASTHRA: Refreshing rescue report")
        console.log("ASTHRA: Mission logger:", missionLogger)
        if (missionLogger) {
            console.log("ASTHRA: Mission logger active vehicle:", missionLogger.activeVehicle)
            console.log("ASTHRA: Mission events count:", missionLogger.missionEvents ? missionLogger.missionEvents.length : 0)
        }
        if (eventList) {
            // Force refresh by clearing and resetting model
            eventList.model = null
            Qt.callLater(function() {
                eventList.model = eventList.getOffboardEvents()
                console.log("ASTHRA: Event list model refreshed, count:", eventList.count)
            })
        }
    }
    
    Component.onCompleted: {
        console.log("ASTHRA: Rescue Report Panel loaded")
        console.log("ASTHRA: Mission logger:", missionLogger)
        console.log("ASTHRA: Offboard monitor:", offboardMonitor)
        if (missionLogger) {
            console.log("ASTHRA: Mission logger connected")
            console.log("ASTHRA: Mission logger events:", missionLogger.missionEvents ? missionLogger.missionEvents.length : 0)
        }
        // Delay refresh to ensure everything is initialized
        Qt.callLater(refreshReport)
    }
    
    onMissionLoggerChanged: {
        console.log("ASTHRA: Mission logger changed")
        Qt.callLater(refreshReport)
    }
    
    onVisibleChanged: {
        if (visible) {
            console.log("ASTHRA: Rescue report panel made visible")
            Qt.callLater(refreshReport)
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        
        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3
            color: qgcPal.windowShadeDark
            border.width: 1
            border.color: qgcPal.buttonBorder
            
            QGCLabel {
                anchors.centerIn: parent
                text: "RESCUE REPORT - OFFBOARD EVENTS"
                font.family: ScreenTools.fixedFontFamily
                font.weight: Font.Bold
                font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                color: qgcPal.text
            }
        }
        
        // Event List
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            // Show message when no events
            QGCLabel {
                id: noEventsLabel
                anchors.centerIn: parent
                visible: !eventList || eventList.count === 0
                text: missionLogger ? 
                      "NO OFFBOARD EVENTS RECORDED\n\n" +
                      "OFFBOARD exit events will appear here when:\n" +
                      "• Vehicle enters OFFBOARD mode\n" +
                      "• Vehicle exits OFFBOARD mode (link loss, failsafe, etc.)\n\n" +
                      "Events include coordinates, distance from base,\n" +
                      "direction, and Google Maps route." :
                      "MISSION LOGGER NOT CONNECTED\n\n" +
                      "Please ensure a vehicle is connected."
                font.family: ScreenTools.fixedFontFamily
                font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                color: qgcPal.text
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width * 0.8
            }
            
            ListView {
                id: eventList
                width: parent.width
                model: getOffboardEvents()
                visible: count > 0
                
                function getOffboardEvents() {
                    if (!missionLogger) {
                        console.warn("ASTHRA: Mission logger not available")
                        return []
                    }
                    try {
                        var events = missionLogger.getOffboardEvents()
                        console.log("ASTHRA: Found", events ? events.length : 0, "OFFBOARD events")
                        return events || []
                    } catch (e) {
                        console.error("ASTHRA: Error getting events:", e)
                        return []
                    }
                }
                
                Component.onCompleted: {
                    console.log("ASTHRA: Event list component completed")
                    // Refresh when component is loaded
                    if (missionLogger) {
                        model = getOffboardEvents()
                    }
                }
                
                delegate: Rectangle {
                    width: eventList.width
                    height: ScreenTools.defaultFontPixelHeight * 8  // Taller to fit Google Maps button
                    color: index % 2 === 0 ? qgcPal.windowShadeDark : qgcPal.windowShade
                    border.width: 1
                    border.color: qgcPal.buttonBorder
                    visible: true
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                        spacing: ScreenTools.defaultFontPixelWidth * 0.3
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            QGCLabel {
                                text: "EXIT #" + (index + 1)
                                font.family: ScreenTools.fixedFontFamily
                                font.weight: Font.Bold
                                color: getEventColor()
                                
                                function getEventColor() {
                                    var reason = modelData.data ? modelData.data.reason : "UNKNOWN"
                                    if (reason === "LINK_LOSS" || reason === "FAILSAFE") {
                                        return qgcPal.colorRed
                                    }
                                    return qgcPal.colorYellow
                                }
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            QGCLabel {
                                text: Qt.formatDateTime(modelData.timestamp, "HH:mm:ss")
                                font.family: ScreenTools.fixedFontFamily
                                color: qgcPal.text
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            QGCLabel {
                                text: "LAT: " + (modelData.data ? modelData.data.latitude.toFixed(6) : "N/A")
                                font.family: ScreenTools.fixedFontFamily
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: qgcPal.text
                            }
                            
                            QGCLabel {
                                text: "LON: " + (modelData.data ? modelData.data.longitude.toFixed(6) : "N/A")
                                font.family: ScreenTools.fixedFontFamily
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: qgcPal.text
                            }
                            
                            QGCLabel {
                                text: "ALT: " + (modelData.data ? modelData.data.altitude.toFixed(1) : "N/A") + " m"
                                font.family: ScreenTools.fixedFontFamily
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: qgcPal.text
                            }
                        }
                        
                        // Google Maps Link
                        RowLayout {
                            Layout.fillWidth: true
                            
                            QGCLabel {
                                text: "MAP:"
                                font.family: ScreenTools.fixedFontFamily
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: qgcPal.text
                            }
                            
                            QGCButton {
                                text: "OPEN IN GOOGLE MAPS"
                                font.family: ScreenTools.fixedFontFamily
                                font.pointSize: ScreenTools.smallFontPointSize * 0.9
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                                backgroundColor: qgcPal.colorBlue
                                visible: modelData.data && modelData.data.latitude && modelData.data.longitude && 
                                         modelData.data.gcsLatitude && modelData.data.gcsLongitude
                                onClicked: {
                                    var gcsLat = modelData.data.gcsLatitude
                                    var gcsLon = modelData.data.gcsLongitude
                                    var exitLat = modelData.data.latitude
                                    var exitLon = modelData.data.longitude
                                    var url = "https://www.google.com/maps/dir/" + gcsLat + "," + gcsLon + "/" + exitLat + "," + exitLon
                                    Qt.openUrlExternally(url)
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            QGCLabel {
                                text: "REASON: " + (modelData.data ? modelData.data.reason : "UNKNOWN")
                                font.family: ScreenTools.fixedFontFamily
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: qgcPal.text
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            QGCLabel {
                                text: modelData.data && modelData.data.distanceText ? 
                                      "DIST: " + modelData.data.distanceText : "DIST: N/A"
                                font.family: ScreenTools.fixedFontFamily
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: qgcPal.colorBlue
                            }
                            
                            QGCLabel {
                                text: modelData.data && modelData.data.directionText ? 
                                      "DIR: " + modelData.data.directionText : "DIR: N/A"
                                font.family: ScreenTools.fixedFontFamily
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: qgcPal.colorBlue
                            }
                        }
                    }
                }
            }
        }
        
        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth
            
            QGCButton {
                text: "DOWNLOAD FLIGHT LOG"
                Layout.fillWidth: true
                backgroundColor: qgcPal.colorGreen
                font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                enabled: missionLogger && missionLogger.activeVehicle
                onClicked: downloadFlightLog()
            }
            
            QGCButton {
                text: "EXPORT LOG"
                Layout.fillWidth: true
                backgroundColor: qgcPal.colorBlue
                font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                onClicked: exportReport("log")
            }
            
            QGCButton {
                text: "EXPORT JSON"
                Layout.fillWidth: true
                font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                onClicked: exportReport("json")
            }
            
            QGCButton {
                text: "EXPORT CSV"
                Layout.fillWidth: true
                font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                onClicked: exportReport("csv")
            }
            
            QGCButton {
                text: "CLOSE"
                Layout.fillWidth: true
                font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                onClicked: rescuePanel.visible = false
            }
        }
    }
    
    FileDialog {
        id: saveFileDialog
        fileMode: FileDialog.SaveFile
        onAccepted: {
            var fileUrl = selectedFile
            var filePath = ""
            
            // Convert URL to local file path
            if (typeof QGroundControl !== 'undefined' && QGroundControl.fileDialogController) {
                filePath = QGroundControl.fileDialogController.urlToLocalFile(fileUrl)
            } else {
                filePath = fileUrl.toString().replace("file://", "")
            }
            
            var content = saveFileDialog.contentToSave
            if (!content) {
                console.error("ASTHRA: No content to save")
                return
            }
            
            console.log("ASTHRA: Saving report to", filePath)
            console.log("ASTHRA: Report content length", content.length)
            
            // Write file using QGroundControl's file dialog controller
            var success = false
            if (typeof QGroundControl !== 'undefined' && QGroundControl.fileDialogController) {
                success = QGroundControl.fileDialogController.writeTextFile(filePath, content)
            }
            
            if (success) {
                console.log("ASTHRA: Report saved successfully to", filePath)
                // Show success message
                if (typeof mainWindow !== 'undefined' && mainWindow.showMessageDialog) {
                    mainWindow.showMessageDialog("Report Saved", 
                        "Report saved successfully to:\n" + filePath,
                        Dialog.Ok)
                }
            } else {
                console.error("ASTHRA: Failed to save report")
                // Fallback: Copy to clipboard
                if (typeof Qt !== 'undefined' && Qt.application && Qt.application.clipboard) {
                    Qt.application.clipboard.text = content
                    console.log("ASTHRA: Report copied to clipboard as backup")
                    if (typeof mainWindow !== 'undefined' && mainWindow.showMessageDialog) {
                        mainWindow.showMessageDialog("Report Copied", 
                            "File writing failed. Report content copied to clipboard.\n" +
                            "Please paste into a text file and save manually.",
                            Dialog.Ok)
                    }
                }
            }
        }
        
        property string contentToSave: ""
    }
    
    function saveReportToFile(filePath, content) {
        // Trigger file dialog with content
        saveFileDialog.contentToSave = content
        saveFileDialog.currentFile = filePath
        saveFileDialog.open()
        return true
    }
    
    function exportReport(format) {
        if (!missionLogger) {
            console.error("ASTHRA: Mission logger not available")
            return
        }
        
        var extension = ".txt"
        var nameFilter = "Text files (*.txt)"
        var content = null
        
        if (format === "log") {
            extension = ".log"
            nameFilter = "Log files (*.log);;Text files (*.txt)"
            content = missionLogger.exportRescueReportLog()
        } else if (format === "json") {
            extension = ".json"
            nameFilter = "JSON files (*.json)"
            content = missionLogger.exportRescueReportJSON()
        } else if (format === "csv") {
            extension = ".csv"
            nameFilter = "CSV files (*.csv)"
            content = missionLogger.exportRescueReportCSV()
        }
        
        if (!content) {
            console.error("ASTHRA: Failed to generate report content")
            return
        }
        
        var defaultName = "ASTHRA_Rescue_Report_" + Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss") + extension
        
        // Set up file dialog
        saveFileDialog.nameFilters = [nameFilter]
        saveFileDialog.currentFile = defaultName
        saveFileDialog.contentToSave = content
        saveFileDialog.open()
    }
    
    function downloadFlightLog() {
        if (!missionLogger || !missionLogger.activeVehicle) {
            console.error("ASTHRA: No active vehicle for log download")
            return
        }
        
        var vehicle = missionLogger.activeVehicle
        if (!vehicle) {
            console.error("ASTHRA: No active vehicle")
            return
        }
        
        // Use QGroundControl's log download system
        // The log files are typically stored in ~/.local/share/QGroundControl/Logs/
        // or can be accessed through the Analyze view
        console.log("ASTHRA: Flight log download requested for vehicle", vehicle.id)
        
        // Open the Analyze view which has log download functionality
        if (typeof mainWindow !== 'undefined' && mainWindow.showAnalyzeTool) {
            mainWindow.showAnalyzeTool()
            console.log("ASTHRA: Opened Analyze view - use Log Download section to download flight logs")
        } else {
            console.log("ASTHRA: Flight logs are automatically saved during flight")
            console.log("ASTHRA: Check ~/.local/share/QGroundControl/Logs/ for .ulg files")
        }
        
        // Show message to user
        if (typeof mainWindow !== 'undefined' && mainWindow.showMessage) {
            mainWindow.showMessage("Flight Log Download", 
                "Flight logs (.ulg/.bin) are automatically saved during flight.\n" +
                "Check the Analyze view or ~/.local/share/QGroundControl/Logs/ directory.\n" +
                "For connected vehicles, use the Log Download section in Analyze view.")
        }
    }
}

