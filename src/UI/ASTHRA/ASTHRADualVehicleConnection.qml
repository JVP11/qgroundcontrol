/****************************************************************************
 *
 * ASTHRA - Simplified Dual Vehicle Connection Wizard
 * Easy one-click connection for dual-drone missions
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Dual Vehicle Connection Panel - Simplified connection for dual-drone missions
Rectangle {
    id: dualVehicleConnection
    color: qgcPal.window
    anchors.fill: parent

    QGCPalette { id: qgcPal }

    // Access to mainWindow
    property var mainWindow: null

    Component.onCompleted: {
        console.log("ASTHRA: Dual Vehicle Connection panel loaded")
        // Try to get mainWindow reference
        // In QML, we can access it through the parent hierarchy
        var parentItem = parent
        while (parentItem) {
            if (parentItem.objectName === "mainWindow" || typeof parentItem.showSettingsTool === 'function') {
                mainWindow = parentItem
                break
            }
            parentItem = parentItem.parent
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() {
            console.log("ASTHRA: Active vehicle changed")
        }
    }
    Connections {
        target: QGroundControl.multiVehicleManager.vehicles
        function onCountChanged() {
            console.log("ASTHRA: Vehicles changed, count:", QGroundControl.multiVehicleManager.vehicles.count)
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: scrollView.width
            spacing: ScreenTools.defaultFontPixelHeight

            // Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.5
                color: qgcPal.windowShadeDark
                border.width: 1
                border.color: qgcPal.buttonBorder

                QGCLabel {
                    anchors.centerIn: parent
                    text: "ASTHRA - VEHICLE CONNECTION"
                    font.family: ScreenTools.fixedFontFamily
                    font.weight: Font.Bold
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                    color: qgcPal.text
                }
            }

            // Connection Status
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 10
                color: qgcPal.windowShade
                border.width: 1
                border.color: qgcPal.buttonBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth
                    spacing: ScreenTools.defaultFontPixelHeight * 0.5

                    QGCLabel {
                        width: parent.width
                        text: "CONNECTION STATUS"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        color: qgcPal.text
                    }

                    QGCLabel {
                        width: parent.width
                        text: "Connected Vehicles: " + QGroundControl.multiVehicleManager.vehicles.count.toString()
                        font.family: ScreenTools.fixedFontFamily
                        color: qgcPal.text
                        wrapMode: Text.WordWrap
                    }

                    QGCLabel {
                        width: parent.width
                        text: "Active Vehicle: " + (QGroundControl.multiVehicleManager.activeVehicle ?
                               "Vehicle " + QGroundControl.multiVehicleManager.activeVehicle.fleetSlot +
                               "  SYS " + QGroundControl.multiVehicleManager.activeVehicle.id : "None")
                        font.family: ScreenTools.fixedFontFamily
                        color: qgcPal.text
                        wrapMode: Text.WordWrap
                    }

                    // Vehicle List
                    Repeater {
                        model: QGroundControl.multiVehicleManager.vehicles

                        Row {
                            width: parent.width
                            spacing: ScreenTools.defaultFontPixelWidth

                            QGCLabel {
                                width: parent.width - statusIndicator.width - setActiveButton.width - parent.spacing * 2
                                text: "Vehicle " + object.fleetSlot + "  SYS " + object.id + " (" + object.vehicleTypeString + ")"
                                font.family: ScreenTools.fixedFontFamily
                                color: qgcPal.text
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                id: statusIndicator
                                width: ScreenTools.defaultFontPixelWidth * 2
                                height: ScreenTools.defaultFontPixelWidth * 2
                                radius: width / 2
                                color: object === QGroundControl.multiVehicleManager.activeVehicle ?
                                       qgcPal.colorGreen : qgcPal.colorGrey
                            }

                            QGCButton {
                                id: setActiveButton
                                text: "Set Active"
                                enabled: object !== QGroundControl.multiVehicleManager.activeVehicle
                                onClicked: {
                                    QGroundControl.multiVehicleManager.activeVehicle = object
                                }
                            }
                        }
                    }
                }
            }

            // Quick Connect - One-Click Serial Connection
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 12
                color: qgcPal.windowShade
                border.width: 1
                border.color: qgcPal.buttonBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth
                    spacing: ScreenTools.defaultFontPixelHeight * 0.5

                    QGCLabel {
                        width: parent.width
                        text: "QUICK CONNECT - ONE CLICK"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        color: qgcPal.text
                    }

                    QGCLabel {
                        width: parent.width
                        text: "Available Serial Ports:"
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: qgcPal.text
                    }

                    // List available ports
                    Repeater {
                        model: getAvailablePorts()

                        QGCButton {
                            width: parent.width
                            text: "Connect " + modelData.port + " (Vehicle " + (modelData.index + 1) + ")"
                            enabled: !modelData.connected
                            onClicked: {
                                connectToPort(modelData.port, modelData.index + 1)
                            }
                        }
                    }

                    QGCLabel {
                        width: parent.width
                        text: "OR"
                        horizontalAlignment: Text.AlignHCenter
                        font.family: ScreenTools.fixedFontFamily
                        color: qgcPal.textDisabled
                    }

                    QGCButton {
                        width: parent.width
                        text: "Connect all USB radios"
                        primary: true
                        onClicked: {
                            var n = 0
                            if (QGroundControl.linkManager && typeof QGroundControl.linkManager.connectAvailableUsbRadios === "function")
                                n = QGroundControl.linkManager.connectAvailableUsbRadios()
                            console.log("ASTHRA: opened USB radios:", n)
                        }
                    }

                    QGCButton {
                        width: parent.width
                        text: "Enable Auto-Connect (UDP)"
                        onClicked: {
                            var autoConnectSettings = QGroundControl.settingsManager.autoConnectSettings
                            if (autoConnectSettings && autoConnectSettings.autoConnectUDP) {
                                autoConnectSettings.autoConnectUDP.value = true
                            }
                        }
                    }

                    QGCLabel {
                        width: parent.width
                        text: "UDP: vehicle N uses port 14550 + (N-1). Example: 14550, 14551, 14552, …"
                        wrapMode: Text.WordWrap
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: qgcPal.textDisabled
                    }
                }
            }

            // System ID Check
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 7
                color: qgcPal.windowShade
                border.width: 1
                border.color: qgcPal.buttonBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth
                    spacing: ScreenTools.defaultFontPixelHeight * 0.5

                    QGCLabel {
                        width: parent.width
                        text: "SYSTEM ID VERIFICATION"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        color: qgcPal.text
                    }

                    QGCLabel {
                        width: parent.width
                        text: "Status: " + checkSystemIDs()
                        font.family: ScreenTools.fixedFontFamily
                        color: qgcPal.text
                        wrapMode: Text.WordWrap
                    }

                    QGCLabel {
                        width: parent.width
                        text: "Each vehicle must have a unique system ID:\n" +
                              "• PX4: Set MAV_SYS_ID parameter\n" +
                              "• ArduPilot: Set SYSID_THISMAV parameter"
                        wrapMode: Text.WordWrap
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: qgcPal.textDisabled
                    }
                }
            }

            // Instructions
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 7
                color: qgcPal.windowShade
                border.width: 1
                border.color: qgcPal.buttonBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth
                    spacing: ScreenTools.defaultFontPixelHeight * 0.5

                    QGCLabel {
                        width: parent.width
                        text: "CONNECTION INSTRUCTIONS"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        color: qgcPal.text
                    }

                    QGCLabel {
                        width: parent.width
                        text: "1. USB: each radio is V1, V2, … even if both use SYS 2\n" +
                              "2. Shared UDP: give each drone a unique SYSID, port 14550 + (N-1)\n" +
                              "3. Open SWARM to set % split, survey, and upload per radio\n" +
                              "4. Land split uses the live fleet count — not a fixed 2 or 3"
                        wrapMode: Text.WordWrap
                        font.family: ScreenTools.fixedFontFamily
                        color: qgcPal.text
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight
            }
        }
    }

    function checkSystemIDs() {
        var vehicles = QGroundControl.multiVehicleManager.vehicles
        if (vehicles.count === 0) {
            return "No vehicles connected"
        }
        var ids = []
        for (var i = 0; i < vehicles.count; i++) {
            ids.push(vehicles.get(i).id)
        }
        var unique = ids.filter(function(v, idx, a) { return a.indexOf(v) === idx })
        if (unique.length < ids.length) {
            return vehicles.count + " USB radio(s) linked. Shared SYS is OK — each cable is its own drone."
        }
        return vehicles.count + " vehicle(s) connected"
    }

    function getAvailablePorts() {
        var ports = []
        var live = []
        if (QGroundControl.linkManager && typeof QGroundControl.linkManager.usbSerialPorts === "function")
            live = QGroundControl.linkManager.usbSerialPorts()
        if (!live || live.length === 0)
            return ports
        var linkConfigs = QGroundControl.linkManager.linkConfigurations
        for (var i = 0; i < live.length; i++) {
            var port = live[i]
            var isConnected = false
            for (var j = 0; j < linkConfigs.count; j++) {
                var config = linkConfigs.get(j)
                if (config && (config.portName === port || (config.portDisplayName && port.indexOf(config.portDisplayName) >= 0))) {
                    isConnected = true
                    break
                }
            }
            ports.push({ port: port, index: i, connected: isConnected })
        }
        return ports
    }

    property string _lastError: ""

    function connectToPort(portName, vehicleNumber) {
        console.log("ASTHRA: Attempting to connect to", portName, "for Vehicle", vehicleNumber)
        _lastError = ""

        // Get link manager
        var linkManager = QGroundControl.linkManager
        if (!linkManager) {
            _lastError = "LinkManager not available"
            console.error("ASTHRA:", _lastError)
            showError("Connection Error", _lastError)
            return
        }

        // Check if link already exists
        var linkConfigs = linkManager.linkConfigurations
        var existingConfig = null
        for (var i = 0; i < linkConfigs.count; i++) {
            var config = linkConfigs.get(i)
            if (config && config.portName === portName) {
                existingConfig = config
                console.log("ASTHRA: Found existing link config for", portName)
                break
            }
        }

        if (existingConfig) {
            // Link exists, try to connect it
            console.log("ASTHRA: Connecting existing link...")
            try {
                linkManager.createConnectedLink(existingConfig)
                console.log("ASTHRA: Connection initiated successfully")
            } catch (e) {
                _lastError = "Exception: " + e.toString()
                console.error("ASTHRA: Error connecting:", e)
                showError("Connection Error", _lastError + "\n\nCheck:\n1. Port permissions (sudo chmod 666 " + portName + ")\n2. No other app using the port\n3. Device is connected")
            }
        } else {
            // Create new link configuration automatically
            console.log("ASTHRA: Creating new link configuration for", portName)
            try {
                // Create a new serial link configuration using the correct enum
                var linkType = LinkConfiguration.TypeSerial
                var linkName = "Vehicle " + vehicleNumber + " - " + portName
                var newConfig = linkManager.createConfiguration(linkType, linkName)

                if (newConfig) {
                    console.log("ASTHRA: New config created, type:", newConfig.linkType, "has portName:", typeof newConfig.portName !== 'undefined', "has baud:", typeof newConfig.baud !== 'undefined')

                    // Set port name and baud rate for serial link
                    try {
                        // Set port name - this should work for SerialConfiguration
                        newConfig.portName = portName
                        console.log("ASTHRA: Set portName to", portName, "actual value:", newConfig.portName)

                        // Set baud rate
                        newConfig.baud = 115200 // Standard baud rate
                        console.log("ASTHRA: Set baud to 115200, actual value:", newConfig.baud)
                    } catch (propError) {
                        console.error("ASTHRA: Error setting properties:", propError, propError.toString())
                        _lastError = "Error setting port properties: " + propError.toString()
                        showError("Configuration Error", _lastError)
                        return
                    }

                    // Save the configuration - this adds it to the linkConfigurations list
                    newConfig.dynamic = false
                    linkManager.endCreateConfiguration(newConfig)
                    console.log("ASTHRA: Link configuration created and saved successfully")
                    console.log("ASTHRA: Config after save - name:", newConfig.name, "portName:", newConfig.portName, "baud:", newConfig.baud)

                    // Connect using the config - endCreateConfiguration adds it to the list, so we can find it there
                    // Use a small delay to ensure the config is fully added to the list
                    Qt.callLater(function() {
                        console.log("ASTHRA: Attempting to connect using config, portName:", newConfig.portName, "baud:", newConfig.baud, "name:", newConfig.name)
                        
                        // Find the config in the linkConfigurations list (it was added by endCreateConfiguration)
                        var linkConfigs = linkManager.linkConfigurations
                        var savedConfig = null
                        for (var k = 0; k < linkConfigs.count; k++) {
                            var cfg = linkConfigs.get(k)
                            if (cfg && (cfg.portName === portName || cfg.name === linkName)) {
                                savedConfig = cfg
                                console.log("ASTHRA: Found config in list:", cfg.name, "portName:", cfg.portName)
                                break
                            }
                        }
                        
                        if (savedConfig) {
                            // Use the QML-friendly createConnectedLink that takes a LinkConfiguration pointer
                            try {
                                linkManager.createConnectedLink(savedConfig)
                                console.log("ASTHRA: Connection initiated successfully for", portName)
                            } catch (e) {
                                _lastError = "Exception during connection: " + e.toString()
                                console.error("ASTHRA:", _lastError)
                                showError("Connection Error", _lastError + "\n\nCheck:\n1. Port permissions (sudo chmod 666 " + portName + ")\n2. No other app using the port\n3. Device is connected")
                            }
                        } else {
                            _lastError = "Config not found in linkConfigurations list after creation"
                            console.error("ASTHRA:", _lastError)
                            showError("Configuration Error", _lastError + "\n\nPlease try:\n1. Restart ASTHRA\n2. Create link manually in Settings -> Comm Links")
                        }
                    }, 100) // Small delay to ensure config is fully added to list
                } else {
                    _lastError = "Failed to create link configuration - createConfiguration returned null"
                    console.error("ASTHRA:", _lastError)
                    showError("Configuration Error", _lastError + "\n\nPlease create link manually in Settings -> Comm Links")
                }
            } catch (e) {
                _lastError = "Exception creating link: " + e.toString()
                console.error("ASTHRA: Error creating link:", e, e.toString(), e.name, e.message)
                showError("Connection Error", _lastError + "\n\nPlease create link manually in Settings -> Comm Links\n\nPort: " + portName + "\nBaud: 115200")
            }
        }
    }

    function showError(title, message) {
        // Try to show error via mainWindow if available
        if (typeof mainWindow !== 'undefined' && mainWindow && typeof mainWindow.showMessageDialog === 'function') {
            mainWindow.showMessageDialog(title, message, Dialog.Ok)
        } else {
            // Fallback: log to console
            console.error("ASTHRA ERROR:", title, "-", message)
        }
    }
}
