/****************************************************************************
 *
 * ASTHRA - Disaster Management Flight Log and Emergency Area Assessment Report Generator
 * Comprehensive disaster response mission reporting system
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls

/// Disaster Management Report Generator
/// Generates formal disaster response reports suitable for emergency authorities
QtObject {
    id: reportGenerator

    property var missionLogger: null
    property var telemetryLogger: null
    property var offboardMonitor: null
    property var activeVehicle: null
    property var missionController: null
    property var frameCapture: null  // Camera frame capture system

    // Disaster mission metadata
    property string disasterType: ""  // flood, earthquake, landslide, fire, cyclone, etc.
    property string missionId: ""
    property string commandAuthority: ""
    property string responseTeam: ""
    property var missionStartTime: null
    property var missionEndTime: null

    // Emergency zones detected during mission
    property var emergencyZones: []  // Array of { lat, lon, radius, severity, type, timestamp, indicators }

    // Disaster impact data
    property var impactData: {
        "structuralDamage": [],
        "floodDepth": [],
        "fireSpread": [],
        "debrisConcentration": [],
        "blockedRoutes": [],
        "survivorPresence": []
    }

    function initialize(logger, telemetry, monitor, vehicle, controller, frameCap) {
        missionLogger = logger
        telemetryLogger = telemetry
        offboardMonitor = monitor
        activeVehicle = vehicle
        missionController = controller
        frameCapture = frameCap
    }

    function setDisasterMetadata(type, id, authority, team) {
        disasterType = type
        missionId = id
        commandAuthority = authority
        responseTeam = team
    }

    function addEmergencyZone(lat, lon, radius, severity, type, indicators) {
        emergencyZones.push({
            latitude: lat,
            longitude: lon,
            radius: radius,  // meters
            severity: severity,  // "Low", "Medium", "High", "Critical"
            type: type,  // "structural_damage", "flood", "fire", "debris", "survivor", etc.
            timestamp: new Date(),
            indicators: indicators || []
        })
    }

    function addImpactData(category, data) {
        if (impactData.hasOwnProperty(category)) {
            impactData[category].push(data)
        }
    }

    // ============================================================================
    // SECTION 1: DISASTER MISSION OVERVIEW
    // ============================================================================
    function generateMissionOverview() {
        var startTime = missionLogger ? missionLogger.missionStartTime : new Date()
        var endTime = missionLogger ? missionLogger.missionEndTime : new Date()

        var vehicleInfo = {
            id: activeVehicle ? activeVehicle.id : 0,
            type: activeVehicle ? activeVehicle.vehicleTypeString : "Unknown",
            firmware: activeVehicle ? activeVehicle.firmwareTypeString : "Unknown"
        }

        // Determine payload from vehicle configuration
        var payload = []
        if (activeVehicle) {
            if (activeVehicle.cameraTriggerPoints && activeVehicle.cameraTriggerPoints.count > 0) {
                payload.push("Camera")
            }
            // Add other payload detection logic here
            payload.push("Standard Telemetry")
        }

        return {
            disasterType: disasterType || "Not Specified",
            missionId: missionId || generateMissionId(),
            dateTimeUTC: {
                start: startTime ? startTime.toISOString() : null,
                end: endTime ? endTime.toISOString() : null
            },
            dateTimeLocal: {
                start: startTime ? formatLocalTime(startTime) : null,
                end: endTime ? formatLocalTime(endTime) : null
            },
            uavPlatform: {
                id: vehicleInfo.id,
                type: vehicleInfo.type,
                firmware: vehicleInfo.firmware
            },
            payload: payload.length > 0 ? payload : ["Standard Telemetry"],
            operatingSystem: "ASTHRA-GC",
            commandAuthority: commandAuthority || "Not Specified",
            responseTeam: responseTeam || "Not Specified"
        }
    }

    // ============================================================================
    // SECTION 2: AREA OF OPERATIONS (AO)
    // ============================================================================
    function generateAreaOfOperations() {
        if (!telemetryLogger || !activeVehicle) {
            return null
        }

        var samples = telemetryLogger.getSamples()
        if (samples.length === 0) return null

        // Calculate mission boundaries
        var minLat = Infinity, maxLat = -Infinity
        var minLon = Infinity, maxLon = -Infinity
        var coordinates = []

        for (var i = 0; i < samples.length; i++) {
            var pos = samples[i].position
            if (pos && !isNaN(pos.lat) && !isNaN(pos.lon)) {
                coordinates.push({ lat: pos.lat, lon: pos.lon })
                minLat = Math.min(minLat, pos.lat)
                maxLat = Math.max(maxLat, pos.lat)
                minLon = Math.min(minLon, pos.lon)
                maxLon = Math.max(maxLon, pos.lon)
            }
        }

        // Calculate coverage area (approximate)
        var centerLat = (minLat + maxLat) / 2
        var centerLon = (minLon + maxLon) / 2
        var centerCoord = QtPositioning.coordinate(centerLat, centerLon)

        var maxDistance = 0
        for (var j = 0; j < coordinates.length; j++) {
            var coord = QtPositioning.coordinate(coordinates[j].lat, coordinates[j].lon)
            var dist = centerCoord.distanceTo(coord)
            maxDistance = Math.max(maxDistance, dist)
        }

        // Get waypoints from mission
        var waypoints = []
        if (missionController && missionController.visualItems) {
            for (var k = 0; k < missionController.visualItems.count; k++) {
                var item = missionController.visualItems.get(k)
                if (item.coordinate && !isNaN(item.coordinate.latitude)) {
                    waypoints.push({
                        sequence: k,
                        latitude: item.coordinate.latitude,
                        longitude: item.coordinate.longitude,
                        altitude: item.coordinate.altitude || 0
                    })
                }
            }
        }

        return {
            disasterZoneBoundaries: {
                minLatitude: minLat,
                maxLatitude: maxLat,
                minLongitude: minLon,
                maxLongitude: maxLon,
                center: {
                    latitude: centerLat,
                    longitude: centerLon
                },
                estimatedRadius: maxDistance,  // meters
                coverageArea: Math.PI * maxDistance * maxDistance / 1000000  // km²
            },
            coordinates: coordinates,
            waypoints: waypoints,
            affectedPopulationEstimate: "To be determined by ground assessment",
            terrainAssessment: generateTerrainAssessment(),
            accessibilityAssessment: generateAccessibilityAssessment(),
            noFlyZones: [],  // To be populated from geofence data
            restrictedAirspace: []  // To be populated from UTM/airspace data
        }
    }

    function generateTerrainAssessment() {
        if (!telemetryLogger) return "Insufficient data"

        var altProfile = telemetryLogger.getAltitudeProfile()
        if (!altProfile) return "Insufficient data"

        var terrainRoughness = "Unknown"
        var elevationRange = altProfile.max - altProfile.min

        if (elevationRange < 50) terrainRoughness = "Flat"
        else if (elevationRange < 200) terrainRoughness = "Moderate"
        else terrainRoughness = "Mountainous"

        return {
            elevationRange: elevationRange,
            minElevation: altProfile.min,
            maxElevation: altProfile.max,
            averageElevation: altProfile.avg,
            terrainRoughness: terrainRoughness
        }
    }

    function generateAccessibilityAssessment() {
        // Analyze blocked routes and terrain
        var blockedRoutes = impactData.blockedRoutes || []
        return {
            accessibleRoutes: "To be determined",
            blockedRoutes: blockedRoutes,
            terrainDifficulty: "Based on elevation profile analysis"
        }
    }

    // ============================================================================
    // SECTION 3: FLIGHT LOG SUMMARY
    // ============================================================================
    function generateFlightLogSummary() {
        if (!telemetryLogger || !missionLogger) return null

        var samples = telemetryLogger.getSamples()
        if (samples.length === 0) return null

        // Add captured frames information
        var capturedFramesInfo = null
        if (frameCapture) {
            var descentFrames = frameCapture.getDescentFrames()
            var offboardFrames = frameCapture.getOffboardFrames()
            capturedFramesInfo = {
                totalFrames: frameCapture.getAllFrames().length,
                descentFrames: descentFrames.length,
                offboardFrames: offboardFrames.length,
                descentFrameTimestamps: descentFrames.map(function(f) { return f.timestampUTC }),
                offboardFrameTimestamps: offboardFrames.map(function(f) { return f.timestampUTC })
            }
        }

        var startTime = missionLogger.missionStartTime
        var endTime = missionLogger.missionEndTime || new Date()
        var duration = missionLogger.getMissionDuration()

        // Launch and recovery locations
        var launchPos = samples.length > 0 ? samples[0].position : null
        var recoveryPos = samples.length > 0 ? samples[samples.length - 1].position : null

        // Calculate total distance
        var totalDistance = 0
        for (var i = 1; i < samples.length; i++) {
            var prevPos = samples[i-1].position
            var currPos = samples[i].position
            if (prevPos && currPos && !isNaN(prevPos.lat) && !isNaN(currPos.lat)) {
                var prevCoord = QtPositioning.coordinate(prevPos.lat, prevPos.lon)
                var currCoord = QtPositioning.coordinate(currPos.lat, currPos.lon)
                totalDistance += prevCoord.distanceTo(currCoord)
            }
        }

        // Altitude and speed profiles
        var altProfile = telemetryLogger.getAltitudeProfile()
        var speedProfile = telemetryLogger.getSpeedProfile()

        // Time spent over critical zones
        var criticalZoneTime = calculateCriticalZoneTime()

        return {
            launchLocation: launchPos ? {
                latitude: launchPos.lat,
                longitude: launchPos.lon,
                altitude: launchPos.alt
            } : null,
            recoveryLocation: recoveryPos ? {
                latitude: recoveryPos.lat,
                longitude: recoveryPos.lon,
                altitude: recoveryPos.alt
            } : null,
            flightDuration: {
                seconds: duration,
                formatted: formatDuration(duration)
            },
            distanceCovered: {
                meters: totalDistance,
                kilometers: totalDistance / 1000,
                formatted: formatDistance(totalDistance)
            },
            coverageArea: calculateCoverageArea(samples),
            altitudeProfile: altProfile ? {
                min: altProfile.min,
                max: altProfile.max,
                average: altProfile.avg,
                unit: "meters AMSL"
            } : null,
            speedProfile: speedProfile ? {
                min: speedProfile.min,
                max: speedProfile.max,
                average: speedProfile.avg,
                unit: "m/s"
            } : null,
            waypoints: getWaypointSummary(),
            gridScanPatterns: detectGridPatterns(samples),
            timeOverCriticalZones: criticalZoneTime,
            capturedFrames: capturedFramesInfo
        }
    }

    function calculateCriticalZoneTime() {
        if (!telemetryLogger || emergencyZones.length === 0) return 0

        var samples = telemetryLogger.getSamples()
        var criticalTime = 0
        var sampleInterval = 1.0  // seconds

        for (var i = 0; i < samples.length; i++) {
            var pos = samples[i].position
            if (!pos) continue

            for (var j = 0; j < emergencyZones.length; j++) {
                var zone = emergencyZones[j]
                if (zone.severity === "Critical" || zone.severity === "High") {
                    var coord = QtPositioning.coordinate(pos.lat, pos.lon)
                    var zoneCoord = QtPositioning.coordinate(zone.latitude, zone.longitude)
                    var distance = coord.distanceTo(zoneCoord)

                    if (distance <= zone.radius) {
                        criticalTime += sampleInterval
                        break  // Count once per sample
                    }
                }
            }
        }

        return {
            seconds: criticalTime,
            formatted: formatDuration(criticalTime)
        }
    }

    function calculateCoverageArea(samples) {
        // Simple bounding box area calculation
        var minLat = Infinity, maxLat = -Infinity
        var minLon = Infinity, maxLon = -Infinity

        for (var i = 0; i < samples.length; i++) {
            var pos = samples[i].position
            if (pos && !isNaN(pos.lat)) {
                minLat = Math.min(minLat, pos.lat)
                maxLat = Math.max(maxLat, pos.lat)
                minLon = Math.min(minLon, pos.lon)
                maxLon = Math.max(maxLon, pos.lon)
            }
        }

        // Approximate area using bounding box
        var latDiff = (maxLat - minLat) * 111000  // meters
        var lonDiff = (maxLon - minLon) * 111000 * Math.cos((minLat + maxLat) / 2 * Math.PI / 180)
        var area = latDiff * lonDiff / 1000000  // km²

        return {
            squareKilometers: area,
            squareMeters: area * 1000000
        }
    }

    function getWaypointSummary() {
        if (!missionController || !missionController.visualItems) return []

        var waypoints = []
        for (var i = 0; i < missionController.visualItems.count; i++) {
            var item = missionController.visualItems.get(i)
            if (item.coordinate && !isNaN(item.coordinate.latitude)) {
                waypoints.push({
                    sequence: i,
                    latitude: item.coordinate.latitude,
                    longitude: item.coordinate.longitude,
                    altitude: item.coordinate.altitude || 0,
                    command: item.command ? item.command.name : "Unknown"
                })
            }
        }
        return waypoints
    }

    function detectGridPatterns(samples) {
        // Simple grid pattern detection based on waypoint analysis
        // This is a placeholder - more sophisticated pattern detection can be added
        return {
            patternType: "Waypoint-based",
            coverageEfficiency: "To be calculated"
        }
    }

    // ============================================================================
    // SECTION 4: EMERGENCY ZONE IDENTIFICATION
    // ============================================================================
    function generateEmergencyZoneIdentification() {
        var zones = []

        for (var i = 0; i < emergencyZones.length; i++) {
            var zone = emergencyZones[i]
            zones.push({
                zoneId: "EZ-" + (i + 1),
                coordinates: {
                    latitude: zone.latitude,
                    longitude: zone.longitude
                },
                radius: zone.radius,
                severity: zone.severity,
                type: zone.type,
                timestamp: zone.timestamp.toISOString(),
                indicators: zone.indicators,
                priority: getSeverityPriority(zone.severity)
            })
        }

        // Sort by severity priority
        zones.sort(function(a, b) {
            return b.priority - a.priority
        })

        return {
            totalZones: zones.length,
            criticalZones: zones.filter(function(z) { return z.severity === "Critical" }).length,
            highZones: zones.filter(function(z) { return z.severity === "High" }).length,
            mediumZones: zones.filter(function(z) { return z.severity === "Medium" }).length,
            lowZones: zones.filter(function(z) { return z.severity === "Low" }).length,
            zones: zones
        }
    }

    function getSeverityPriority(severity) {
        switch(severity) {
            case "Critical": return 4
            case "High": return 3
            case "Medium": return 2
            case "Low": return 1
            default: return 0
        }
    }

    // ============================================================================
    // SECTION 5: DISASTER IMPACT ANALYSIS
    // ============================================================================
    function generateDisasterImpactAnalysis() {
        return {
            structuralDamage: {
                indicators: impactData.structuralDamage || [],
                summary: analyzeStructuralDamage()
            },
            floodData: {
                depthMeasurements: impactData.floodDepth || [],
                affectedAreas: getFloodAffectedAreas()
            },
            fireData: {
                spreadIndicators: impactData.fireSpread || [],
                affectedAreas: getFireAffectedAreas()
            },
            debrisConcentration: {
                locations: impactData.debrisConcentration || [],
                densityMap: "To be generated from visual analysis"
            },
            blockedRoutes: {
                locations: impactData.blockedRoutes || [],
                impactAssessment: "Routes blocked by debris or structural damage"
            },
            infrastructureFailures: {
                powerGrid: "To be assessed",
                communications: "To be assessed",
                waterSupply: "To be assessed"
            },
            survivorPresence: {
                detections: impactData.survivorPresence || [],
                movementPatterns: analyzeSurvivorPatterns()
            }
        }
    }

    function analyzeStructuralDamage() {
        var damage = impactData.structuralDamage || []
        return {
            totalIndicators: damage.length,
            severityDistribution: "To be analyzed from visual data",
            locations: damage
        }
    }

    function getFloodAffectedAreas() {
        var floodZones = emergencyZones.filter(function(z) { return z.type === "flood" })
        return floodZones.map(function(z) {
            return {
                latitude: z.latitude,
                longitude: z.longitude,
                radius: z.radius,
                severity: z.severity
            }
        })
    }

    function getFireAffectedAreas() {
        var fireZones = emergencyZones.filter(function(z) { return z.type === "fire" })
        return fireZones.map(function(z) {
            return {
                latitude: z.latitude,
                longitude: z.longitude,
                radius: z.radius,
                severity: z.severity
            }
        })
    }

    function analyzeSurvivorPatterns() {
        var survivors = impactData.survivorPresence || []
        return {
            totalDetections: survivors.length,
            concentrationAreas: "To be analyzed from detection data",
            movementTrends: "To be determined from temporal analysis"
        }
    }

    // ============================================================================
    // SECTION 6: SYSTEM & TELEMETRY HEALTH
    // ============================================================================
    function generateSystemTelemetryHealth() {
        if (!telemetryLogger) return null

        var samples = telemetryLogger.getSamples()
        if (samples.length === 0) return null

        // GPS analysis
        var gpsStats = analyzeGPSHealth(samples)

        // Battery analysis
        var batteryProfile = telemetryLogger.getBatteryProfile()

        // Link quality
        var linkQuality = telemetryLogger.getLinkQualityProfile()

        // Failsafe events
        var failsafeEvents = getFailsafeEvents()

        return {
            gps: gpsStats,
            battery: batteryProfile ? {
                usage: {
                    minVoltage: batteryProfile.minVoltage,
                    maxVoltage: batteryProfile.maxVoltage,
                    averageVoltage: batteryProfile.avgVoltage,
                    totalConsumption: batteryProfile.totalConsumption
                },
                enduranceMargins: calculateEnduranceMargins(batteryProfile),
                healthStatus: assessBatteryHealth(batteryProfile)
            } : null,
            communication: linkQuality ? {
                rcRSSI: linkQuality.rcRSSI,
                telemetryRSSI: linkQuality.telemetryRSSI,
                messageLossRate: linkQuality.messageLossRate,
                stability: assessLinkStability(linkQuality)
            } : null,
            failsafeEvents: failsafeEvents,
            emergencyEvents: getEmergencyEvents()
        }
    }

    function analyzeGPSHealth(samples) {
        var gpsCount = 0
        var fixTypes = []
        var satelliteCounts = []
        var hdopValues = []

        for (var i = 0; i < samples.length; i++) {
            var gps = samples[i].gps
            if (gps) {
                gpsCount++
                if (!isNaN(gps.fixType)) fixTypes.push(gps.fixType)
                if (!isNaN(gps.satellites)) satelliteCounts.push(gps.satellites)
                if (!isNaN(gps.hdop)) hdopValues.push(gps.hdop)
            }
        }

        var avgSatellites = satelliteCounts.length > 0 ?
            satelliteCounts.reduce(function(a, b) { return a + b; }, 0) / satelliteCounts.length : 0
        var avgHDOP = hdopValues.length > 0 ?
            hdopValues.reduce(function(a, b) { return a + b; }, 0) / hdopValues.length : 0

        return {
            dataAvailability: (gpsCount / samples.length) * 100,
            averageSatellites: avgSatellites,
            averageHDOP: avgHDOP,
            signalIntegrity: avgHDOP < 2.0 ? "Excellent" : (avgHDOP < 5.0 ? "Good" : "Fair"),
            fixTypeDistribution: "To be analyzed"
        }
    }

    function calculateEnduranceMargins(batteryProfile) {
        if (!batteryProfile) return null

        var remainingPercent = batteryProfile.percentages.length > 0 ?
            batteryProfile.percentages[batteryProfile.percentages.length - 1] : 0

        return {
            remainingCapacity: remainingPercent,
            estimatedTimeRemaining: "To be calculated from consumption rate",
            safetyMargin: remainingPercent > 20 ? "Adequate" : "Low"
        }
    }

    function assessBatteryHealth(batteryProfile) {
        if (!batteryProfile) return "Unknown"

        var minVolt = batteryProfile.minVoltage
        if (isNaN(minVolt)) return "Unknown"

        if (minVolt < 10.5) return "Critical"
        if (minVolt < 11.0) return "Warning"
        return "Normal"
    }

    function assessLinkStability(linkQuality) {
        if (!linkQuality || !linkQuality.messageLossRate) return "Unknown"

        var avgLoss = linkQuality.messageLossRate.avg
        if (isNaN(avgLoss)) return "Unknown"

        if (avgLoss < 1.0) return "Excellent"
        if (avgLoss < 5.0) return "Good"
        if (avgLoss < 10.0) return "Fair"
        return "Poor"
    }

    function getFailsafeEvents() {
        if (!missionLogger) return []

        var events = missionLogger.getEventLog()
        return events.filter(function(e) {
            return e.eventType === "FAILSAFE_ACTIVATED"
        }).map(function(e) {
            return {
                timestamp: e.timestamp.toISOString(),
                location: {
                    latitude: e.latitude,
                    longitude: e.longitude,
                    altitude: e.altitude
                },
                data: e.data
            }
        })
    }

    function getEmergencyEvents() {
        if (!missionLogger) return []

        var events = missionLogger.getEventLog()
        var emergencyTypes = ["FAILSAFE_ACTIVATED", "OFFBOARD_EXIT", "LINK_LOSS"]

        return events.filter(function(e) {
            return emergencyTypes.indexOf(e.eventType) >= 0
        }).map(function(e) {
            return {
                timestamp: e.timestamp.toISOString(),
                eventType: e.eventType,
                location: {
                    latitude: e.latitude,
                    longitude: e.longitude,
                    altitude: e.altitude
                },
                data: e.data
            }
        })
    }

    // ============================================================================
    // SECTION 7: SAFETY & RISK ASSESSMENT
    // ============================================================================
    function generateSafetyRiskAssessment() {
        if (!telemetryLogger) return null

        var samples = telemetryLogger.getSamples()
        var risks = []

        // Analyze altitude violations
        var altViolations = detectAltitudeViolations(samples)

        // Analyze speed violations
        var speedViolations = detectSpeedViolations(samples)

        // Analyze battery critical zones
        var batteryCritical = detectBatteryCriticalZones(samples)

        // Environmental hazards
        var environmentalHazards = analyzeEnvironmentalHazards(samples)

        // Near-miss events
        var nearMisses = detectNearMissEvents()

        return {
            uavOperationalRisks: {
                altitudeViolations: altViolations,
                speedViolations: speedViolations,
                batteryCriticalZones: batteryCritical,
                communicationLoss: getCommunicationLossEvents()
            },
            environmentalHazards: environmentalHazards,
            airspaceConflicts: {
                detected: false,
                nearMissEvents: nearMisses,
                restrictedAirspaceViolations: []
            },
            overallRiskLevel: calculateOverallRiskLevel(altViolations, speedViolations, batteryCritical, nearMisses)
        }
    }

    function detectAltitudeViolations(samples) {
        // Placeholder - would check against altitude limits
        return {
            count: 0,
            violations: []
        }
    }

    function detectSpeedViolations(samples) {
        // Placeholder - would check against speed limits
        return {
            count: 0,
            violations: []
        }
    }

    function detectBatteryCriticalZones(samples) {
        var criticalZones = []
        for (var i = 0; i < samples.length; i++) {
            var battery = samples[i].battery
            if (battery && battery.percentRemaining < 20) {
                criticalZones.push({
                    timestamp: samples[i].timestamp.toISOString(),
                    location: samples[i].position,
                    batteryLevel: battery.percentRemaining
                })
            }
        }
        return {
            count: criticalZones.length,
            zones: criticalZones
        }
    }

    function analyzeEnvironmentalHazards(samples) {
        // Placeholder for wind, smoke, rain, visibility analysis
        return {
            windConditions: "To be analyzed from telemetry",
            visibility: "To be assessed",
            precipitation: "To be assessed",
            smoke: "To be assessed from thermal/visual data"
        }
    }

    function detectNearMissEvents() {
        // Placeholder - would analyze proximity to obstacles or other aircraft
        return []
    }

    function getCommunicationLossEvents() {
        if (!missionLogger) return []

        var events = missionLogger.getEventLog()
        return events.filter(function(e) {
            return e.data && (e.data.reason === "LINK_LOSS" || e.eventType === "LINK_LOSS")
        })
    }

    function calculateOverallRiskLevel(altViolations, speedViolations, batteryCritical, nearMisses) {
        var riskScore = 0

        if (altViolations.count > 0) riskScore += 2
        if (speedViolations.count > 0) riskScore += 1
        if (batteryCritical.count > 0) riskScore += 3
        if (nearMisses.length > 0) riskScore += 5

        if (riskScore >= 7) return "High"
        if (riskScore >= 4) return "Medium"
        if (riskScore >= 1) return "Low"
        return "Minimal"
    }

    // ============================================================================
    // SECTION 8: MISSION OUTCOME & RESPONSE SUPPORT
    // ============================================================================
    function generateMissionOutcome() {
        var coverage = calculateCoverageCompleteness()
        var priorityZones = identifyPriorityZones()
        var recommendations = generateRecommendations()

        return {
            missionSuccess: assessMissionSuccess(),
            coverageCompleteness: coverage,
            dataCompleteness: assessDataCompleteness(),
            priorityZones: priorityZones,
            recommendations: recommendations,
            followUpActions: generateFollowUpActions()
        }
    }

    function assessMissionSuccess() {
        if (!missionLogger) return "Unknown"

        var events = missionLogger.getEventLog()
        var hasCriticalEvents = events.some(function(e) {
            return e.eventType === "FAILSAFE_ACTIVATED" ||
                   (e.data && e.data.reason === "LINK_LOSS")
        })

        if (hasCriticalEvents) return "Partial - Critical events occurred"
        if (emergencyZones.length > 0) return "Successful - Emergency zones identified"
        return "Successful - Mission completed"
    }

    function calculateCoverageCompleteness() {
        if (!telemetryLogger) return "Unknown"

        var samples = telemetryLogger.getSamples()
        var ao = generateAreaOfOperations()

        if (!ao) return "Unknown"

        // Simple heuristic - would be more sophisticated in real implementation
        var coveragePercent = Math.min(100, (samples.length / 100) * 10)  // Placeholder calculation

        return {
            percentage: coveragePercent,
            assessment: coveragePercent > 80 ? "Complete" : (coveragePercent > 50 ? "Adequate" : "Incomplete")
        }
    }

    function assessDataCompleteness() {
        if (!telemetryLogger) return "Unknown"

        var samples = telemetryLogger.getSamples()
        var gpsCount = 0
        var batteryCount = 0

        for (var i = 0; i < samples.length; i++) {
            if (samples[i].gps) gpsCount++
            if (samples[i].battery) batteryCount++
        }

        var total = samples.length
        return {
            gpsData: (gpsCount / total) * 100,
            batteryData: (batteryCount / total) * 100,
            overall: ((gpsCount + batteryCount) / (total * 2)) * 100
        }
    }

    function identifyPriorityZones() {
        var priorityZones = emergencyZones.filter(function(z) {
            return z.severity === "Critical" || z.severity === "High"
        }).map(function(z, index) {
            return {
                zoneId: "PZ-" + (index + 1),
                coordinates: {
                    latitude: z.latitude,
                    longitude: z.longitude
                },
                radius: z.radius,
                severity: z.severity,
                type: z.type,
                priority: z.severity === "Critical" ? 1 : 2,
                immediateResponseRequired: z.severity === "Critical"
            }
        })

        priorityZones.sort(function(a, b) { return a.priority - b.priority })
        return priorityZones
    }

    function generateRecommendations() {
        var recommendations = []

        // Analyze emergency zones and generate recommendations
        var criticalZones = emergencyZones.filter(function(z) { return z.severity === "Critical" })
        if (criticalZones.length > 0) {
            recommendations.push({
                priority: "Immediate",
                action: "Deploy ground response teams to critical zones",
                zones: criticalZones.map(function(z) { return { lat: z.latitude, lon: z.longitude } })
            })
        }

        // Battery and system health recommendations
        var batteryProfile = telemetryLogger ? telemetryLogger.getBatteryProfile() : null
        if (batteryProfile && batteryProfile.minVoltage < 11.0) {
            recommendations.push({
                priority: "High",
                action: "Review battery health and consider replacement",
                technical: true
            })
        }

        // Coverage recommendations
        var coverage = calculateCoverageCompleteness()
        if (coverage.percentage < 80) {
            recommendations.push({
                priority: "Medium",
                action: "Consider follow-up sortie for complete area coverage",
                operational: true
            })
        }

        return recommendations
    }

    function generateFollowUpActions() {
        return {
            groundTeams: {
                priorityZones: identifyPriorityZones(),
                recommendedRoutes: "To be determined from blocked route analysis",
                estimatedResponseTime: "To be calculated"
            },
            followUpUAVSorties: {
                recommended: calculateCoverageCompleteness().percentage < 80,
                targetAreas: "Areas with incomplete coverage",
                payloadRecommendations: "Based on disaster type and initial findings"
            },
            dataAnalysis: {
                visualAnalysis: "Required for structural damage assessment",
                thermalAnalysis: "Required for fire and survivor detection",
                mapping: "Generate detailed disaster area maps"
            }
        }
    }

    // ============================================================================
    // SECTION 9: OUTPUTS & ATTACHMENTS
    // ============================================================================
    function generateFullReport() {
        return {
            reportMetadata: {
                reportType: "Disaster Management Flight Log and Emergency Area Assessment",
                generatedAt: new Date().toISOString(),
                system: "ASTHRA-GC",
                version: "1.0"
            },
            section1_MissionOverview: generateMissionOverview(),
            section2_AreaOfOperations: generateAreaOfOperations(),
            section3_FlightLogSummary: generateFlightLogSummary(),
            section4_EmergencyZoneIdentification: generateEmergencyZoneIdentification(),
            section5_DisasterImpactAnalysis: generateDisasterImpactAnalysis(),
            section6_SystemTelemetryHealth: generateSystemTelemetryHealth(),
            section7_SafetyRiskAssessment: generateSafetyRiskAssessment(),
            section8_MissionOutcome: generateMissionOutcome(),
            section9_Outputs: {
                disasterAreaMap: generateDisasterAreaMap(),
                survivorHazardCoordinates: generateSurvivorHazardCoordinates(),
                flightLogs: generateFlightLogs(),
                telemetryLogs: generateTelemetryLogs(),
                capturedFrames: generateCapturedFrames()
            }
        }
    }

    function generateDisasterAreaMap() {
        var ao = generateAreaOfOperations()
        var zones = generateEmergencyZoneIdentification()

        return {
            boundaries: ao ? ao.disasterZoneBoundaries : null,
            emergencyZones: zones.zones,
            waypoints: ao ? ao.waypoints : [],
            flightPath: telemetryLogger ? telemetryLogger.getSamples().map(function(s) {
                return { lat: s.position.lat, lon: s.position.lon, alt: s.position.alt }
            }) : []
        }
    }

    function generateSurvivorHazardCoordinates() {
        var survivors = impactData.survivorPresence || []
        var hazards = emergencyZones.filter(function(z) {
            return z.type !== "survivor"
        })

        return {
            survivors: survivors.map(function(s) {
                return {
                    latitude: s.latitude || s.lat,
                    longitude: s.longitude || s.lon,
                    timestamp: s.timestamp || new Date().toISOString(),
                    confidence: s.confidence || "Unknown"
                }
            }),
            hazards: hazards.map(function(h) {
                return {
                    latitude: h.latitude,
                    longitude: h.longitude,
                    radius: h.radius,
                    type: h.type,
                    severity: h.severity
                }
            })
        }
    }

    function generateFlightLogs() {
        if (!missionLogger) return null

        return {
            events: missionLogger.getEventLog().map(function(e) {
                return {
                    timestamp: e.timestamp.toISOString(),
                    eventType: e.eventType,
                    location: {
                        latitude: e.latitude,
                        longitude: e.longitude,
                        altitude: e.altitude
                    },
                    data: e.data
                }
            }),
            missionDuration: missionLogger.getMissionDuration(),
            startTime: missionLogger.missionStartTime ? missionLogger.missionStartTime.toISOString() : null,
            endTime: missionLogger.missionEndTime ? missionLogger.missionEndTime.toISOString() : null
        }
    }

    function generateTelemetryLogs() {
        if (!telemetryLogger) return null

        var samples = telemetryLogger.getSamples()
        return {
            sampleCount: samples.length,
            sampleInterval: telemetryLogger.sampleInterval,
            samples: samples.map(function(s) {
                return {
                    timestamp: s.timestamp.toISOString(),
                    position: s.position,
                    gps: s.gps,
                    battery: s.battery,
                    link: s.link,
                    sensors: s.sensors
                }
            })
        }
    }

    function generateCapturedFrames() {
        if (!frameCapture) return null

        var allFrames = frameCapture.getAllFrames()
        var descentFrames = frameCapture.getDescentFrames()
        var offboardFrames = frameCapture.getOffboardFrames()

        return {
            totalFrames: allFrames.length,
            descentFrames: descentFrames.length,
            offboardFrames: offboardFrames.length,
            frames: allFrames.map(function(f) {
                return {
                    frameId: f.frameId,
                    timestamp: f.timestampUTC,
                    imagePath: f.imagePath,
                    imageFileName: f.imageFileName,
                    position: f.position,
                    flightMode: f.flightMode,
                    captureReason: f.captureReason,
                    gps: f.gps,
                    battery: f.battery,
                    metadata: f.metadata
                }
            }),
            descentFramesList: descentFrames.map(function(f) {
                return {
                    frameId: f.frameId,
                    timestamp: f.timestampUTC,
                    imagePath: f.imagePath,
                    position: f.position,
                    altitude: f.position.alt
                }
            }),
            offboardFramesList: offboardFrames.map(function(f) {
                return {
                    frameId: f.frameId,
                    timestamp: f.timestampUTC,
                    imagePath: f.imagePath,
                    position: f.position
                }
            })
        }
    }

    // ============================================================================
    // EXPORT FUNCTIONS
    // ============================================================================
    function exportJSON() {
        return JSON.stringify(generateFullReport(), null, 2)
    }

    function exportKML() {
        var report = generateFullReport()
        var kml = '<?xml version="1.0" encoding="UTF-8"?>\n'
        kml += '<kml xmlns="http://www.opengis.net/kml/2.2">\n'
        kml += '<Document>\n'
        kml += '<name>ASTHRA Disaster Mission Report</name>\n'

        // Flight path
        if (report.section9_Outputs.disasterAreaMap && report.section9_Outputs.disasterAreaMap.flightPath) {
            kml += '<Placemark>\n'
            kml += '<name>Flight Path</name>\n'
            kml += '<LineString>\n'
            kml += '<coordinates>\n'
            var path = report.section9_Outputs.disasterAreaMap.flightPath
            for (var i = 0; i < path.length; i++) {
                kml += path[i].lon + ',' + path[i].lat + ',' + path[i].alt + ' '
            }
            kml += '</coordinates>\n'
            kml += '</LineString>\n'
            kml += '</Placemark>\n'
        }

        // Emergency zones
        if (report.section4_EmergencyZoneIdentification && report.section4_EmergencyZoneIdentification.zones) {
            var zones = report.section4_EmergencyZoneIdentification.zones
            for (var j = 0; j < zones.length; j++) {
                var zone = zones[j]
                kml += '<Placemark>\n'
                kml += '<name>' + zone.zoneId + ' - ' + zone.severity + '</name>\n'
                kml += '<description>Type: ' + zone.type + '</description>\n'
                kml += '<Point>\n'
                kml += '<coordinates>' + zone.coordinates.longitude + ',' + zone.coordinates.latitude + ',0</coordinates>\n'
                kml += '</Point>\n'
                kml += '</Placemark>\n'
            }
        }

        kml += '</Document>\n'
        kml += '</kml>\n'
        return kml
    }

    function exportCSV() {
        var report = generateFullReport()
        var csv = "Section,Field,Value\n"

        // Mission Overview
        var overview = report.section1_MissionOverview
        csv += "Mission Overview,Disaster Type," + overview.disasterType + "\n"
        csv += "Mission Overview,Mission ID," + overview.missionId + "\n"
        csv += "Mission Overview,Start Time UTC," + overview.dateTimeUTC.start + "\n"
        csv += "Mission Overview,End Time UTC," + overview.dateTimeUTC.end + "\n"

        // Emergency Zones
        if (report.section4_EmergencyZoneIdentification && report.section4_EmergencyZoneIdentification.zones) {
            csv += "\nEmergency Zones,Zone ID,Latitude,Longitude,Radius (m),Severity,Type\n"
            var zones = report.section4_EmergencyZoneIdentification.zones
            for (var i = 0; i < zones.length; i++) {
                var z = zones[i]
                csv += "Emergency Zones," + z.zoneId + "," + z.coordinates.latitude + "," + z.coordinates.longitude + "," + z.radius + "," + z.severity + "," + z.type + "\n"
            }
        }

        return csv
    }

    function exportGeoJSON() {
        var report = generateFullReport()
        var geoJson = {
            type: "FeatureCollection",
            features: []
        }

        // Flight path as LineString
        if (report.section9_Outputs.disasterAreaMap && report.section9_Outputs.disasterAreaMap.flightPath) {
            var coordinates = report.section9_Outputs.disasterAreaMap.flightPath.map(function(p) {
                return [p.lon, p.lat, p.alt]
            })
            geoJson.features.push({
                type: "Feature",
                geometry: {
                    type: "LineString",
                    coordinates: coordinates
                },
                properties: {
                    name: "Flight Path",
                    type: "flight_path"
                }
            })
        }

        // Emergency zones as Points
        if (report.section4_EmergencyZoneIdentification && report.section4_EmergencyZoneIdentification.zones) {
            var zones = report.section4_EmergencyZoneIdentification.zones
            for (var i = 0; i < zones.length; i++) {
                var zone = zones[i]
                geoJson.features.push({
                    type: "Feature",
                    geometry: {
                        type: "Point",
                        coordinates: [zone.coordinates.longitude, zone.coordinates.latitude, 0]
                    },
                    properties: {
                        zoneId: zone.zoneId,
                        severity: zone.severity,
                        type: zone.type,
                        radius: zone.radius
                    }
                })
            }
        }

        return JSON.stringify(geoJson, null, 2)
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================
    function generateMissionId() {
        var now = new Date()
        return "ASTHRA-" + now.getFullYear() +
               String(now.getMonth() + 1).padStart(2, '0') +
               String(now.getDate()).padStart(2, '0') + "-" +
               String(now.getHours()).padStart(2, '0') +
               String(now.getMinutes()).padStart(2, '0')
    }

    function formatLocalTime(date) {
        if (!date) return "N/A"
        return date.toLocaleString()
    }

    function formatDuration(seconds) {
        var hours = Math.floor(seconds / 3600)
        var minutes = Math.floor((seconds % 3600) / 60)
        var secs = seconds % 60
        return String(hours).padStart(2, '0') + ":" +
               String(minutes).padStart(2, '0') + ":" +
               String(Math.floor(secs)).padStart(2, '0')
    }

    function formatDistance(meters) {
        if (meters < 1000) {
            return meters.toFixed(0) + " m"
        } else {
            return (meters / 1000).toFixed(2) + " km"
        }
    }
}

