/****************************************************************************
 *
 * ASTHRA - Camera Frame Capture System
 * Industrial IoT-compliant image capture during OFFBOARD mode and descent
 * Captures frames with full metadata for disaster response documentation
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls

/// Camera Frame Capture System
/// IoT-compliant image capture with metadata for industrial disaster response
QtObject {
    id: frameCapture

    property var activeVehicle: null
    property var videoManager: null
    property var telemetryLogger: null
    property var missionLogger: null

    // Capture settings
    property bool captureInOffboard: true
    property bool captureDuringDescent: true
    property int captureInterval: 2000  // Capture every 2 seconds during active capture
    property int descentCaptureInterval: 1000  // Capture every 1 second during descent

    // Storage
    property var capturedFrames: []  // Array of captured frame metadata
    property string imageStoragePath: ""
    property var captureTimer: null
    property var descentCaptureTimer: null

    // State tracking
    property bool wasInOffboard: false
    property bool wasLanding: false
    property bool isCapturing: false

    // Frame metadata structure:
    // {
    //   frameId: string (IoT-compliant UUID or timestamp-based ID),
    //   timestamp: Date (ISO 8601),
    //   timestampUTC: string,
    //   timestampLocal: string,
    //   imagePath: string,
    //   imageFileName: string,
    //   position: { lat, lon, alt, relativeAlt },
    //   attitude: { roll, pitch, yaw },
    //   flightMode: string,
    //   captureReason: string (OFFBOARD, DESCENT, MANUAL, etc.),
    //   gps: { fixType, satellites, hdop },
    //   battery: { voltage, percentRemaining },
    //   metadata: {
    //     vehicleId: int,
    //     missionId: string,
    //     frameSequence: int,
    //     iotDeviceId: string,
    //     iotTimestamp: string (ISO 8601 with milliseconds)
    //   }
    // }

    property var _lastInitializedVehicle: null

    function initialize(vehicle, videoMgr, telemetry, mission) {
        // Guard: Only initialize if vehicle actually changed
        if (vehicle === _lastInitializedVehicle) {
            return
        }

        console.log("ASTHRA Camera: Initializing frame capture system")
        console.log("ASTHRA Camera: Vehicle:", vehicle ? "Present (ID: " + vehicle.id + ")" : "Missing")
        console.log("ASTHRA Camera: VideoManager:", videoMgr ? "Present" : "Missing")
        console.log("ASTHRA Camera: TelemetryLogger:", telemetry ? "Present" : "Missing")
        console.log("ASTHRA Camera: MissionLogger:", mission ? "Present" : "Missing")

        // Disconnect previous vehicle signals first to prevent conflicts
        if (activeVehicle && activeVehicle !== vehicle) {
            try {
                if (activeVehicle.flightModeChanged) {
                    activeVehicle.flightModeChanged.disconnect(onFlightModeChanged)
                }
            } catch(e) {
                // Ignore if already disconnected
            }
        }

        // Stop any running timers
        if (captureTimer) {
            captureTimer.running = false
        }
        if (descentCaptureTimer) {
            descentCaptureTimer.running = false
        }

        _lastInitializedVehicle = vehicle
        activeVehicle = vehicle
        videoManager = videoMgr
        telemetryLogger = telemetry
        missionLogger = mission

        // Setup image storage path (IoT-compliant directory structure)
        setupImageStorage()

        // Monitor vehicle state changes
        if (activeVehicle) {
            console.log("ASTHRA Camera: Connecting to vehicle flight mode changes")
            activeVehicle.flightModeChanged.connect(onFlightModeChanged)
            console.log("ASTHRA Camera: Initial flight mode:", activeVehicle.flightMode)
            wasInOffboard = (activeVehicle.flightMode === "OFFBOARD")
            // Note: landing state is tracked via telemetry samples
        } else {
            console.log("ASTHRA Camera: WARNING - No active vehicle provided")
        }

        console.log("ASTHRA Camera: Initialization complete")
    }

    function setupImageStorage() {
        // IoT-compliant storage path structure:
        // Get base path from settings, then append our organized structure
        // Format: {basePath}/ASTHRA/images/YYYY-MM-DD/mission-{missionId}/frames/
        var now = new Date()
        var dateStr = now.toISOString().substring(0, 10)  // YYYY-MM-DD
        var missionId = missionLogger ? (missionLogger.missionStartTime ?
            missionLogger.missionStartTime.toISOString().replace(/[:.]/g, '-') :
            "mission-" + now.getTime()) : "mission-" + now.getTime()

        // Try to get photo save path from settings (via QGroundControl)
        // Default to a relative path structure if settings not available
        var basePath = ""
        try {
            // QGroundControl.settingsManager should have appSettings with photoSavePath
            if (QGroundControl.settingsManager && QGroundControl.settingsManager.appSettings) {
                basePath = QGroundControl.settingsManager.appSettings.photoSavePath || ""
            }
        } catch(e) {
            console.log("ASTHRA: Could not access settings for photo path:", e)
        }

        // Build full path
        if (basePath && basePath.length > 0) {
            // Ensure path ends with separator
            if (!basePath.endsWith("/") && !basePath.endsWith("\\")) {
                basePath += "/"
            }
            imageStoragePath = basePath + "ASTHRA/images/" + dateStr + "/" + missionId + "/frames/"
        } else {
            // Fallback: use relative path (VideoManager will use its default)
            imageStoragePath = "ASTHRA/images/" + dateStr + "/" + missionId + "/frames/"
        }

        console.log("ASTHRA: Image storage path:", imageStoragePath)
    }

    function onFlightModeChanged() {
        if (!activeVehicle) {
            console.log("ASTHRA Camera: onFlightModeChanged - no active vehicle")
            return
        }

        var currentMode = activeVehicle.flightMode
        var isInOffboard = (currentMode === "OFFBOARD")

        console.log("ASTHRA Camera: Flight mode changed to", currentMode, "wasInOffboard:", wasInOffboard, "isInOffboard:", isInOffboard)

        // Detect OFFBOARD entry
        if (!wasInOffboard && isInOffboard && captureInOffboard) {
            console.log("ASTHRA Camera: Entering OFFBOARD mode - starting capture")
            startOffboardCapture()
        }

        // Detect OFFBOARD exit
        if (wasInOffboard && !isInOffboard) {
            console.log("ASTHRA Camera: Exiting OFFBOARD mode - stopping capture")
            stopOffboardCapture()
        }

        wasInOffboard = isInOffboard
    }

    function startOffboardCapture() {
        if (isCapturing) return

        console.log("ASTHRA: Starting OFFBOARD frame capture")
        isCapturing = true

        // Create capture timer for OFFBOARD mode
        if (!captureTimer) {
            captureTimer = Qt.createQmlObject("import QtQuick; Timer { repeat: true }", frameCapture)
            captureTimer.triggered.connect(captureFrame)
        }
        captureTimer.interval = captureInterval
        captureTimer.running = true

        // Capture immediately
        captureFrame("OFFBOARD_ENTRY")
    }

    function stopOffboardCapture() {
        if (captureTimer) {
            captureTimer.running = false
        }
        isCapturing = false
        console.log("ASTHRA: Stopped OFFBOARD frame capture")
    }

    function startDescentCapture() {
        if (!captureDuringDescent) return

        console.log("ASTHRA: Starting descent frame capture")

        // Create descent capture timer
        if (!descentCaptureTimer) {
            descentCaptureTimer = Qt.createQmlObject("import QtQuick; Timer { repeat: true }", frameCapture)
            descentCaptureTimer.triggered.connect(function() { captureFrame("DESCENT") })
        }
        descentCaptureTimer.interval = descentCaptureInterval
        descentCaptureTimer.running = true

        // Capture immediately when descent starts
        captureFrame("DESCENT_START")
    }

    function stopDescentCapture() {
        if (descentCaptureTimer) {
            descentCaptureTimer.running = false
        }
        console.log("ASTHRA: Stopped descent frame capture")
    }

    function checkDescentState() {
        if (!activeVehicle || !telemetryLogger) return

        var samples = telemetryLogger.getSamples()
        if (samples.length < 2) return

        // Check if vehicle is descending (negative climb rate or landing state)
        var isLanding = activeVehicle.landing || false
        var currentSample = samples[samples.length - 1]
        var previousSample = samples[samples.length - 2]

        var isDescending = false
        if (currentSample && previousSample && currentSample.velocity) {
            var climbRate = currentSample.velocity.climbRate || 0
            isDescending = climbRate < -0.5  // Descending faster than 0.5 m/s
        }

        if ((isLanding || isDescending) && !wasLanding) {
            wasLanding = true
            startDescentCapture()
        } else if (!isLanding && !isDescending && wasLanding) {
            wasLanding = false
            stopDescentCapture()
        }
    }

    function captureFrame(reason) {
        console.log("ASTHRA Camera: captureFrame called with reason:", reason)

        if (!videoManager) {
            console.log("ASTHRA Camera: ERROR - VideoManager not available")
            return
        }

        if (!activeVehicle) {
            console.log("ASTHRA Camera: ERROR - Active vehicle not available")
            return
        }

        // Check if video is available
        console.log("ASTHRA Camera: VideoManager.hasVideo:", videoManager.hasVideo)
        console.log("ASTHRA Camera: VideoManager.streaming:", videoManager.streaming)

        if (!videoManager.hasVideo || !videoManager.streaming) {
            console.log("ASTHRA Camera: Video not available - hasVideo:", videoManager.hasVideo, "streaming:", videoManager.streaming)
            return
        }

        // Generate IoT-compliant frame ID (ISO 8601 timestamp-based)
        var now = new Date()
        var frameId = generateIoTFrameId(now)
        var timestampUTC = now.toISOString()
        var timestampLocal = now.toLocaleString()

        // Generate IoT-compliant filename
        var fileName = generateIoTFileName(frameId, reason)
        console.log("ASTHRA Camera: Generated filename:", fileName)

        // Get photo save path from settings (VideoManager uses this internally)
        // We'll let VideoManager handle the path, but store our custom path in metadata
        var fullPath = imageStoragePath + fileName
        console.log("ASTHRA Camera: Full image path:", fullPath)
        console.log("ASTHRA Camera: Image storage path:", imageStoragePath)

        // Get current telemetry data
        var telemetryData = getCurrentTelemetryData()
        console.log("ASTHRA Camera: Telemetry data retrieved - Position:", telemetryData.position.lat, telemetryData.position.lon)

        // Capture frame using VideoManager
        // Note: VideoManager.grabImage() will use settings path if empty,
        // but we pass our custom path for proper organization
        try {
            console.log("ASTHRA Camera: Calling videoManager.grabImage with path:", fullPath)
            // Use full absolute path - VideoManager will save to this location
            // If the directory doesn't exist, VideoManager will use default path
            // but we'll still track our intended path in metadata
            videoManager.grabImage(fullPath)
            console.log("ASTHRA Camera: grabImage call completed")

            // Create frame metadata (IoT-compliant structure)
            var frameMetadata = {
                frameId: frameId,
                timestamp: now,
                timestampUTC: timestampUTC,
                timestampLocal: timestampLocal,
                imagePath: fullPath,
                imageFileName: fileName,
                position: telemetryData.position,
                attitude: telemetryData.attitude,
                flightMode: activeVehicle.flightMode,
                captureReason: reason || "AUTO",
                gps: telemetryData.gps,
                battery: telemetryData.battery,
                metadata: {
                    vehicleId: activeVehicle.id,
                    missionId: missionLogger ? (missionLogger.missionStartTime ?
                        missionLogger.missionStartTime.toISOString() : "unknown") : "unknown",
                    frameSequence: capturedFrames.length + 1,
                    iotDeviceId: "ASTHRA-GC-" + activeVehicle.id,
                    iotTimestamp: timestampUTC,
                    iotProtocol: "MAVLink",
                    iotStandard: "ISO 8601",
                    captureMode: reason || "AUTO"
                }
            }

            capturedFrames.push(frameMetadata)
            console.log("ASTHRA: Frame captured:", frameId, "Reason:", reason)

            // Emit signal for UI updates
            frameCaptured(frameMetadata)
        } catch (e) {
            console.log("ASTHRA: Error capturing frame:", e)
        }
    }

    function getCurrentTelemetryData() {
        var data = {
            position: { lat: 0, lon: 0, alt: 0, relativeAlt: 0 },
            attitude: { roll: 0, pitch: 0, yaw: 0 },
            gps: { fixType: 0, satellites: 0, hdop: 0 },
            battery: { voltage: 0, percentRemaining: 0 }
        }

        if (!activeVehicle) return data

        // Get position
        data.position = {
            lat: activeVehicle.latitude,
            lon: activeVehicle.longitude,
            alt: activeVehicle.altitudeAMSL.value,
            relativeAlt: activeVehicle.altitudeRelative.value
        }

        // Get attitude
        data.attitude = {
            roll: activeVehicle.roll.value,
            pitch: activeVehicle.pitch.value,
            yaw: activeVehicle.yaw.value
        }

        // Get GPS data
        if (activeVehicle.gps) {
            data.gps = {
                fixType: activeVehicle.gps.lock.value,
                satellites: activeVehicle.gps.count.value,
                hdop: activeVehicle.gps.hdop.value
            }
        }

        // Get battery data
        if (activeVehicle.batteries && activeVehicle.batteries.length > 0) {
            var battery = activeVehicle.batteries[0]
            data.battery = {
                voltage: battery.voltage.value,
                percentRemaining: battery.percentRemaining.value
            }
        }

        return data
    }

    function generateIoTFrameId(timestamp) {
        // IoT-compliant frame ID: ISO 8601 format with milliseconds
        // Format: YYYY-MM-DDTHH:mm:ss.sssZ
        var isoString = timestamp.toISOString()
        // Remove colons and dots for filesystem compatibility, keep as ID
        return "FRAME-" + isoString.replace(/[:.]/g, '-').replace('T', '-').replace('Z', '')
    }

    function generateIoTFileName(frameId, reason) {
        // IoT-compliant filename structure:
        // {frameId}_{reason}_{sequence}.jpg
        var sequence = String(capturedFrames.length + 1).padStart(6, '0')
        return frameId + "_" + (reason || "AUTO") + "_" + sequence + ".jpg"
    }

    function getFramesByReason(reason) {
        return capturedFrames.filter(function(f) {
            return f.captureReason === reason || f.captureReason.indexOf(reason) >= 0
        })
    }

    function getDescentFrames() {
        return getFramesByReason("DESCENT")
    }

    function getOffboardFrames() {
        return getFramesByReason("OFFBOARD")
    }

    function getAllFrames() {
        return capturedFrames
    }

    function getFrameMetadata(frameId) {
        for (var i = 0; i < capturedFrames.length; i++) {
            if (capturedFrames[i].frameId === frameId) {
                return capturedFrames[i]
            }
        }
        return null
    }

    function exportFrameMetadataJSON() {
        return JSON.stringify({
            metadataVersion: "1.0",
            iotStandard: "ISO 8601",
            captureSystem: "ASTHRA-GC",
            totalFrames: capturedFrames.length,
            frames: capturedFrames.map(function(f) {
                return {
                    frameId: f.frameId,
                    timestamp: f.timestampUTC,
                    imagePath: f.imagePath,
                    position: f.position,
                    flightMode: f.flightMode,
                    captureReason: f.captureReason,
                    metadata: f.metadata
                }
            })
        }, null, 2)
    }

    function exportFrameMetadataCSV() {
        var csv = "Frame ID,Timestamp UTC,Image Path,Latitude,Longitude,Altitude,Flight Mode,Capture Reason,Vehicle ID,Mission ID,Frame Sequence\n"

        for (var i = 0; i < capturedFrames.length; i++) {
            var f = capturedFrames[i]
            csv += f.frameId + "," +
                   f.timestampUTC + "," +
                   f.imagePath + "," +
                   f.position.lat + "," +
                   f.position.lon + "," +
                   f.position.alt + "," +
                   f.flightMode + "," +
                   f.captureReason + "," +
                   f.metadata.vehicleId + "," +
                   f.metadata.missionId + "," +
                   f.metadata.frameSequence + "\n"
        }

        return csv
    }

    // Periodic check for descent state (called from telemetry logger or external timer)
    function updateDescentState() {
        checkDescentState()
    }

    function clearFrames() {
        capturedFrames = []
    }

    signal frameCaptured(var frameMetadata)
}

