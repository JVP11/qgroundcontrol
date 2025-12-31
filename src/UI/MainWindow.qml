/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.Toolbar

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:         mainWindow
    visible:    true
    title:      "ASTHRA - Advanced Strategic Tactical Humanitarian Response Analyser"
    // The special casing for android prevents white bars from showing up on the edges of the screen with newer android versions
    flags:      Qt.Window | (ScreenTools.isAndroid ? Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint : 0)

    property bool   _utmspSendActTrigger

    // ASTHRA Mission Monitoring
    property var offboardMonitor: null
    property var missionLogger: null
    property var telemetryLogger: null
    property var cameraFrameCapture: null
    property var disasterReportGenerator: null
    property var disasterReportPanel: null
    property var _lastActiveVehicle: null  // Guard to prevent re-initialization loops

    Component.onCompleted: {
        // Start the sequence of first run prompt(s)
        firstRunPromptManager.nextPrompt()

        // Initialize ASTHRA monitoring
        initializeASTHRAMonitoring()
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
    function allowViewSwitch(previousValidationErrorCount = 0) {
        // Run validation on active focus control to ensure it is valid before switching views
        if (mainWindow.activeFocusControl instanceof FactTextField) {
            mainWindow.activeFocusControl._onEditingFinished()
        }
        return globals.validationErrorCount <= previousValidationErrorCount
    }

    function showPlanView() {
        flyView.visible = false
        planView.visible = true
        toolDrawer.visible = false
    }

    function showFlyView() {
        flyView.visible = true
        planView.visible = false
        toolDrawer.visible = false
    }

    function showTool(toolTitle, toolSource, toolIcon) {
        console.log("ASTHRA: showTool called - title:", toolTitle, "source:", toolSource)
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
        showTool(qsTr("Vehicle Configuration"), "qrc:/qml/QGroundControl/VehicleSetup/SetupView.qml", "/qmlimages/Gears.svg")
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

    function showDualVehicleConnection() {
        showTool(qsTr("Dual Vehicle Connection"), "qrc:/qml/QGroundControl/UI/ASTHRA/ASTHRADualVehicleConnection.qml", "")
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

    function showMessageDialog(dialogTitle, dialogText, buttons = Dialog.Ok, acceptFunction = null, closeFunction = null) {
        simpleMessageDialogComponent.createObject(mainWindow, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction, closeFunction: closeFunction }).open()
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        showMessageDialog(dialogTitle, dialogText)
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    property bool _forceClose: false

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

    property string closeDialogTitle: qsTr("Close %1").arg(QGroundControl.appName)

    function checkForUnsavedMission() {
        if (planView._planMasterController.dirty) {
            showMessageDialog(closeDialogTitle,
                              qsTr("You have a mission edit in progress which has not been saved/sent. If you close you will lose changes. Are you sure you want to close?"),
                              Dialog.Yes | Dialog.No,
                              function() { _closeChecksToSkip |= _skipUnsavedMissionCheckMask; performCloseChecks() })
            return false
        } else {
            return true
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                mainWindow.showMessageDialog(closeDialogTitle,
                    qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
                    Dialog.Yes | Dialog.No,
                    function() { _closeChecksToSkip |= _skipPendingParameterWritesCheckMask; performCloseChecks() })
                return false
            }
        }
        return true
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            mainWindow.showMessageDialog(closeDialogTitle,
                qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
                Dialog.Yes | Dialog.No,
                function() { _closeChecksToSkip |= _skipActiveConnectionsCheckMask; performCloseChecks() })
            return false
        } else {
            return true
        }
    }

    onClosing: (close) => {
        if (!_forceClose) {
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

        FlyView {
            id:                     flyView
            anchors.fill:           parent
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

        PlanView {
            id:             planView
            anchors.fill:   parent
            visible:        false
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

    Component {
        id: toolSelectComponent

        SelectViewDropdown {
        }
    }

    // Tool Drawer - Overlays entire ASTHRA layout when visible
    Rectangle {
        id:             toolDrawer
        anchors.fill:   parent
        visible:        false
        z:              1000  // Ensure it's on top of ASTHRA layout
        color:          qgcPal.window

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
        closeIndicatorDrawer()
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional warning message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = message
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false
            criticalVehicleMessagePopup.open()
        }
    }

    Popup {
        id:                 criticalVehicleMessagePopup
        y:                  ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal:              false
        focus:              true

        property alias  criticalVehicleMessage:             criticalVehicleMessageText.text
        property bool   additionalCriticalMessagesReceived: false

        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      vehicleWarningLabel.contentWidth + _margins
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Vehicle Error")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            Rectangle {
                id:                         additionalErrorsIndicator
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.bottom:             parent.bottom
                anchors.bottomMargin:       -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      additionalErrorsLabel.contentWidth + _margins
                height:                     additionalErrorsLabel.contentHeight + _margins
                visible:                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 additionalErrorsLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Additional errors received")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
            textFormat:         TextEdit.RichText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                criticalVehicleMessagePopup.close()
                if (criticalVehicleMessagePopup.additionalCriticalMessagesReceived) {
                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false;
                    flyView.dropMainStatusIndicatorTool();
                } else {
                    QGroundControl.multiVehicleManager.activeVehicle.resetErrorLevelMessages();
                }
            }
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

        function calcXPosition() {
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
                anchors.horizontalCenter:   backgroundRect.right
                anchors.verticalCenter:     backgroundRect.top
                width:                      ScreenTools.largeFontPixelHeight
                height:                     width
                radius:                     width / 2
                color:                      QGroundControl.globalPalette.button
                border.color:               QGroundControl.globalPalette.buttonText
                visible:                    indicatorDrawerLoader.item && indicatorDrawerLoader.item.showExpand && !indicatorDrawer._expanded

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
            implicitWidth:  Math.min(mainWindow.contentItem.width - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.width)
            implicitHeight: Math.min(mainWindow.contentItem.height - ScreenTools.toolbarHeight - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.height)
            contentWidth:   indicatorDrawerLoader.width
            contentHeight:  indicatorDrawerLoader.height

            Loader {
                id: indicatorDrawerLoader

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

    // We have to create the popup windows for the Analyze pages here so that the creation context is rooted
    // to mainWindow. Otherwise if they are rooted to the AnalyzeView itself they will die when the analyze viewSwitch
    // closes.

    function createrWindowedAnalyzePage(title, source) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.source = source
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    true

            property alias source: loader.source

            Rectangle {
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
                source = ""
            }
        }
    }
}
