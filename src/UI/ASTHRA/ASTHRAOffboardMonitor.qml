/****************************************************************************
 *
 * ASTHRA - OFFBOARD Mode Monitor
 * Detects OFFBOARD mode transitions and captures critical events
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls

/// OFFBOARD Mode Monitor - Detects transitions and captures events
QtObject {
    id: offboardMonitor

    property var activeVehicle: null
    property bool wasInOffboard: false
    property var eventLog: []  // Array of OFFBOARD events

    // Event structure:
    // {
    //   timestamp: Date,
    //   latitude: real,
    //   longitude: real,
    //   altitude: real,
    //   reason: string,
    //   previousMode: string,
    //   currentMode: string
    // }

    property var _lastInitializedVehicle: null

    function initialize(vehicle) {
        // Guard: Only initialize if vehicle actually changed
        if (vehicle === _lastInitializedVehicle) {
            return
        }

        // Disconnect previous vehicle signals first
        if (activeVehicle && activeVehicle !== vehicle) {
            try {
                if (activeVehicle.flightModeChanged) {
                    activeVehicle.flightModeChanged.disconnect(onFlightModeChanged)
                }
            } catch(e) {
                // Ignore if already disconnected
            }
        }

        _lastInitializedVehicle = vehicle
        activeVehicle = vehicle
        if (activeVehicle) {
            wasInOffboard = (activeVehicle.flightMode === "OFFBOARD")
            activeVehicle.flightModeChanged.connect(onFlightModeChanged)
        }
    }

    function onFlightModeChanged() {
        if (!activeVehicle) return

        var currentMode = activeVehicle.flightMode
        var isInOffboard = (currentMode === "OFFBOARD")

        // Detect OFFBOARD exit
        if (wasInOffboard && !isInOffboard) {
            captureOffboardExit()
        }

        // Detect OFFBOARD entry
        if (!wasInOffboard && isInOffboard) {
            captureOffboardEntry()
        }

        wasInOffboard = isInOffboard
    }

    function captureOffboardExit() {
        if (!activeVehicle) return

        // Get GCS position for distance and direction calculation
        var gcsPosition = QGroundControl.qgcPositionManger.gcsPosition
        var vehicleLat = activeVehicle.latitude.value
        var vehicleLon = activeVehicle.longitude.value
        var vehicleAlt = activeVehicle.altitudeAMSL.value

        // Calculate distance and direction from GCS
        var distanceFromGCS = 0
        var directionFromGCS = 0
        var gcsLat = 0
        var gcsLon = 0
        var gcsAlt = 0

        if (gcsPosition && gcsPosition.isValid) {
            gcsLat = gcsPosition.latitude
            gcsLon = gcsPosition.longitude
            gcsAlt = gcsPosition.altitude

            var vehicleCoord = QtPositioning.coordinate(vehicleLat, vehicleLon, vehicleAlt)
            var gcsCoord = QtPositioning.coordinate(gcsLat, gcsLon, gcsAlt)
            distanceFromGCS = gcsCoord.distanceTo(vehicleCoord)  // Distance in meters
            directionFromGCS = gcsCoord.azimuthTo(vehicleCoord)  // Bearing in degrees (0-360)
        } else {
            // Fallback: use vehicle's own distance/heading facts if available
            try {
                if (activeVehicle.distanceToGCS && !isNaN(activeVehicle.distanceToGCS.value)) {
                    distanceFromGCS = activeVehicle.distanceToGCS.value
                }
                if (activeVehicle.headingFromGCS && !isNaN(activeVehicle.headingFromGCS.value)) {
                    directionFromGCS = activeVehicle.headingFromGCS.value
                }
            } catch(e) {
                console.log("ASTHRA: Could not access vehicle distance/heading facts")
            }
        }

        var event = {
            timestamp: new Date(),
            latitude: activeVehicle.latitude.value,
            longitude: activeVehicle.longitude.value,
            altitude: activeVehicle.altitudeAMSL.value,
            reason: determineExitReason(),
            previousMode: "OFFBOARD",
            currentMode: activeVehicle.flightMode,
            eventType: "OFFBOARD_EXIT",
            // Rescue information
            distanceFromGCS: distanceFromGCS,  // Distance in meters
            directionFromGCS: directionFromGCS,  // Bearing in degrees
            gcsLatitude: gcsLat,
            gcsLongitude: gcsLon,
            gcsAltitude: gcsAlt,
            directionText: formatDirection(directionFromGCS),
            distanceText: formatDistance(distanceFromGCS)
        }

        eventLog.push(event)
        console.log("ASTHRA: OFFBOARD EXIT captured", JSON.stringify(event))

        // Emit signal for UI updates
        offboardExitDetected(event)
    }

    function formatDirection(bearing) {
        if (isNaN(bearing) || bearing < 0) return "N/A"

        var directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        var index = Math.round(bearing / 22.5) % 16
        return directions[index] + " (" + bearing.toFixed(1) + "°)"
    }

    function formatDistance(meters) {
        if (isNaN(meters) || meters < 0) return "N/A"

        if (meters < 1000) {
            return meters.toFixed(0) + " m"
        } else {
            return (meters / 1000).toFixed(2) + " km"
        }
    }

    function captureOffboardEntry() {
        if (!activeVehicle) return

        var event = {
            timestamp: new Date(),
            latitude: activeVehicle.latitude.value,
            longitude: activeVehicle.longitude.value,
            altitude: activeVehicle.altitudeAMSL.value,
            reason: "MANUAL_ENTRY",
            previousMode: wasInOffboard ? "OFFBOARD" : activeVehicle.flightMode,
            currentMode: "OFFBOARD",
            eventType: "OFFBOARD_ENTRY"
        }

        eventLog.push(event)
        console.log("ASTHRA: OFFBOARD ENTRY captured", JSON.stringify(event))

        offboardEntryDetected(event)
    }

    function determineExitReason() {
        if (!activeVehicle) return "UNKNOWN"

        // Check for communication loss
        if (activeVehicle.vehicleLinkManager.communicationLost) {
            return "LINK_LOSS"
        }

        // Check for failsafe
        if (activeVehicle.failsafe) {
            return "FAILSAFE"
        }

        // Check for timeout (if vehicle reports it)
        // This would require checking vehicle-specific parameters

        // Check if mode was manually changed
        if (activeVehicle.flightMode !== "OFFBOARD") {
            return "MODE_CHANGE"
        }

        return "UNKNOWN"
    }

    function getEventLog() {
        return eventLog
    }

    function clearEventLog() {
        eventLog = []
    }

    signal offboardExitDetected(var event)
    signal offboardEntryDetected(var event)
}


