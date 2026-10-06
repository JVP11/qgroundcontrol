import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.PlanView
import QGroundControl.Toolbar
import ASTHRA.Swarm

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:         mainWindow
    visible:    true
    title:      "ASTHRA - Advanced Strategic Tactical Humanitarian Response Analyser"
    // The special casing for android prevents white bars from showing up on the edges of the screen with newer android versions
    flags:      Qt.Window | (ScreenTools.isAndroid ? Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint : 0)

    // Qt 6.9+ auto-sets ApplicationWindow padding to the display safe-area insets on mobile,
    // which insets our full-bleed content and leaves a blank strip along the screen edge.
    // QGC draws edge-to-edge and manages its own insets, so zero the padding.
    topPadding:    0
    bottomPadding: 0
    leftPadding:   0
    rightPadding:  0

    // ASTHRA Mission Monitoring
    property var offboardMonitor: null
    property var missionLogger: null
    property var telemetryLogger: null
    property var cameraFrameCapture: null
    property var disasterReportGenerator: null
    property var disasterReportPanel: null
    property var _lastActiveVehicle: null  // Guard to prevent re-initialization loops
    
    // ASTHRA Swarm Backend
    property bool swarmOverlayEnabled: false
    property bool spatial3DOpen: false

    QtObject {
        id: swarmCoverageState
        property var landPath: []
        property real totalAreaM2: 0
        property string fileName: ""
        property var assignments: []
        property var sharePercents: ({})
        property int plannedN: 2
        property int revision: 0
    }
    property alias swarmCoverage: swarmCoverageState
    property alias swarmBackend: swarmClient
    
    SwarmWebSocketClient {
        id: swarmClient
        serverUrl: "ws://localhost:8765"
        Component.onCompleted: {
            // Auto-connect on startup
            connectToBackend()
        }
        onConnectedChanged: {
            if (connected && flyView._mapControl && swarmOverlayEnabled) {
                flyView._mapControl.enableSwarmMapOverlay(swarmClient)
            }
        }
        onErrorOccurred: function(message) {
            console.warn("Swarm backend:", message)
        }
    }

    Component.onCompleted: {
        firstRunPromptManager.nextPrompt()
        initializeASTHRAMonitoring()
        ensureAsthraReady()
    }

    /// Map defaults, full-screen fly map, and delayed tile refresh for first launch.
    function ensureAsthraReady() {
        var fm = QGroundControl.settingsManager.flightMapSettings
        // Bing Hybrid + high fractional zoom → grey map; OSM blocks QGC user-agent (403).
        if (fm.mapType.value === "Hybrid") {
            fm.mapType.value = "Road"
        }
        if (fm.mapProvider.value === "Street" || fm.mapProvider.value === "Japan-GSI") {
            fm.mapProvider.value = "Esri"
            fm.mapType.value = "World Street"
        }
        var z = Math.round(QGroundControl.flightMapZoom)
        if (z > 17) {
            z = 14
        } else if (z < 3) {
            z = 12
        }
        if (Math.abs(z - QGroundControl.flightMapZoom) > 0.01) {
            QGroundControl.flightMapZoom = z
        }
        QGroundControl.saveBoolGlobalSetting("MainFlyWindowIsMap", true)
        flyView.ensureMapFullScreen()
        _asthraMapReadyTimer.restart()
    }

    function _usableMapCoord(c) {
        return c && c.isValid && (Math.abs(c.latitude) > 0.01 || Math.abs(c.longitude) > 0.01)
    }

    function applyMapCenter() {
        if (!flyView._mapControl) {
            return
        }
        flyView._mapControl.updateActiveMapType()
        flyView._mapControl.ensureMapHasCenter()
        var vehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (vehicle && _usableMapCoord(vehicle.coordinate)) {
            flyView._mapControl.center = vehicle.coordinate
        } else {
            var pos = QGroundControl.flightMapPosition
            if (_usableMapCoord(pos)) {
                flyView._mapControl.center = pos
            }
        }
        flyView.ensureMapFullScreen()
    }

    Timer {
        id:                 _asthraMapReadyTimer
        interval:           800
        repeat:             false
        onTriggered: applyMapCenter()
    }

    function initializeASTHRAMonitoring() {
        // Create OFFBOARD monitor
        var monitorComponent = Qt.createComponent("qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRAOffboardMonitor.qml")
        if (monitorComponent.status === Component.Ready) {
            offboardMonitor = monitorComponent.createObject(mainWindow)
            if (offboardMonitor) {
                offboardMonitor.offboardExitDetected.connect(function(event) {
                    if (missionLogger) {
                        missionLogger.logOffboardEvent(event)
                    }
                })
            }
        }

        // Create Mission Logger
        var loggerComponent = Qt.createComponent("qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRAMissionLogger.qml")
        if (loggerComponent.status === Component.Ready) {
            missionLogger = loggerComponent.createObject(mainWindow)
        }

        // Create Telemetry Logger
        var telemetryComponent = Qt.createComponent("qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRATelemetryLogger.qml")
        if (telemetryComponent.status === Component.Ready) {
            telemetryLogger = telemetryComponent.createObject(mainWindow)
            if (missionLogger && telemetryLogger) {
                missionLogger.setTelemetryLogger(telemetryLogger)
            }
        }

        // Create Camera Frame Capture System
        var frameCaptureComponent = Qt.createComponent("qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRACameraFrameCapture.qml")
        if (frameCaptureComponent.status === Component.Ready) {
            cameraFrameCapture = frameCaptureComponent.createObject(mainWindow)
            if (cameraFrameCapture && telemetryLogger && missionLogger) {
                var vehicle = QGroundControl.multiVehicleManager.activeVehicle
                // Access VideoManager via QGroundControl global
                var videoManager = null
                try {
                    videoManager = QGroundControl.videoManager
                } catch(e) {
                    console.log("ASTHRA: Could not access VideoManager:", e)
                }
                if (videoManager) {
                    cameraFrameCapture.initialize(vehicle, videoManager, telemetryLogger, missionLogger)
                    // Connect telemetry logger to frame capture
                    telemetryLogger.frameCapture = cameraFrameCapture
                } else {
                    console.log("ASTHRA: VideoManager not available - frame capture disabled")
                }
            }
        }

        // Create Disaster Report Generator
        var reportGenComponent = Qt.createComponent("qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRADisasterReportGenerator.qml")
        if (reportGenComponent.status === Component.Ready) {
            disasterReportGenerator = reportGenComponent.createObject(mainWindow)
            if (disasterReportGenerator && missionLogger && telemetryLogger && offboardMonitor) {
                var vehicle = QGroundControl.multiVehicleManager.activeVehicle
                var missionController = flyView ? flyView.planController : null
                disasterReportGenerator.initialize(missionLogger, telemetryLogger, offboardMonitor, vehicle, missionController, cameraFrameCapture)
            }
        }

        // Connect to active vehicle changes - with guard to prevent loops
        QGroundControl.multiVehicleManager.activeVehicleChanged.connect(function() {
            var vehicle = QGroundControl.multiVehicleManager.activeVehicle

            // Guard: Only update if vehicle actually changed
            if (vehicle === mainWindow._lastActiveVehicle) {
                return
            }

            console.log("ASTHRA: Active vehicle changed to:", vehicle ? vehicle.id : "None")
            mainWindow._lastActiveVehicle = vehicle

            // Use Qt.callLater to batch updates and prevent cascading
            Qt.callLater(function() {
                // Initialize components with new vehicle (they handle disconnection internally)
                if (offboardMonitor) {
                    offboardMonitor.initialize(vehicle)
                }
                if (missionLogger) {
                    missionLogger.initialize(vehicle)
                    if (vehicle && vehicle.armed) {
                        missionLogger.startMission()
                    }
                }
                if (telemetryLogger) {
                    telemetryLogger.initialize(vehicle)
                }
                if (cameraFrameCapture) {
                    var videoManager = null
                    try {
                        videoManager = QGroundControl.videoManager
                    } catch(e) {
                        console.log("ASTHRA: Could not access VideoManager:", e)
                    }
                    if (videoManager) {
                        cameraFrameCapture.initialize(vehicle, videoManager, telemetryLogger, missionLogger)
                        if (telemetryLogger) {
                            telemetryLogger.frameCapture = cameraFrameCapture
                        }
                    }
                }
                if (disasterReportGenerator) {
                    var missionController = flyView ? flyView.planController : null
                    disasterReportGenerator.initialize(missionLogger, telemetryLogger, offboardMonitor, vehicle, missionController, cameraFrameCapture)
                }
                applyMapCenter()
            })
        })

        // Monitor vehicle armed state for mission start/end - handled in activeVehicleChanged above
        // The missionLogger.initialize() will connect to armedChanged signal
    }

    /// Saves main window position and size and re-opens it in the same position and size next time
    MainWindowSavedState {
        window: mainWindow
    }

    QtObject {
        id: firstRunPromptManager

        property var currentDialog:     null
        property var rgPromptIds:       QGroundControl.corePlugin.firstRunPromptsToShow()
        property int nextPromptIdIndex: 0

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt)
            }
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(rgPromptIds[nextPromptIdIndex]));
                currentDialog = component.createObject(mainWindow)
                currentDialog.closed.connect(nextPrompt)
                currentDialog.open()
                nextPromptIdIndex++
            } else {
                currentDialog = null
                showPreFlightChecklistIfNeeded()
            }
        }
    }

    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var       activeVehicle:                  QGroundControl.multiVehicleManager.activeVehicle
        readonly property real      defaultTextHeight:              ScreenTools.defaultFontPixelHeight
        readonly property real      defaultTextWidth:               ScreenTools.defaultFontPixelWidth
        readonly property var       planMasterControllerFlyView:    flyView.planController
        readonly property var       guidedControllerFlyView:        flyView.guidedController

        // Number of QGCTextField's with validation errors. Used to prevent closing panels with validation errors.
        property int                validationErrorCount:           0

        // Set to a non-empty string to block navigation with a custom reason (e.g. during calibration)
        property string             navigationBlockedReason:        ""

        // Property to manage RemoteID quick access to settings page
        property bool               commingFromRIDIndicator:        false
    }

    /// Default color palette used throughout the UI
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal forceArmVehicleRequest
    signal disarmVehicleRequest
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest
    signal showPreFlightChecklistIfNeeded

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    // This function is used to prevent view switching if there are validation errors
    function allowViewSwitch(previousValidationErrorCount = 0, showErrorOnDisallow = true) {
        // Check for explicit navigation block (e.g. calibration in progress)
        if (globals.navigationBlockedReason !== "") {
            if (showErrorOnDisallow) {
                validationErrorToast.text = globals.navigationBlockedReason
                if (validationErrorToast.visible) {
                    validationErrorToast.close()
                }
                validationErrorToast.open()
            }
            return false
        }
        // Run validation on active focus control to ensure it is valid before switching views
        if (mainWindow.activeFocusControl instanceof FactTextField) {
            mainWindow.activeFocusControl._onEditingFinished()
        }
        var allowed = globals.validationErrorCount <= previousValidationErrorCount
        if (!allowed && showErrorOnDisallow) {
            validationErrorToast.text = qsTr("Please correct the invalid value before continuing")
            if (validationErrorToast.visible) {
                validationErrorToast.close()
            }
            validationErrorToast.open()
        }
        return allowed
    }

    function showPlanView() {
        flyView.visible = false
        planView.visible = true
        toolDrawer.visible = false
    }

    function coverageMap() {
        return flyView._mapControl
    }

    function fitCoverageLand(path) {
        if (!flyView._mapControl || !path || path.length < 2)
            return
        var minLat = 90, maxLat = -90, minLon = 180, maxLon = -180
        for (var i = 0; i < path.length; i++) {
            var c = path[i]
            var lat = (c.latitude !== undefined) ? c.latitude : c.lat
            var lon = (c.longitude !== undefined) ? c.longitude : c.lng
            minLat = Math.min(minLat, lat)
            maxLat = Math.max(maxLat, lat)
            minLon = Math.min(minLon, lon)
            maxLon = Math.max(maxLon, lon)
        }
        var padLat = Math.max(0.002, (maxLat - minLat) * 0.25)
        var padLon = Math.max(0.002, (maxLon - minLon) * 0.25)
        flyView._mapControl.setVisibleRegion(QtPositioning.rectangle(
                                                 QtPositioning.coordinate(maxLat + padLat, minLon - padLon),
                                                 QtPositioning.coordinate(minLat - padLat, maxLon + padLon)))
    }

    function showFlyView(keepDrawer) {
        flyView.visible = true
        planView.visible = false
        if (!keepDrawer)
            toolDrawer.visible = false
        applyMapCenter()
        if (swarmOverlayEnabled && flyView._mapControl && swarmClient.connected) {
            flyView._mapControl.enableSwarmMapOverlay(swarmClient)
        }
    }
    
    function toggleSpatial3DView() {
        spatial3DOpen = !spatial3DOpen
        if (spatial3DOpen) {
            showFlyView()
        }
    }

    function toggleSwarmOverlay() {
        swarmOverlayEnabled = !swarmOverlayEnabled
        if (flyView._mapControl) {
            if (swarmOverlayEnabled && swarmClient.connected) {
                flyView._mapControl.enableSwarmMapOverlay(swarmClient)
            } else {
                flyView._mapControl.disableSwarmMapOverlay()
            }
        }
    }

    function showTool(toolTitle, toolSource, toolIcon, sidePanel) {
        console.log("ASTHRA: showTool called - title:", toolTitle, "source:", toolSource)
        toolDrawer.sideMode     = !!sidePanel
        toolDrawer.backIcon     = flyView.visible ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Plan.svg"
        toolDrawer.toolTitle    = toolTitle
        toolDrawer.toolSource   = toolSource
        toolDrawer.toolIcon     = toolIcon
        // Set source directly to Loader
        toolDrawerLoader.source = toolSource
        console.log("ASTHRA: Set toolDrawerLoader.source to:", toolSource)
        toolDrawer.visible      = true
    }

    function showAnalyzeTool() {
        showTool(qsTr("Analyze Tools"), "qrc:/qml/QGroundControl/AnalyzeView/AnalyzeView.qml", "/qmlimages/Analyze.svg")
    }

    function showVehicleConfig() {
        showTool(qsTr("Vehicle Configuration"), "qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigView.qml", "/qmlimages/Gears.svg")
    }

    function showVehicleConfigParametersPage() {
        showVehicleConfig()
        toolDrawerLoader.item.showParametersPanel()
    }

    function showKnownVehicleComponentConfigPage(knownVehicleComponent) {
        showVehicleConfig()
        let vehicleComponent = globals.activeVehicle.autopilotPlugin.findKnownVehicleComponent(knownVehicleComponent)
        if (vehicleComponent) {
            toolDrawerLoader.item.showVehicleComponentPanel(vehicleComponent)
        }
    }

    function showSettingsTool(settingsPage = "") {
        showTool(qsTr("Application Settings"), "qrc:/qml/QGroundControl/Controls/AppSettings.qml", "")  // Logo removed for ASTHRA
        if (settingsPage !== "") {
            toolDrawerLoader.item.showSettingsPage(settingsPage)
        }
    }

    function showSwarmCoverage() {
        flyView.visible = true
        planView.visible = false
        applyMapCenter()
        if (swarmOverlayEnabled && flyView._mapControl && swarmClient.connected) {
            flyView._mapControl.enableSwarmMapOverlay(swarmClient)
        }
        showTool(qsTr("Split land"), "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRASwarmCoveragePanel.qml", "", true)
        if (QGroundControl.linkManager && typeof QGroundControl.linkManager.connectAvailableUsbRadios === "function")
            QGroundControl.linkManager.connectAvailableUsbRadios()
        if (toolDrawerLoader.item) {
            toolDrawerLoader.item.mainWindow = mainWindow
            toolDrawerLoader.item.coverage = swarmCoverageState
            toolDrawerLoader.item.swarmBackend = swarmClient
        }
        var land = swarmCoverageState && swarmCoverageState.landPath
        if (land && land.length >= 3)
            fitCoverageLand(land)
        else
            applyMapCenter()
    }

    function showDualVehicleConnection() {
        showSwarmCoverage()
    }

    function showRescueReport() {
        showTool(qsTr("Rescue Report - OFFBOARD Events"), "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRARescueReportPanel.qml", "")
        if (toolDrawerLoader.item && missionLogger) {
            toolDrawerLoader.item.missionLogger = missionLogger
            toolDrawerLoader.item.offboardMonitor = offboardMonitor
        }
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function _showMessageDialogWorker(owner, dialogTitle, dialogText, buttons = Dialog.Ok, acceptFunction = null, closeFunction = null, bypassNavigationCheck = false) {
        let dialog = simpleMessageDialogComponent.createObject(owner, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction, closeFunction: closeFunction, bypassNavigationCheck: bypassNavigationCheck })
        dialog.open()
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle, dialogText)
    }

    Connections {
        target: QGroundControl

        function onShowMessageDialogRequested(owner, title, text, buttons, acceptFunction, closeFunction) {
            _showMessageDialogWorker(owner, title, text, buttons, acceptFunction, closeFunction)
        }
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    property bool _forceClose: false
    property bool suppressCriticalVehicleMessages: false

    function finishCloseProcess() {
        _forceClose = true
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        firstRunPromptManager.clearNextPromptSignal()
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // Check for things which should prevent the app from closing
    //  Returns true if it is OK to close
    readonly property int _skipUnsavedMissionCheckMask: 0x01
    readonly property int _skipPendingParameterWritesCheckMask: 0x02
    readonly property int _skipActiveConnectionsCheckMask: 0x04
    property int _closeChecksToSkip: 0
    property bool _reentrantCloseGuard: false
    function performCloseChecks() {
        if (!(_closeChecksToSkip & _skipUnsavedMissionCheckMask) && !checkForUnsavedMission()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipPendingParameterWritesCheckMask) && !checkForPendingParameterWrites()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipActiveConnectionsCheckMask) && !checkForActiveConnections()) {
            return false
        }
        finishCloseProcess()
        return true
    }

    function checkForUnsavedMission() {
        // Only warn when edits are neither saved to disk nor uploaded to the vehicle.
        // If either happened the edits are recoverable, so closing loses nothing.
        // With no active vehicle an upload can't have happened, so treat the plan as
        // not uploaded regardless of dirtyForUpload.
        if (planView._planMasterController.dirtyForSave &&
                (planView._planMasterController.dirtyForUpload || !QGroundControl.multiVehicleManager.activeVehicle)) {
            let accepted = false
            _reentrantCloseGuard = true
            _showMessageDialogWorker(mainWindow, qsTr("Unsaved Mission"),
                              qsTr("You have a mission edit in progress which has not been saved/uploaded. If you close you will lose changes. Are you sure you want to close?"),
                              Dialog.Yes | Dialog.No,
                              function() { accepted = true; _closeChecksToSkip |= _skipUnsavedMissionCheckMask; performCloseChecks() },
                              function() { if (!accepted) _reentrantCloseGuard = false },
                              true /* bypassNavigationCheck */)
            return false
        } else {
            return true
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                let accepted = false
                _reentrantCloseGuard = true
                _showMessageDialogWorker(mainWindow, qsTr("Pending Parameter Updates"),
                    qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
                    Dialog.Yes | Dialog.No,
                    function() { accepted = true; _closeChecksToSkip |= _skipPendingParameterWritesCheckMask; performCloseChecks() },
                    function() { if (!accepted) _reentrantCloseGuard = false },
                    true /* bypassNavigationCheck */)
                return false
            }
        }
        return true
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            let accepted = false
            _reentrantCloseGuard = true
            _showMessageDialogWorker(mainWindow, qsTr("Active Vehicle Connections"),
                qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
                Dialog.Yes | Dialog.No,
                function() { accepted = true; _closeChecksToSkip |= _skipActiveConnectionsCheckMask; performCloseChecks() },
                function() { if (!accepted) _reentrantCloseGuard = false },
                true /* bypassNavigationCheck */)
            return false
        } else {
            return true
        }
    }

    onClosing: (close) => {
        if (!_forceClose) {
            if (_reentrantCloseGuard) {
                close.accepted = false
                return
            }
            _closeChecksToSkip = 0
            close.accepted = performCloseChecks()
        }
    }

    background: Rectangle {
        anchors.fill:   parent
        color:          QGroundControl.globalPalette.window
    }

    // ============================================================================
    // ASTHRA - LOCKED MILITARY-INDUSTRIAL LAYOUT
    // Fixed structure: Top Strip | Left Column | Central Workspace | Right Column | Bottom Bar
    // ============================================================================

    // ============================================================================
    // ASTHRA - LOCKED MILITARY-INDUSTRIAL LAYOUT
    // Fixed structure: Top Strip | Left Column | Central Workspace | Right Column | Bottom Bar
    // ============================================================================

    // Boot screen: covers the window on start-up, then unloads itself
    Loader {
        id:             bootScreenLoader
        anchors.fill:   parent
        z:              100000
        source:         "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRABootScreen.qml"
        onLoaded:       item.forceActiveFocus()
        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load ASTHRABootScreen")
                active = false
            }
        }

        Binding {
            target:     bootScreenLoader.item
            when:       bootScreenLoader.status === Loader.Ready
            property:   "mapReady"
            value:      !!flyView._mapControl
        }
        Binding {
            target:     bootScreenLoader.item
            when:       bootScreenLoader.status === Loader.Ready
            property:   "swarmConnected"
            value:      swarmClient.connected
        }
        Connections {
            target:     bootScreenLoader.item
            function onFinished() { bootScreenLoader.active = false }
        }
    }

    // Top Status Strip
    Loader {
        id: topStatusStrip
        source: "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRATopStatusStrip.qml"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load ASTHRATopStatusStrip:", sourceComponent.errorString())
            }
        }
    }

    // Left System Control Column
    Loader {
        id: leftControlColumn
        source: "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRALeftControlColumn.qml"
        anchors.left: parent.left
        anchors.top: topStatusStrip.bottom
        anchors.bottom: bottomCommandBar.top
        onLoaded: {
            if (item) {
                item.globals = globals
            }
        }
        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load ASTHRALeftControlColumn:", sourceComponent.errorString())
            }
        }
    }

    // Right Telemetry Column
    Loader {
        id: rightTelemetryColumn
        source: "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRARightTelemetryColumn.qml"
        anchors.right: parent.right
        anchors.top: topStatusStrip.bottom
        anchors.bottom: bottomCommandBar.top
        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load ASTHRARightTelemetryColumn:", sourceComponent.errorString())
            }
        }
    }

    // Central Mission Workspace (Fly/Plan/Analyze views)
    Rectangle {
        id:                     centralWorkspace
        anchors.left:           leftControlColumn.right
        anchors.right:          rightTelemetryColumn.left
        anchors.top:            topStatusStrip.bottom
        anchors.bottom:         bottomCommandBar.top
        color:                  qgcPal.window
        border.width:           2
        border.color:           qgcPal.buttonBorder

        // Military corner brackets on workspace (optimized Rectangle-based for performance)
        Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 3
            width: 12
            height: 12
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 2; height: 12; color: qgcPal.colorBlue }
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 12; height: 2; color: qgcPal.colorBlue }
        }

        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 3
            width: 12
            height: 12
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 2; height: 12; color: qgcPal.colorBlue }
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 12; height: 2; color: qgcPal.colorBlue }
        }

        Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 3
            width: 12
            height: 12
            Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 2; height: 12; color: qgcPal.colorBlue }
            Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 12; height: 2; color: qgcPal.colorBlue }
        }

        Item {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 3
            width: 12
            height: 12
            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 2; height: 12; color: qgcPal.colorBlue }
            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 12; height: 2; color: qgcPal.colorBlue }
        }

        SplitView {
            id:                     flySplitView
            anchors.fill:           parent
            orientation:            Qt.Horizontal
            visible:                flyView.visible

            clip: true

            handle: Rectangle {
                implicitWidth:  6
                color:          SplitHandle.pressed ? qgcPal.colorBlue : qgcPal.buttonBorder
                Rectangle {
                    anchors.centerIn: parent
                    width: 2
                    height: parent.height * 0.18
                    color: Qt.lighter(parent.color, 1.4)
                    opacity: 0.6
                }
            }

            FlyView {
                id:                         flyView
                objectName:                 "mainView_fly"
                useAsthraChrome:            true
                enabled:                    !toolDrawer.visible || toolDrawer.sideMode
                SplitView.fillWidth:        true
                SplitView.fillHeight:       true
                SplitView.minimumWidth:     ScreenTools.defaultFontPixelWidth * 20
            }

            Loader {
                id:                         spatial3DLoader
                active:                     mainWindow.spatial3DOpen
                visible:                    mainWindow.spatial3DOpen
                clip:                       true
                SplitView.fillHeight:       true
                SplitView.preferredWidth:   Math.max(320, Math.min(460, centralWorkspace.width * 0.32))
                SplitView.minimumWidth:     mainWindow.spatial3DOpen ? 320 : 0
                SplitView.fillWidth:        false
                source:                     "qrc:/qml/QGroundControl/UI/ASTHRA/Spatial3D/ASTHRASpatial3DView.qml"
                onLoaded: {
                    if (item) {
                        item.planMasterController = flyView.planController
                    }
                }
            }
        }

        // Swarm KML land-cover overlay
        Loader {
            id: swarmCoverageMapLoader
            source: "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRASwarmCoverageMap.qml"
            visible: flyView.visible
            onLoaded: {
                if (item) {
                    item.coverage = swarmCoverageState
                    item.map = Qt.binding(function() { return flyView._mapControl })
                }
            }
        }

        // OFFBOARD Event Map Markers (overlay on map)
        Loader {
            id: offboardMarkersLoader
            source: "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRAOffboardMapMarkers.qml"
            visible: flyView.visible
            onLoaded: {
                if (item && flyView._mapControl) {
                    item.map = flyView._mapControl
                    item.offboardEvents = Qt.binding(function() {
                        return missionLogger ? missionLogger.getOffboardEvents() : []
                    })
                }
            }
        }
        
        // ASTHRA Swarm Control Panel (top-right of map pane)
        SwarmControlPanel {
            id: swarmControlPanel
            swarmClient: swarmClient
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: ScreenTools.defaultFontPixelHeight
            visible: flyView.visible && swarmOverlayEnabled
            z: 100
        }

        PlanView {
            id:             planView
            objectName:     "mainView_plan"
            anchors.fill:   parent
            visible:        false
            enabled:        !toolDrawer.visible
        }
    }

    // Bottom Command Bar
    Loader {
        id: bottomCommandBar
        source: "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRABottomCommandBar.qml"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        onLoaded: {
            if (item) {
                item.flyView = flyView
                item.planView = planView
                item.globals = globals
            }
        }
        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load ASTHRABottomCommandBar:", sourceComponent.errorString())
            }
        }
    }

    footer: Item {
        // Footer disabled for ASTHRA layout
        height: 0
    }

    MessageDialog {
        id:                 showTouchAreasNotification
        title:              qsTr("Debug Touch Areas")
        text:               qsTr("Touch Area display toggled")
        buttons:            MessageDialog.Ok
    }

    MessageDialog {
        id:                 advancedModeOnConfirmation
        title:              qsTr("Advanced Mode")
        text:               QGroundControl.corePlugin.showAdvancedUIMessage
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = true
            }
        }
    }

    MessageDialog {
        id:                 advancedModeOffConfirmation
        title:              qsTr("Advanced Mode")
        text:               qsTr("Turn off Advanced Mode?")
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = false
            }
        }
    }

    function showToolSelectDialog() {
        if (mainWindow.allowViewSwitch()) {
            mainWindow.showIndicatorDrawer(toolSelectComponent, null)
        }
    }

    // Toast notification shown when a view switch is blocked by a validation error
    ToolTip {
        id:             validationErrorToast
        x:              (mainWindow.width - width) / 2
        y:              mainWindow.height - height - ScreenTools.defaultFontPixelHeight * 3
        timeout:        3000
        closePolicy:    Popup.NoAutoClose
        text:           qsTr("Please correct the invalid value before continuing")

        background: Rectangle {
            color:  qgcPal.alertBackground
            radius: ScreenTools.defaultFontPixelWidth / 2
        }

        contentItem: QGCLabel {
            text:   validationErrorToast.text
            color:  qgcPal.alertText
        }
    }

    Component {
        id: toolSelectComponent

        SelectViewDropdown {
        }
    }

    // Tool Drawer — full-screen for settings; side panel for SWARM so the map stays visible
    Rectangle {
        id:             toolDrawer
        objectName:     "mainView_toolDrawer"
        anchors.top:    sideMode ? topStatusStrip.bottom : parent.top
        anchors.bottom: sideMode ? bottomCommandBar.top : parent.bottom
        anchors.right:  sideMode ? rightTelemetryColumn.left : parent.right
        width:          sideMode ? Math.min(centralWorkspace.width * 0.46, ScreenTools.defaultFontPixelWidth * 48) : parent.width
        visible:        false
        z:              1000
        color:          qgcPal.window
        border.width:   sideMode ? 1 : 0
        border.color:   qgcPal.buttonBorder

        property bool sideMode: false
        property var backIcon
        property string toolTitle
        property string toolSource: ""
        property var toolIcon

        onVisibleChanged: {
            console.log("ASTHRA: toolDrawer visible changed to:", visible, "toolSource:", toolSource)
            if (!toolDrawer.visible) {
                toolDrawerLoader.source = ""
            }
        }

        // This need to block click event leakage to underlying map.
        DeadMouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id:             toolDrawerToolbar
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            height:         ScreenTools.toolbarHeight
            color:          qgcPal.toolbarBackground

            RowLayout {
                id:                 toolDrawerToolbarLayout
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.left:       parent.left
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                spacing:            ScreenTools.defaultFontPixelWidth

                // BACK Button - Military Standard
                QGCButton {
                    id:                 backButton
                    text:               "BACK"
                    font.family:        ScreenTools.fixedFontFamily
                    font.weight:        Font.Bold
                    font.pointSize:     ScreenTools.defaultFontPointSize * 1.0
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                    Layout.preferredHeight: parent.height * 0.8
                    onClicked:          {
                        toolDrawer.visible = false
                    }
                }

                QGCLabel {
                    id:             toolbarDrawerText
                    text:           toolDrawer.toolTitle
                    font.pointSize: ScreenTools.largeFontPointSize
                    font.family:    ScreenTools.fixedFontFamily
                    font.weight:    Font.Bold
                    Layout.fillWidth: true
                }
            }
        }

        Loader {
            id:             toolDrawerLoader
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    toolDrawerToolbar.bottom
            anchors.bottom: parent.bottom

            Connections {
                target:                 toolDrawerLoader.item
                ignoreUnknownSignals:   true
                function onPopout() { toolDrawer.visible = false }
            }

            onLoaded: {
                console.log("ASTHRA: Tool drawer loader loaded, source:", toolDrawerLoader.source)
                console.log("ASTHRA: Tool drawer loader item:", toolDrawerLoader.item)
                console.log("ASTHRA: Tool drawer loader status:", toolDrawerLoader.status)
                if (toolDrawerLoader.status === Loader.Error) {
                    console.error("ASTHRA: Loader ERROR -", toolDrawerLoader.errorString())
                }
                if (toolDrawerLoader.item) {
                    console.log("ASTHRA: Tool drawer item width:", toolDrawerLoader.item.width, "height:", toolDrawerLoader.item.height)
                } else {
                    console.error("ASTHRA: Tool drawer item is NULL!")
                }
                // Pass mission logger and offboard monitor to rescue report panel
                if (toolDrawerLoader.item && toolDrawerLoader.item.missionLogger !== undefined) {
                    toolDrawerLoader.item.missionLogger = missionLogger
                }
                if (toolDrawerLoader.item && toolDrawerLoader.item.offboardMonitor !== undefined) {
                    toolDrawerLoader.item.offboardMonitor = offboardMonitor
                }
                // Pass mainWindow reference to dual vehicle connection panel
                if (toolDrawerLoader.item && toolDrawerLoader.item.mainWindow !== undefined) {
                    toolDrawerLoader.item.mainWindow = mainWindow
                }
                if (toolDrawerLoader.item && toolDrawerLoader.item.coverage !== undefined) {
                    toolDrawerLoader.item.coverage = swarmCoverageState
                }
                if (toolDrawerLoader.item && toolDrawerLoader.item.swarmBackend !== undefined) {
                    toolDrawerLoader.item.swarmBackend = swarmClient
                }
                // Refresh report when loaded
                if (toolDrawerLoader.item && typeof toolDrawerLoader.item.refreshReport === 'function') {
                    toolDrawerLoader.item.refreshReport()
                }
            }

            onStatusChanged: {
                console.log("ASTHRA: Tool drawer loader status changed to:", status, "source:", toolDrawerLoader.source)
                if (status === Loader.Error) {
                    console.error("ASTHRA: Tool drawer loader ERROR:", toolDrawerLoader.source)
                    console.error("ASTHRA: Error string:", toolDrawerLoader.errorString())
                } else if (status === Loader.Ready) {
                    console.log("ASTHRA: Tool drawer loader READY:", toolDrawerLoader.source)
                } else if (status === Loader.Loading) {
                    console.log("ASTHRA: Tool drawer loader LOADING:", toolDrawerLoader.source)
                } else if (status === Loader.Null) {
                    console.log("ASTHRA: Tool drawer loader NULL (source cleared)")
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function showCriticalVehicleMessage(message) {
        if (suppressCriticalVehicleMessages) {
            return
        }
        if (criticalVehicleMessagePopup.visible) {
            // Once a message is held back, later ones are too so the shown messages stay in order
            if (!criticalVehicleMessagePopup.additionalCriticalMessagesReceived && criticalVehicleMessagePopup.appendMessageIfRoom(message)) {
                criticalVehicleMessageDismissTimer.restart()
            } else if (!criticalVehicleMessagePopup.additionalCriticalMessagesReceived) {
                // When the user closes the popup drop the message indicator tool so they can see the rest.
                criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
                // Leave time to act on the new "Click to see more" prompt
                criticalVehicleMessageDismissTimer.restart()
            }
        } else if (QGroundControl.videoManager.fullScreen) {
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = message
            criticalVehicleMessagePopup.shownMessageCount           = 1
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false
            criticalVehicleMessagePopup.open()
        }
    }

    // No focus and no Escape handler: either would steal keys from whatever the user is typing in.
    Popup {
        id:                 criticalVehicleMessagePopup
        objectName:         "criticalVehicleMessage_popup"
        y:                  ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight - topInset
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + _chromeHeight
        topInset:           vehicleWarningHeading.height / 2
        topPadding:         padding + topInset
        modal:              false
        closePolicy:        Popup.CloseOnPressOutside

        property alias  criticalVehicleMessage:             criticalVehicleMessageText.text
        property bool   additionalCriticalMessagesReceived: false
        property int    shownMessageCount:                  0
        readonly property int maxShownMessages:             5

        readonly property real _chromeHeight:   topInset + ScreenTools.defaultFontPixelHeight
        readonly property real _maxHeight:      mainWindow.height - y - ScreenTools.defaultFontPixelHeight

        function appendMessageIfRoom(message) {
            if (shownMessageCount >= maxShownMessages) {
                return false
            }
            const previousMessages = criticalVehicleMessage
            criticalVehicleMessage += "<br/>" + message
            if (criticalVehicleMessageText.contentHeight + _chromeHeight > _maxHeight) {
                criticalVehicleMessage = previousMessages
                return false
            }
            shownMessageCount++
            return true
        }

        function acknowledge() {
            close()
            if (additionalCriticalMessagesReceived) {
                additionalCriticalMessagesReceived = false
                flyView.dropMainStatusIndicatorTool()
            }
        }

        background: Rectangle {
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                id:                         vehicleWarningHeading
                objectName:                 "criticalVehicleMessage_heading"
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      Math.min(vehicleWarningLabel.implicitWidth + _margins, parent.width - ScreenTools.defaultFontPixelHeight)
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    width:              parent.width - parent._margins
                    horizontalAlignment: Text.AlignHCenter
                    elide:              Text.ElideRight
                    text:               criticalVehicleMessagePopup.additionalCriticalMessagesReceived ?
                                            qsTr("Vehicle Alert - Click to see more") :
                                            qsTr("Vehicle Alert")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            // Extends over the heading's overhang so clicking the heading acknowledges too
            MouseArea {
                anchors.fill:       parent
                anchors.topMargin:  -criticalVehicleMessagePopup.topInset
                onClicked:          criticalVehicleMessagePopup.acknowledge()
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            objectName:         "criticalVehicleMessage_text"
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
            textFormat:         TextEdit.RichText
        }

        // Plain close, not acknowledge(): a timeout must not drop the status indicator drawer.
        Timer {
            id:             criticalVehicleMessageDismissTimer
            objectName:     "criticalVehicleMessage_dismissTimer"
            interval:       10000
            running:        criticalVehicleMessagePopup.visible
            onTriggered:    criticalVehicleMessagePopup.close()
        }
    }

    //-------------------------------------------------------------------------
    //-- Indicator Drawer

    function showIndicatorDrawer(drawerComponent, indicatorItem) {
        indicatorDrawer.sourceComponent = drawerComponent
        indicatorDrawer.indicatorItem = indicatorItem
        indicatorDrawer.open()
    }

    function closeIndicatorDrawer() {
        indicatorDrawer.close()
    }

    // Fires before the active vehicle is cleared, so drawer contents never see it go null
    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleAvailableChanged(activeVehicleAvailable) {
            if (!activeVehicleAvailable) {
                closeIndicatorDrawer()
            }
        }
    }

    Popup {
        id:             indicatorDrawer
        x:              calcXPosition()
        y:              ScreenTools.toolbarHeight + _margins
        leftInset:      0
        rightInset:     0
        topInset:       0
        bottomInset:    0
        padding:        _margins * 2
        visible:        false
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var sourceComponent
        property var indicatorItem

        property bool _expanded:    false
        property real _margins:     ScreenTools.defaultFontPixelHeight / 4
        property bool _fillWindow:  indicatorDrawerLoader.item ? indicatorDrawerLoader.item.fillWindow === true : false

        function calcXPosition() {
            if (_fillWindow) {
                return _margins
            }
            if (indicatorItem) {
                var xCenter = indicatorItem.mapToItem(mainWindow.contentItem, indicatorItem.width / 2, 0).x
                return Math.max(_margins, Math.min(xCenter - (contentItem.implicitWidth / 2), mainWindow.contentItem.width - contentItem.implicitWidth - _margins - (indicatorDrawer.padding * 2) - (ScreenTools.defaultFontPixelHeight / 2)))
            } else {
                return _margins
            }
        }

        onOpened: {
            _expanded                               = false;
            indicatorDrawerLoader.sourceComponent   = indicatorDrawer.sourceComponent
        }
        onClosed: {
            _expanded                               = false
            indicatorItem                           = undefined
            indicatorDrawerLoader.sourceComponent   = undefined
        }

        background: Item {
            Rectangle {
                id:             backgroundRect
                anchors.fill:   parent
                color:          QGroundControl.globalPalette.window
                radius:         indicatorDrawer._margins
                opacity:        0.85
            }

            Rectangle {
                objectName:                 "indicatorDrawerExpandButton"
                anchors.horizontalCenter:   backgroundRect.right
                anchors.verticalCenter:     backgroundRect.top
                width:                      ScreenTools.largeFontPixelHeight
                height:                     width
                radius:                     width / 2
                color:                      QGroundControl.globalPalette.button
                border.color:               QGroundControl.globalPalette.buttonText
                visible:                    indicatorDrawerLoader.item && indicatorDrawerLoader.item._showExpand && !indicatorDrawer._expanded

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               ">"
                    color:              QGroundControl.globalPalette.buttonText
                }

                QGCMouseArea {
                    fillItem: parent
                    onClicked: indicatorDrawer._expanded = true
                }
            }
        }

        contentItem: QGCFlickable {
            id:             indicatorDrawerLoaderFlickable
            implicitWidth:  indicatorDrawer._fillWindow ? _availableWidth : Math.min(_availableWidth, indicatorDrawerLoader.width)
            implicitHeight: indicatorDrawer._fillWindow ? _availableHeight : Math.min(_availableHeight, indicatorDrawerLoader.height)
            contentWidth:   indicatorDrawerLoader.width
            contentHeight:  indicatorDrawerLoader.height

            property real _availableWidth:  mainWindow.contentItem.width - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2)
            property real _availableHeight: mainWindow.contentItem.height - ScreenTools.toolbarHeight - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2)

            Loader {
                id:         indicatorDrawerLoader
                objectName: "indicatorDrawerLoader"
                width:      indicatorDrawer._fillWindow ? indicatorDrawerLoaderFlickable.width : undefined

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "expanded"
                    value:      indicatorDrawer._expanded
                }

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "drawer"
                    value:      indicatorDrawer
                }
            }
        }
    }

    // Analyze page items (both in-panel and popped-out windows) are created with mainWindow as their
    // QObject parent so their lifetime is not tied to AnalyzeView. This lets a popped-out window
    // survive AnalyzeView being unloaded from the tool drawer.

    // Tracks the analyze page item currently shown inside AnalyzeView's panel (not popped out).
    // null when no page is loaded or the item has been handed off to a popup window.
    property var _inPanelAnalyzePage: null

    // Called by AnalyzeView.Component.onDestruction to destroy the in-panel item while
    // panelContainer is still alive.
    function destroyInPanelAnalyzePage() {
        if (_inPanelAnalyzePage) {
            _inPanelAnalyzePage.destroy()
            _inPanelAnalyzePage = null
        }
    }

    // Called by AnalyzeView to create an analyze page item owned by mainWindow.
    // The caller sets the visual parent to panelContainer after creation.
    function createAnalyzePage(source) {
        if (_inPanelAnalyzePage) {
            _inPanelAnalyzePage.destroy()
            _inPanelAnalyzePage = null
        }
        var component = Qt.createComponent(source)
        if (component.status !== Component.Ready) {
            console.warn("createAnalyzePage failed source:", source, "errorString:", component.errorString())
            return null
        }
        _inPanelAnalyzePage = component.createObject(mainWindow)
        return _inPanelAnalyzePage
    }

    // Called by AnalyzeView when the in-panel item is handed off to a popup window.
    // Clears _inPanelAnalyzePage so destroyInPanelAnalyzePage() does not destroy it
    // when AnalyzeView is torn down.
    function analyzePageMovedToPopup() {
        _inPanelAnalyzePage = null
    }

    function createWindowedAnalyzePage(title, source, requiresVehicle, existingItem) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.requiresVehicle = requiresVehicle
        if (existingItem) {
            windowedPage.adoptItem(existingItem)
        } else {
            windowedPage.source = source
        }
        windowedPage.visible = true
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    false

            property alias source: loader.source
            property bool requiresVehicle: false

            function adoptItem(item) {
                loader.visible = false
                loader.source = ""
                item.parent = contentRect
                item.anchors.fill = contentRect
                item.popped = true
                item.visible = true
            }

            Connections {
                target: QGroundControl.multiVehicleManager
                function onActiveVehicleChanged() {
                    if (requiresVehicle) {
                        close()
                    }
                }
            }

            Rectangle {
                id:             contentRect
                color:          QGroundControl.globalPalette.window
                anchors.fill:   parent

                Loader {
                    id:             loader
                    anchors.fill:   parent
                    onLoaded:       item.popped = true
                }
            }

            onClosing: {
                visible = false
                // Destroy any reparented children (not owned by loader)
                for (var i = contentRect.children.length - 1; i >= 0; i--) {
                    var child = contentRect.children[i]
                    if (child !== loader) {
                        child.destroy()
                    }
                }
                source = ""
                Qt.callLater(destroy)
            }
        }
    }
}
