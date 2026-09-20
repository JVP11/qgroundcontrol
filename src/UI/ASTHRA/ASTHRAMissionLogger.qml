/****************************************************************************
 *
 * ASTHRA - Mission Event Logger
 * Comprehensive mission event tracking and log storage
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Mission Event Logger - Tracks all mission-critical events
QtObject {
    id: missionLogger

    property var activeVehicle: null
    property var missionEvents: []  // Complete mission event log
    property var missionStartTime: null
    property var missionEndTime: null
    property bool missionActive: false
    property var telemetryLogger: null  // Reference to telemetry logger

    // Event structure:
    // {
    //   timestamp: Date,
    //   eventType: string,
    //   latitude: real,
    //   longitude: real,
    //   altitude: real,
    //   data: object (event-specific data)
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
                if (activeVehicle.armedChanged) {
                    activeVehicle.armedChanged.disconnect(onArmedChanged)
                }
                if (activeVehicle.flightModeChanged) {
                    activeVehicle.flightModeChanged.disconnect(onFlightModeChanged)
                }
                if (activeVehicle.failsafeChanged) {
                    activeVehicle.failsafeChanged.disconnect(onFailsafeChanged)
                }
            } catch(e) {
                // Ignore if already disconnected
            }
        }

        _lastInitializedVehicle = vehicle
        activeVehicle = vehicle
        if (activeVehicle) {
            try { activeVehicle.armedChanged.connect(onArmedChanged) } catch (e) {}
            try { activeVehicle.flightModeChanged.connect(onFlightModeChanged) } catch (e) {}
            if (activeVehicle.failsafeChanged)
                try { activeVehicle.failsafeChanged.connect(onFailsafeChanged) } catch (e) {}
        }
    }

    function setTelemetryLogger(logger) {
        telemetryLogger = logger
        if (telemetryLogger && activeVehicle) {
            telemetryLogger.initialize(activeVehicle)
        }
    }

    function startMission() {
        missionStartTime = new Date()
        missionActive = true
        missionEvents = []

        // Start telemetry logging if available
        if (telemetryLogger) {
            telemetryLogger.startLogging()
        }

        logEvent("MISSION_START", {
            vehicleId: activeVehicle ? activeVehicle.id : 0,
            startTime: missionStartTime.toISOString()
        })
    }

    function endMission() {
        missionEndTime = new Date()
        missionActive = false

        // Stop telemetry logging if available
        if (telemetryLogger) {
            telemetryLogger.stopLogging()
        }

        logEvent("MISSION_END", {
            endTime: missionEndTime.toISOString(),
            duration: getMissionDuration()
        })
    }

    function onArmedChanged() {
        if (!activeVehicle) return

        var eventType = activeVehicle.armed ? "VEHICLE_ARMED" : "VEHICLE_DISARMED"
        logEvent(eventType, {
            armed: activeVehicle.armed
        })
    }

    function onFlightModeChanged() {
        if (!activeVehicle) return

        logEvent("FLIGHT_MODE_CHANGE", {
            mode: activeVehicle.flightMode,
            latitude: activeVehicle.latitude.value,
            longitude: activeVehicle.longitude.value,
            altitude: activeVehicle.altitudeAMSL.value
        })
    }

    function onFailsafeChanged() {
        if (!activeVehicle) return

        if (activeVehicle.failsafe) {
            logEvent("FAILSAFE_ACTIVATED", {
                latitude: activeVehicle.latitude.value,
                longitude: activeVehicle.longitude.value,
                altitude: activeVehicle.altitudeAMSL.value
            })
        }
    }

    function logOffboardEvent(event) {
        // Add Google Maps URL to the event data
        var googleMapsURL = ""
        if (event.gcsLatitude && event.gcsLongitude && event.latitude && event.longitude) {
            googleMapsURL = "https://www.google.com/maps/dir/" + event.gcsLatitude.toFixed(6) + "," + event.gcsLongitude.toFixed(6) + "/" + event.latitude.toFixed(6) + "," + event.longitude.toFixed(6)
        }

        logEvent(event.eventType, {
            reason: event.reason,
            previousMode: event.previousMode,
            currentMode: event.currentMode,
            latitude: event.latitude,
            longitude: event.longitude,
            altitude: event.altitude,
            // Rescue information with proper field names
            distanceMeters: event.distanceMeters || 0,
            distanceText: event.distanceText || "N/A",
            directionDegrees: event.directionDegrees || 0,
            directionText: event.directionText || "N/A",
            gcsLatitude: event.gcsLatitude || 0,
            gcsLongitude: event.gcsLongitude || 0,
            gcsAltitude: event.gcsAltitude || 0,
            googleMapsURL: googleMapsURL,
            // Legacy field names for compatibility
            distanceFromGCS: event.distanceMeters || event.distanceFromGCS || 0,
            directionFromGCS: event.directionDegrees || event.directionFromGCS || 0
        })
    }

    function generateRescueReport() {
        var offboardEvents = getOffboardEvents()
        if (offboardEvents.length === 0) {
            return null
        }

        var report = {
            reportType: "RESCUE_REPORT",
            generatedAt: new Date().toISOString(),
            vehicleId: activeVehicle ? activeVehicle.id : 0,
            missionStartTime: missionStartTime ? missionStartTime.toISOString() : null,
            missionEndTime: missionEndTime ? missionEndTime.toISOString() : null,
            offboardEvents: [],
            summary: {
                totalOffboardExits: 0,
                totalOffboardEntries: 0,
                criticalExits: []  // Exits with link loss or failsafe
            }
        }

        for (var i = 0; i < offboardEvents.length; i++) {
            var event = offboardEvents[i]
            var eventData = event.data || {}

            if (event.eventType === "OFFBOARD_EXIT") {
                report.summary.totalOffboardExits++

                var exitEvent = {
                    timestamp: event.timestamp.toISOString(),
                    latitude: eventData.latitude || event.latitude,
                    longitude: eventData.longitude || event.longitude,
                    altitude: eventData.altitude || event.altitude,
                    reason: eventData.reason || "UNKNOWN",
                    distanceFromGCS: eventData.distanceFromGCS || 0,
                    directionFromGCS: eventData.directionFromGCS || 0,
                    directionText: eventData.directionText || "N/A",
                    distanceText: eventData.distanceText || "N/A",
                    gcsLatitude: eventData.gcsLatitude || 0,
                    gcsLongitude: eventData.gcsLongitude || 0,
                    gcsAltitude: eventData.gcsAltitude || 0
                }

                report.offboardEvents.push(exitEvent)

                // Mark critical exits (link loss or failsafe)
                if (eventData.reason === "LINK_LOSS" || eventData.reason === "FAILSAFE") {
                    report.summary.criticalExits.push(exitEvent)
                }
            } else if (event.eventType === "OFFBOARD_ENTRY") {
                report.summary.totalOffboardEntries++
            }
        }

        return report
    }

    function exportRescueReportJSON() {
        var report = generateRescueReport()
        if (!report) return null

        // Add Google Maps URLs to each event
        for (var i = 0; i < report.offboardEvents.length; i++) {
            var event = report.offboardEvents[i]
            event.googleMapsURL = generateGoogleMapsURL(event.gcsLatitude, event.gcsLongitude, event.latitude, event.longitude)
        }

        return JSON.stringify(report, null, 2)
    }

    function exportRescueReportCSV() {
        var offboardEvents = getOffboardEvents()
        if (offboardEvents.length === 0) return null

        var csv = "Timestamp,Event Type,Latitude,Longitude,Altitude (m),Reason,Distance from GCS (m),Direction from GCS (deg),Direction Text,Distance Text,GCS Latitude,GCS Longitude,GCS Altitude,Google Maps URL\n"

        for (var i = 0; i < offboardEvents.length; i++) {
            var event = offboardEvents[i]
            var eventData = event.data || {}

            if (event.eventType === "OFFBOARD_EXIT") {
                var timestamp = event.timestamp.toISOString()
                var lat = eventData.latitude || event.latitude || 0
                var lon = eventData.longitude || event.longitude || 0
                var alt = eventData.altitude || event.altitude || 0
                var reason = eventData.reason || "UNKNOWN"
                var dist = eventData.distanceFromGCS || 0
                var dir = eventData.directionFromGCS || 0
                var dirText = (eventData.directionText || "N/A").replace(/,/g, ";")
                var distText = eventData.distanceText || "N/A"
                var gcsLat = eventData.gcsLatitude || 0
                var gcsLon = eventData.gcsLongitude || 0
                var gcsAlt = eventData.gcsAltitude || 0
                var googleMapsUrl = generateGoogleMapsURL(gcsLat, gcsLon, lat, lon)

                csv += timestamp + "," + event.eventType + "," + lat + "," + lon + "," + alt + "," + reason + "," + dist + "," + dir + "," + dirText + "," + distText + "," + gcsLat + "," + gcsLon + "," + gcsAlt + "," + googleMapsUrl + "\n"
            }
        }

        return csv
    }

    function generateGoogleMapsURL(gcsLat, gcsLon, exitLat, exitLon) {
        if (!gcsLat || !gcsLon || !exitLat || !exitLon) {
            return "N/A"
        }
        // Google Maps URL with directions from base to exit point
        return "https://www.google.com/maps/dir/" + gcsLat + "," + gcsLon + "/" + exitLat + "," + exitLon
    }

    function generateRescueLogReport() {
        var report = generateRescueReport()
        if (!report) return null

        var log = "================================================================================\n"
        log += "ASTHRA RESCUE LOG REPORT\n"
        log += "================================================================================\n"
        log += "Generated: " + new Date().toISOString() + "\n"
        log += "Vehicle ID: " + (activeVehicle ? activeVehicle.id : "N/A") + "\n"
        log += "Mission Start: " + (report.missionStartTime || "N/A") + "\n"
        log += "Mission End: " + (report.missionEndTime || "N/A") + "\n"
        log += "================================================================================\n"
        log += "SUMMARY\n"
        log += "================================================================================\n"
        log += "Total OFFBOARD Exits: " + report.summary.totalOffboardExits + "\n"
        log += "Total OFFBOARD Entries: " + report.summary.totalOffboardEntries + "\n"
        log += "Critical Exits (Link Loss/Failsafe): " + report.summary.criticalExits.length + "\n"
        log += "================================================================================\n"
        log += "OFFBOARD EXIT EVENTS\n"
        log += "================================================================================\n\n"

        for (var i = 0; i < report.offboardEvents.length; i++) {
            var event = report.offboardEvents[i]
            log += "EVENT #" + (i + 1) + "\n"
            log += "--------------------------------------------------------------------------------\n"
            log += "Timestamp: " + event.timestamp + "\n"
            log += "Reason: " + event.reason + "\n"
            log += "Coordinates:\n"
            log += "  Latitude:  " + event.latitude.toFixed(6) + "°\n"
            log += "  Longitude: " + event.longitude.toFixed(6) + "°\n"
            log += "  Altitude:  " + event.altitude.toFixed(2) + " m\n"
            log += "Base Station (GCS):\n"
            log += "  Latitude:  " + event.gcsLatitude.toFixed(6) + "°\n"
            log += "  Longitude: " + event.gcsLongitude.toFixed(6) + "°\n"
            log += "  Altitude:  " + event.gcsAltitude.toFixed(2) + " m\n"
            log += "Distance from Base: " + event.distanceText + " (" + event.distanceFromGCS.toFixed(2) + " m)\n"
            log += "Direction from Base: " + event.directionText + "\n"
            log += "Google Maps Route: " + generateGoogleMapsURL(event.gcsLatitude, event.gcsLongitude, event.latitude, event.longitude) + "\n"
            log += "\n"
        }

        if (report.summary.criticalExits.length > 0) {
            log += "================================================================================\n"
            log += "CRITICAL EXITS (REQUIRES IMMEDIATE ATTENTION)\n"
            log += "================================================================================\n\n"

            for (var j = 0; j < report.summary.criticalExits.length; j++) {
                var criticalEvent = report.summary.criticalExits[j]
                log += "CRITICAL EVENT #" + (j + 1) + "\n"
                log += "--------------------------------------------------------------------------------\n"
                log += "Timestamp: " + criticalEvent.timestamp + "\n"
                log += "Reason: " + criticalEvent.reason + " (CRITICAL)\n"
                log += "Coordinates: " + criticalEvent.latitude.toFixed(6) + ", " + criticalEvent.longitude.toFixed(6) + "\n"
                log += "Altitude: " + criticalEvent.altitude.toFixed(2) + " m\n"
                log += "Distance: " + criticalEvent.distanceText + "\n"
                log += "Direction: " + criticalEvent.directionText + "\n"
                log += "Google Maps: " + generateGoogleMapsURL(criticalEvent.gcsLatitude, criticalEvent.gcsLongitude, criticalEvent.latitude, criticalEvent.longitude) + "\n"
                log += "\n"
            }
        }

        log += "================================================================================\n"
        log += "END OF REPORT\n"
        log += "================================================================================\n"

        return log
    }

    function logEvent(eventType, data) {
        if (!activeVehicle) return

        var event = {
            timestamp: new Date(),
            eventType: eventType,
            latitude: activeVehicle.latitude.value,
            longitude: activeVehicle.longitude.value,
            altitude: activeVehicle.altitudeAMSL.value,
            data: data || {}
        }

        missionEvents.push(event)
        console.log("ASTHRA: Event logged", eventType, JSON.stringify(data))

        eventLogged(event)
    }

    function getMissionDuration() {
        if (!missionStartTime) return 0
        var end = missionEndTime || new Date()
        return (end.getTime() - missionStartTime.getTime()) / 1000  // seconds
    }

    function getEventLog() {
        return missionEvents
    }

    function getOffboardEvents() {
        return missionEvents.filter(function(event) {
            return event.eventType === "OFFBOARD_ENTRY" || event.eventType === "OFFBOARD_EXIT"
        })
    }

    function clearLog() {
        missionEvents = []
        missionStartTime = null
        missionEndTime = null
        missionActive = false
    }

    signal eventLogged(var event)
}


