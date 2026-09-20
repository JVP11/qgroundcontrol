/****************************************************************************
 *
 * ASTHRA - Telemetry Data Logger
 * Captures periodic telemetry samples for comprehensive mission reporting
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls

/// Telemetry Logger - Captures periodic telemetry samples
QtObject {
    id: telemetryLogger

    property var activeVehicle: null
    property var telemetrySamples: []  // Array of telemetry samples
    property int sampleInterval: 1000  // Sample every 1 second (ms)
    property var sampleTimer: null
    property var frameCapture: null  // Reference to camera frame capture system

    // Sample structure:
    // {
    //   timestamp: Date,
    //   position: { lat, lon, alt, relativeAlt },
    //   gps: { fixType, satellites, hdop, vdop },
    //   battery: { voltage, current, percentRemaining, mahConsumed, temperature },
    //   link: { rcRSSI, telemetryRRSSI, telemetryLRSSI, messagesReceived, messagesSent, messagesLost },
    //   sensors: { imuHealthy, compassHealthy, barometerHealthy, gpsHealthy },
    //   attitude: { roll, pitch, yaw },
    //   velocity: { groundSpeed, airSpeed, climbRate },
    //   heading: real
    // }

    property var _lastInitializedVehicle: null

    function initialize(vehicle) {
        // Guard: Only initialize if vehicle actually changed
        if (vehicle === _lastInitializedVehicle) {
            return
        }

        // Stop previous timer if exists
        if (sampleTimer) {
            sampleTimer.running = false
            sampleTimer.triggered.disconnect(captureSample)
            sampleTimer.destroy()
            sampleTimer = null
        }

        _lastInitializedVehicle = vehicle
        activeVehicle = vehicle
        if (activeVehicle) {
            sampleTimer = Qt.createQmlObject("import QtQuick; Timer { interval: " + sampleInterval + "; repeat: true; running: false }", telemetryLogger)
            sampleTimer.triggered.connect(captureSample)
        }
    }

    function startLogging() {
        telemetrySamples = []
        if (sampleTimer) {
            sampleTimer.running = true
        }
    }

    function stopLogging() {
        if (sampleTimer) {
            sampleTimer.running = false
        }
    }

    function captureSample() {
        if (!activeVehicle) return

        // Notify frame capture system to check descent state
        if (frameCapture) {
            frameCapture.updateDescentState()
        }

        var battery = null
        if (activeVehicle.batteries && activeVehicle.batteries.length > 0) {
            var primaryBattery = activeVehicle.batteries[0]
            battery = {
                voltage: primaryBattery.voltage.value,
                current: primaryBattery.current.value,
                percentRemaining: primaryBattery.percentRemaining.value,
                mahConsumed: primaryBattery.mahConsumed.value,
                temperature: primaryBattery.temperature.value
            }
        }

        var gps = null
        if (activeVehicle.gps) {
            gps = {
                fixType: activeVehicle.gps.lock.value,
                satellites: activeVehicle.gps.count.value,
                hdop: activeVehicle.gps.hdop.value,
                vdop: activeVehicle.gps.vdop.value
            }
        }

        var sensors = {
            imuHealthy: (activeVehicle.sensorsHealthBits & 0x01) !== 0,
            compassHealthy: (activeVehicle.sensorsHealthBits & 0x02) !== 0,
            barometerHealthy: (activeVehicle.sensorsHealthBits & 0x04) !== 0,
            gpsHealthy: (activeVehicle.sensorsHealthBits & 0x08) !== 0
        }

        var sample = {
            timestamp: new Date(),
            position: {
                lat: activeVehicle.latitude,
                lon: activeVehicle.longitude,
                alt: activeVehicle.altitudeAMSL.value,
                relativeAlt: activeVehicle.altitudeRelative.value
            },
            gps: gps,
            battery: battery,
            link: {
                rcRSSI: activeVehicle.rcRSSI,
                telemetryRRSSI: activeVehicle.telemetryRRSSI,
                telemetryLRSSI: activeVehicle.telemetryLRSSI,
                messagesReceived: activeVehicle.messagesReceived,
                messagesSent: activeVehicle.messagesSent,
                messagesLost: activeVehicle.messagesLost
            },
            sensors: sensors,
            attitude: {
                roll: activeVehicle.roll.value,
                pitch: activeVehicle.pitch.value,
                yaw: activeVehicle.yaw.value
            },
            velocity: {
                groundSpeed: activeVehicle.groundSpeed.value,
                airSpeed: activeVehicle.airSpeed.value,
                climbRate: activeVehicle.climbRate.value
            },
            heading: activeVehicle.heading.value,
            flightMode: activeVehicle.flightMode,
            armed: activeVehicle.armed
        }

        telemetrySamples.push(sample)
    }

    function getSamples() {
        return telemetrySamples
    }

    function clearSamples() {
        telemetrySamples = []
    }

    function getBatteryProfile() {
        if (telemetrySamples.length === 0) return null

        var voltages = []
        var currents = []
        var percentages = []
        var timestamps = []

        for (var i = 0; i < telemetrySamples.length; i++) {
            var sample = telemetrySamples[i]
            if (sample.battery) {
                timestamps.push(sample.timestamp.getTime())
                voltages.push(sample.battery.voltage)
                currents.push(sample.battery.current)
                percentages.push(sample.battery.percentRemaining)
            }
        }

        return {
            timestamps: timestamps,
            voltages: voltages,
            currents: currents,
            percentages: percentages,
            minVoltage: Math.min.apply(null, voltages.filter(function(v) { return !isNaN(v) })),
            maxVoltage: Math.max.apply(null, voltages.filter(function(v) { return !isNaN(v) })),
            avgVoltage: voltages.reduce(function(a, b) { return (isNaN(a) ? 0 : a) + (isNaN(b) ? 0 : b); }, 0) / voltages.length,
            minCurrent: Math.min.apply(null, currents.filter(function(c) { return !isNaN(c) })),
            maxCurrent: Math.max.apply(null, currents.filter(function(c) { return !isNaN(c) })),
            avgCurrent: currents.reduce(function(a, b) { return (isNaN(a) ? 0 : a) + (isNaN(b) ? 0 : b); }, 0) / currents.length,
            totalConsumption: telemetrySamples.length > 0 && telemetrySamples[telemetrySamples.length - 1].battery ?
                             telemetrySamples[telemetrySamples.length - 1].battery.mahConsumed : 0
        }
    }

    function getAltitudeProfile() {
        if (telemetrySamples.length === 0) return null

        var altitudes = []
        for (var i = 0; i < telemetrySamples.length; i++) {
            var alt = telemetrySamples[i].position.alt
            if (!isNaN(alt)) {
                altitudes.push(alt)
            }
        }

        if (altitudes.length === 0) return null

        return {
            min: Math.min.apply(null, altitudes),
            max: Math.max.apply(null, altitudes),
            avg: altitudes.reduce(function(a, b) { return a + b; }, 0) / altitudes.length,
            samples: altitudes
        }
    }

    function getSpeedProfile() {
        if (telemetrySamples.length === 0) return null

        var speeds = []
        for (var i = 0; i < telemetrySamples.length; i++) {
            var speed = telemetrySamples[i].velocity.groundSpeed
            if (!isNaN(speed)) {
                speeds.push(speed)
            }
        }

        if (speeds.length === 0) return null

        return {
            min: Math.min.apply(null, speeds),
            max: Math.max.apply(null, speeds),
            avg: speeds.reduce(function(a, b) { return a + b; }, 0) / speeds.length,
            samples: speeds
        }
    }

    function getLinkQualityProfile() {
        if (telemetrySamples.length === 0) return null

        var rcRSSIs = []
        var telemRSSIs = []
        var messageLossRates = []

        for (var i = 0; i < telemetrySamples.length; i++) {
            var sample = telemetrySamples[i]
            if (sample.link) {
                if (!isNaN(sample.link.rcRSSI)) rcRSSIs.push(sample.link.rcRSSI)
                if (!isNaN(sample.link.telemetryRRSSI)) telemRSSIs.push(sample.link.telemetryRRSSI)

                var total = sample.link.messagesReceived + sample.link.messagesLost
                if (total > 0) {
                    messageLossRates.push((sample.link.messagesLost / total) * 100)
                }
            }
        }

        return {
            rcRSSI: {
                min: rcRSSIs.length > 0 ? Math.min.apply(null, rcRSSIs) : null,
                max: rcRSSIs.length > 0 ? Math.max.apply(null, rcRSSIs) : null,
                avg: rcRSSIs.length > 0 ? rcRSSIs.reduce(function(a, b) { return a + b; }, 0) / rcRSSIs.length : null
            },
            telemetryRSSI: {
                min: telemRSSIs.length > 0 ? Math.min.apply(null, telemRSSIs) : null,
                max: telemRSSIs.length > 0 ? Math.max.apply(null, telemRSSIs) : null,
                avg: telemRSSIs.length > 0 ? telemRSSIs.reduce(function(a, b) { return a + b; }, 0) / telemRSSIs.length : null
            },
            messageLossRate: {
                min: messageLossRates.length > 0 ? Math.min.apply(null, messageLossRates) : null,
                max: messageLossRates.length > 0 ? Math.max.apply(null, messageLossRates) : null,
                avg: messageLossRates.length > 0 ? messageLossRates.reduce(function(a, b) { return a + b; }, 0) / messageLossRates.length : null
            }
        }
    }
}

