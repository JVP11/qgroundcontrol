/****************************************************************************
 *
 * ASTHRA Swarm — load a KML land polygon and split coverage by % per drone.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root
    color: qgcPal.window
    anchors.fill: parent

    property var mainWindow: null
    property var coverage: null
    property var swarmBackend: null

    readonly property var _mvm: QGroundControl.multiVehicleManager
    readonly property var _vehicles: _mvm ? _mvm.vehicles : null
    readonly property int _qgcCount: _vehicles ? _vehicles.count : 0
    readonly property var _swarmDrones: swarmBackend && swarmBackend.drones ? swarmBackend.drones : []
    readonly property int _swarmCount: _swarmDrones ? _swarmDrones.length : 0
    readonly property int _droneCount: shareModel.count
    readonly property bool _backendOn: !!(swarmBackend && swarmBackend.connected)

    property var landPath: []
    property real totalAreaM2: 0
    property real scanSizeM: 1000
    readonly property bool _mapLand: fileName === "Land on map"
    property string fileName: ""
    property string statusText: "Connect drones, choose the land file, then draw the split on the map."
    property var assignments: []
    property string _lastError: ""
    property bool showUsbLinks: false
    property real surveyAltM: 30
    property real surveySpacingM: 20

    readonly property var _colors: ["#D4A017", "#2A8B55", "#2D4A5F", "#9B2D2D", "#534AB7", "#8B9199"]

    QGCPalette { id: qgcPal }

    ListModel { id: shareModel }

    function _coordLat(c) { return (c.latitude !== undefined) ? c.latitude : c.lat }
    function _coordLon(c) { return (c.longitude !== undefined) ? c.longitude : c.lng }

    function _toCoord(lat, lon) {
        return QtPositioning.coordinate(lat, lon)
    }

    function _copyPath(src) {
        var out = []
        if (!src)
            return out
        for (var i = 0; i < src.length; i++)
            out.push(_toCoord(_coordLat(src[i]), _coordLon(src[i])))
        return out
    }

    function landFromMap() {
        var c = QtPositioning.coordinate(0, 0)
        if (mainWindow && typeof mainWindow.coverageMap === "function") {
            var map = mainWindow.coverageMap()
            if (map && map.center && map.center.isValid)
                c = map.center
        }
        if ((!c || !c.isValid || (c.latitude === 0 && c.longitude === 0)) && _vehicles && _vehicles.count > 0) {
            var v = _vehicles.get(0)
            if (v && v.coordinate && v.coordinate.isValid)
                c = v.coordinate
        }
        if (!c || !c.isValid || (Math.abs(c.latitude) < 0.0001 && Math.abs(c.longitude) < 0.0001))
            c = QtPositioning.coordinate(12.9716, 77.5946)
        var half = Math.max(50, scanSizeM) * 0.5
        var dLat = half / 110540.0
        var dLon = half / (111320.0 * Math.max(0.25, Math.cos(c.latitude * Math.PI / 180.0)))
        landPath = [
            _toCoord(c.latitude - dLat, c.longitude - dLon),
            _toCoord(c.latitude - dLat, c.longitude + dLon),
            _toCoord(c.latitude + dLat, c.longitude + dLon),
            _toCoord(c.latitude + dLat, c.longitude - dLon)
        ]
        totalAreaM2 = polygonAreaM2(landPath)
        fileName = "Land on map"
        assignments = []
        rebuildDrones(true)
        statusText = "Scan " + formatScanSize(scanSizeM) + " at map center (" + formatArea(totalAreaM2) + "). Tap Draw split on map."
        _publish()
    }

    function formatScanSize(m) {
        if (m >= 1000)
            return (m / 1000.0).toFixed(m % 1000 === 0 ? 0 : 1) + " km × " + (m / 1000.0).toFixed(m % 1000 === 0 ? 0 : 1) + " km"
        return Math.round(m) + " m × " + Math.round(m) + " m"
    }

    function setScanSize(m) {
        var next = Math.max(200, Math.min(5000, Math.round(m)))
        if (Math.abs(next - scanSizeM) < 1)
            return
        var hadSplit = assignments && assignments.length > 0
        scanSizeM = next
        if (fileName.length && fileName !== "Land on map")
            return
        landFromMap()
        if (hadSplit)
            applySplit()
    }

    function polygonAreaM2(path) {
        if (!path || path.length < 3)
            return 0
        var lat0 = _coordLat(path[0]) * Math.PI / 180.0
        var mLat = 110540.0
        var mLon = 111320.0 * Math.cos(lat0)
        var lon0 = _coordLon(path[0])
        var latZ = _coordLat(path[0])
        var sum = 0
        for (var i = 0; i < path.length; i++) {
            var a = path[i]
            var b = path[(i + 1) % path.length]
            var x1 = (_coordLon(a) - lon0) * mLon
            var y1 = (_coordLat(a) - latZ) * mLat
            var x2 = (_coordLon(b) - lon0) * mLon
            var y2 = (_coordLat(b) - latZ) * mLat
            sum += x1 * y2 - x2 * y1
        }
        return Math.abs(sum) * 0.5
    }

    function _clipHalf(path, insideFn, intersectFn) {
        if (!path || path.length === 0)
            return []
        var out = []
        for (var i = 0; i < path.length; i++) {
            var a = path[i]
            var b = path[(i + 1) % path.length]
            var aIn = insideFn(a)
            var bIn = insideFn(b)
            if (aIn && bIn) {
                out.push(b)
            } else if (aIn && !bIn) {
                out.push(intersectFn(a, b))
            } else if (!aIn && bIn) {
                out.push(intersectFn(a, b))
                out.push(b)
            }
        }
        return out
    }

    function clipLonBand(path, lonMin, lonMax) {
        var p = _clipHalf(path,
                          function (c) { return _coordLon(c) >= lonMin - 1e-12 },
                          function (a, b) {
                              var den = _coordLon(b) - _coordLon(a)
                              var t = Math.abs(den) < 1e-15 ? 0 : (lonMin - _coordLon(a)) / den
                              return _toCoord(_coordLat(a) + t * (_coordLat(b) - _coordLat(a)), lonMin)
                          })
        return _clipHalf(p,
                         function (c) { return _coordLon(c) <= lonMax + 1e-12 },
                         function (a, b) {
                             var den = _coordLon(b) - _coordLon(a)
                             var t = Math.abs(den) < 1e-15 ? 0 : (lonMax - _coordLon(a)) / den
                             return _toCoord(_coordLat(a) + t * (_coordLat(b) - _coordLat(a)), lonMax)
                         })
    }

    function clipLatBand(path, latMin, latMax) {
        var p = _clipHalf(path,
                          function (c) { return _coordLat(c) >= latMin - 1e-12 },
                          function (a, b) {
                              var den = _coordLat(b) - _coordLat(a)
                              var t = Math.abs(den) < 1e-15 ? 0 : (latMin - _coordLat(a)) / den
                              return _toCoord(latMin, _coordLon(a) + t * (_coordLon(b) - _coordLon(a)))
                          })
        return _clipHalf(p,
                         function (c) { return _coordLat(c) <= latMax + 1e-12 },
                         function (a, b) {
                             var den = _coordLat(b) - _coordLat(a)
                             var t = Math.abs(den) < 1e-15 ? 0 : (latMax - _coordLat(a)) / den
                             return _toCoord(latMax, _coordLon(a) + t * (_coordLon(b) - _coordLon(a)))
                         })
    }

    function boundsOf(path) {
        var minLat = 90, maxLat = -90, minLon = 180, maxLon = -180
        for (var i = 0; i < path.length; i++) {
            minLat = Math.min(minLat, _coordLat(path[i]))
            maxLat = Math.max(maxLat, _coordLat(path[i]))
            minLon = Math.min(minLon, _coordLon(path[i]))
            maxLon = Math.max(maxLon, _coordLon(path[i]))
        }
        return { minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon }
    }

    function formatArea(m2) {
        if (isNaN(m2) || m2 <= 0)
            return "—"
        if (m2 >= 10000)
            return (m2 / 10000.0).toFixed(2) + " ha"
        return m2.toFixed(0) + " m²"
    }

    function _baseName(path) {
        if (!path)
            return ""
        var s = String(path)
        var cut = Math.max(s.lastIndexOf("/"), s.lastIndexOf("\\"))
        return cut >= 0 ? s.substring(cut + 1) : s
    }

    function collectFleet() {
        var byId = {}
        var order = []
        function add(id, linked, backend) {
            if (id === undefined || id === null)
                return
            if (!byId[id]) {
                byId[id] = { vehicleId: id, linked: false, backend: false }
                order.push(id)
            }
            if (linked)
                byId[id].linked = true
            if (backend)
                byId[id].backend = true
        }
        // Configured swarm is always 1–2–3 so % split works before USB/backend is up.
        for (var p = 1; p <= 3; p++)
            add(p, false, false)
        if (_vehicles) {
            for (var i = 0; i < _vehicles.count; i++) {
                var v = _vehicles.get(i)
                if (v)
                    add(v.id, true, false)
            }
        }
        for (var j = 0; j < _swarmCount; j++) {
            var d = _swarmDrones[j]
            if (d)
                add(d.droneId !== undefined ? d.droneId : (j + 1), false, true)
        }
        return order.map(function (id) { return byId[id] })
    }

    function persistSharePercents() {
        var map = {}
        for (var i = 0; i < shareModel.count; i++) {
            var row = shareModel.get(i)
            map[String(row.vehicleId)] = row.percent
        }
        if (coverage)
            coverage.sharePercents = map
    }

    function _persistedPercents() {
        var saved = {}
        if (!coverage || !coverage.sharePercents)
            return saved
        var persisted = coverage.sharePercents
        function take(id) {
            var k = String(id)
            var v = persisted[k]
            if (v === undefined)
                v = persisted[id]
            if (v !== undefined)
                saved[k] = v
        }
        for (var p = 1; p <= 12; p++)
            take(p)
        try {
            var keys = Object.keys(persisted)
            for (var ki = 0; ki < keys.length; ki++)
                take(keys[ki])
        } catch (e) {}
        return saved
    }

    function _tagFor(row) {
        if (row.linked && row.backend)
            return "GCS + BACKEND"
        if (row.linked)
            return "GCS LINK"
        if (row.backend)
            return "BACKEND"
        return "PLANNED"
    }

    function rebuildDrones(keepPercents) {
        var saved = {}
        if (keepPercents) {
            saved = _persistedPercents()
            for (var k = 0; k < shareModel.count; k++) {
                var oldRow = shareModel.get(k)
                var sk = String(oldRow.vehicleId)
                if (saved[sk] === undefined)
                    saved[sk] = oldRow.percent
            }
        }
        var fleet = collectFleet()
        var n = fleet.length
        var useSaved = !!(keepPercents && n > 0)
        for (var ck = 0; ck < n && useSaved; ck++) {
            if (saved[String(fleet[ck].vehicleId)] === undefined)
                useSaved = false
        }
        var inPlace = !!(useSaved && shareModel.count === n && n > 0)
        if (inPlace) {
            for (var s = 0; s < n; s++) {
                if (shareModel.get(s).vehicleId !== fleet[s].vehicleId) {
                    inPlace = false
                    break
                }
            }
        }
        if (inPlace) {
            for (var u = 0; u < n; u++) {
                var frow = fleet[u]
                var tag = _tagFor(frow)
                if (shareModel.get(u).tag !== tag)
                    shareModel.setProperty(u, "tag", tag)
                if (shareModel.get(u).linked !== frow.linked)
                    shareModel.setProperty(u, "linked", frow.linked)
                var want = saved[String(frow.vehicleId)]
                if (want !== undefined && shareModel.get(u).percent !== want)
                    shareModel.setProperty(u, "percent", want)
            }
            return
        }
        var base = n > 0 ? Math.floor(100 / n) : 0
        var rem = n > 0 ? (100 - base * n) : 0
        shareModel.clear()
        for (var i = 0; i < n; i++) {
            var row = fleet[i]
            var id = row.vehicleId
            var pct = base + (i === n - 1 ? rem : 0)
            if (useSaved && saved[String(id)] !== undefined)
                pct = saved[String(id)]
            shareModel.append({
                                  vehicleId: id,
                                  name: "DRONE " + id,
                                  tag: _tagFor(row),
                                  linked: row.linked,
                                  percent: pct,
                                  accent: _colors[i % _colors.length]
                              })
        }
        if (useSaved)
            persistSharePercents()
    }

    function equalSplit() {
        rebuildDrones(false)
        persistSharePercents()
        statusText = _droneCount === 0
                ? "No drones yet. Tap Connect."
                : (_droneCount === 3
                   ? "Equal split: 33% / 33% / 34%."
                   : "Each drone got an equal share.")
    }

    function bumpPercent(index, delta) {
        if (index < 0 || index >= shareModel.count)
            return
        setPercent(index, shareModel.get(index).percent + delta)
    }

    function setPercent(index, value) {
        if (index < 0 || index >= shareModel.count)
            return
        shareModel.setProperty(index, "percent", Math.max(0, Math.min(100, Math.round(value))))
        persistSharePercents()
    }

    function connectRadios() {
        var autoConnectSettings = QGroundControl.settingsManager.autoConnectSettings
        if (autoConnectSettings && autoConnectSettings.autoConnectUDP)
            autoConnectSettings.autoConnectUDP.value = true
        if (swarmBackend && !swarmBackend.connected)
            swarmBackend.connectToBackend()
        statusText = _droneCount > 0
                ? (_droneCount + " drone(s) ready. Next: choose the land file.")
                : "Waiting for drones on UDP 14550, 14551 and 14552…"
    }

    function percentSum() {
        var s = 0
        for (var i = 0; i < shareModel.count; i++)
            s += shareModel.get(i).percent
        return s
    }

    function applySplit() {
        if (shareModel.count === 0)
            rebuildDrones(false)
        if (!landPath || landPath.length < 3)
            landFromMap()
        if (!landPath || landPath.length < 3) {
            statusText = "Could not make a field. Pan the FLY map, then try again."
            return
        }
        if (shareModel.count === 0) {
            statusText = "No drones yet. Tap Connect, or start swarm-backend."
            return
        }
        var sum = percentSum()
        if (Math.abs(sum - 100) > 0.6) {
            statusText = "Enter shares that add to 100%. You have " + sum.toFixed(0) + "%."
            return
        }

        var b = boundsOf(landPath)
        var splitLon = (b.maxLon - b.minLon) >= (b.maxLat - b.minLat)
        var bins = 400
        var binAreas = []
        var total = 0
        for (var i = 0; i < bins; i++) {
            var t0 = i / bins
            var t1 = (i + 1) / bins
            var piece = splitLon
                    ? clipLonBand(landPath, b.minLon + t0 * (b.maxLon - b.minLon), b.minLon + t1 * (b.maxLon - b.minLon))
                    : clipLatBand(landPath, b.minLat + t0 * (b.maxLat - b.minLat), b.minLat + t1 * (b.maxLat - b.minLat))
            var a = polygonAreaM2(piece)
            binAreas.push(a)
            total += a
        }
        if (total <= 0)
            total = totalAreaM2

        var out = []
        var bin = 0
        for (var d = 0; d < shareModel.count; d++) {
            var share = shareModel.get(d)
            var target = share.percent / 100.0 * total
            var start = bin
            var acc = 0
            if (d === shareModel.count - 1)
                bin = bins
            else {
                while (bin < bins) {
                    var next = acc + binAreas[bin]
                    if (acc > 0 && next >= target) {
                        if (Math.abs(next - target) < Math.abs(acc - target)) {
                            acc = next
                            bin++
                        }
                        break
                    }
                    acc = next
                    bin++
                }
                if (bin === start && start < bins)
                    bin = start + 1
            }
            var u0 = start / bins
            var u1 = bin / bins
            var region = splitLon
                    ? clipLonBand(landPath, b.minLon + u0 * (b.maxLon - b.minLon), b.minLon + u1 * (b.maxLon - b.minLon))
                    : clipLatBand(landPath, b.minLat + u0 * (b.maxLat - b.minLat), b.minLat + u1 * (b.maxLat - b.minLat))
            var area = polygonAreaM2(region)
            out.push({
                         vehicleId: share.vehicleId,
                         name: share.name,
                         percent: share.percent,
                         areaM2: area,
                         path: region,
                         color: share.accent
                     })
        }
        assignments = out
        statusText = "Land split by your percentages. Next: make survey waypoints."
        _publish()
        if (mainWindow) {
            mainWindow.showFlyView(true)
            if (typeof mainWindow.fitCoverageLand === "function")
                mainWindow.fitCoverageLand(landPath)
        }
    }

    function _transectHits(path, isNorthSouth, value) {
        var hits = []
        if (!path || path.length < 2)
            return hits
        for (var i = 0; i < path.length; i++) {
            var a = path[i]
            var b = path[(i + 1) % path.length]
            var aLat = _coordLat(a), aLon = _coordLon(a)
            var bLat = _coordLat(b), bLon = _coordLon(b)
            if (isNorthSouth) {
                if ((aLon - value) * (bLon - value) <= 0 && Math.abs(bLon - aLon) > 1e-12) {
                    var t = (value - aLon) / (bLon - aLon)
                    hits.push(aLat + t * (bLat - aLat))
                }
            } else {
                if ((aLat - value) * (bLat - value) <= 0 && Math.abs(bLat - aLat) > 1e-12) {
                    var t = (value - aLat) / (bLat - aLat)
                    hits.push(aLon + t * (bLon - aLon))
                }
            }
        }
        hits.sort(function (x, y) { return x - y })
        return hits
    }

    function surveyWaypoints(path, spacingM, altM) {
        var wps = []
        if (!path || path.length < 3)
            return wps
        var b = boundsOf(path)
        var lat0 = ((b.minLat + b.maxLat) * 0.5) * Math.PI / 180.0
        var mLat = 110540.0
        var mLon = 111320.0 * Math.max(0.25, Math.cos(lat0))
        var ns = (b.maxLon - b.minLon) * mLon >= (b.maxLat - b.minLat) * mLat
        var spacing = Math.max(5, spacingM)
        var flip = false
        if (ns) {
            var dLon = spacing / mLon
            for (var lon = b.minLon + dLon * 0.5; lon <= b.maxLon + 1e-9; lon += dLon) {
                var hits = _transectHits(path, true, lon)
                if (hits.length < 2)
                    continue
                var latA = hits[0]
                var latB = hits[hits.length - 1]
                if (Math.abs(latB - latA) * mLat < spacing * 0.25)
                    continue
                if (flip) {
                    var tmp = latA; latA = latB; latB = tmp
                }
                wps.push({ lat: latA, lon: lon, alt: altM })
                wps.push({ lat: latB, lon: lon, alt: altM })
                flip = !flip
            }
        } else {
            var dLat = spacing / mLat
            for (var lat = b.minLat + dLat * 0.5; lat <= b.maxLat + 1e-9; lat += dLat) {
                var hits2 = _transectHits(path, false, lat)
                if (hits2.length < 2)
                    continue
                var lonA = hits2[0]
                var lonB = hits2[hits2.length - 1]
                if (Math.abs(lonB - lonA) * mLon < spacing * 0.25)
                    continue
                if (flip) {
                    var tmp2 = lonA; lonA = lonB; lonB = tmp2
                }
                wps.push({ lat: lat, lon: lonA, alt: altM })
                wps.push({ lat: lat, lon: lonB, alt: altM })
                flip = !flip
            }
        }
        return wps
    }

    function makeSurvey() {
        if (!assignments || assignments.length === 0)
            applySplit()
        if (!assignments || assignments.length === 0)
            return
        var out = []
        var totalWp = 0
        for (var i = 0; i < assignments.length; i++) {
            var a = assignments[i]
            var wps = surveyWaypoints(a.path, surveySpacingM, surveyAltM)
            totalWp += wps.length
            out.push({
                         vehicleId: a.vehicleId,
                         name: a.name,
                         percent: a.percent,
                         areaM2: a.areaM2,
                         path: a.path,
                         color: a.color,
                         waypoints: wps,
                         wpCount: wps.length
                     })
        }
        assignments = out
        statusText = "Survey ready: " + totalWp + " waypoints. Upload to send each drone its route."
        _publish()
        if (mainWindow) {
            mainWindow.showFlyView(true)
            if (typeof mainWindow.fitCoverageLand === "function")
                mainWindow.fitCoverageLand(landPath)
        }
    }

    function _vehicleById(id) {
        if (!_vehicles)
            return null
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (v && v.id === id)
                return v
        }
        return null
    }

    function _simpleItem(cmd, jumpId, lat, lon, alt, p1) {
        return {
            type: "SimpleItem",
            autoContinue: true,
            command: cmd,
            doJumpId: jumpId,
            frame: 3,
            Altitude: alt,
            AltitudeMode: 1,
            AMSLAltAboveTerrain: null,
            params: [p1, 0, 0, 0, lat, lon, alt]
        }
    }

    function _planJson(vehicle, wps) {
        var items = []
        var first = wps[0]
        items.push(_simpleItem(22, 1, first.lat, first.lon, first.alt, 15))
        for (var i = 0; i < wps.length; i++)
            items.push(_simpleItem(16, i + 2, wps[i].lat, wps[i].lon, wps[i].alt, 0))
        items.push(_simpleItem(20, wps.length + 2, 0, 0, 0, 0))
        var fw = 12
        var vt = 2
        if (vehicle) {
            if (vehicle.apmFirmware)
                fw = 3
            if (vehicle.fixedWing)
                vt = 1
            else if (vehicle.vtol)
                vt = 19
            else if (vehicle.rover)
                vt = 10
        }
        return {
            fileType: "Plan",
            version: 1,
            groundStation: "ASTHRA",
            geoFence: { circles: [], polygons: [], version: 2 },
            rallyPoints: { points: [], version: 2 },
            mission: {
                version: 2,
                firmwareType: fw,
                vehicleType: vt,
                globalPlanAltitudeMode: 1,
                cruiseSpeed: 15,
                hoverSpeed: 5,
                plannedHomePosition: [first.lat, first.lon, 0],
                items: items
            }
        }
    }

    function uploadSurveys() {
        if (!assignments || assignments.length === 0 || !assignments[0].waypoints)
            makeSurvey()
        if (!assignments || assignments.length === 0)
            return
        var uploaded = 0
        var skipped = []
        var failed = []
        for (var i = 0; i < assignments.length; i++) {
            var a = assignments[i]
            var wps = a.waypoints || []
            if (wps.length < 2) {
                failed.push(a.name)
                continue
            }
            var v = _vehicleById(a.vehicleId)
            if (!v || typeof v.sendPlan !== "function") {
                skipped.push(a.name)
                continue
            }
            var path = ShapeFileHelper.writeTempText("asthra_drone_" + a.vehicleId + ".plan", JSON.stringify(_planJson(v, wps)))
            if (!path) {
                failed.push(a.name)
                continue
            }
            v.sendPlan(path)
            uploaded++
        }
        var msg = uploaded + " survey(s) uploaded to radios."
        if (skipped.length)
            msg += " No GCS radio: " + skipped.join(", ") + "."
        if (failed.length)
            msg += " Failed: " + failed.join(", ") + "."
        if (uploaded === 0 && skipped.length)
            msg += " Plug in UDP/USB so each drone can receive its plan."
        statusText = msg
    }

    function clearAll() {
        landPath = []
        totalAreaM2 = 0
        fileName = ""
        assignments = []
        statusText = "Cleared. Load a KML polygon to start."
        _publish()
    }

    function _publish() {
        if (!coverage)
            return
        coverage.landPath = landPath
        coverage.totalAreaM2 = totalAreaM2
        coverage.fileName = fileName
        coverage.assignments = assignments
        persistSharePercents()
        coverage.revision = (coverage.revision || 0) + 1
    }

    function loadKml(filePath) {
        var result = ShapeFileHelper.loadPolygonQml(filePath)
        if (!result || !result.ok || !result.path || result.path.length < 3) {
            statusText = result && result.error ? result.error : "KML must contain a polygon (land boundary)."
            return
        }
        landPath = _copyPath(result.path)
        totalAreaM2 = polygonAreaM2(landPath)
        fileName = _baseName(filePath)
        assignments = []
        rebuildDrones(true)
        statusText = "Loaded " + fileName + " — " + formatArea(totalAreaM2) + ". Enter each drone's %, then draw."
        _publish()
    }

    function restoreFromCoverage() {
        if (mainWindow && mainWindow.swarmCoverage)
            coverage = mainWindow.swarmCoverage
        if (mainWindow && mainWindow.swarmBackend)
            swarmBackend = mainWindow.swarmBackend
        if (!coverage)
            return
        if (coverage.landPath && coverage.landPath.length >= 3) {
            landPath = coverage.landPath
            totalAreaM2 = coverage.totalAreaM2
            fileName = coverage.fileName
            assignments = coverage.assignments || []
        }
        rebuildDrones(true)
    }

    Component.onCompleted: {
        restoreFromCoverage()
    }

    onCoverageChanged: restoreFromCoverage()
    onMainWindowChanged: restoreFromCoverage()

    Timer {
        interval: 300
        running: true
        repeat: false
        onTriggered: {
            restoreFromCoverage()
        }
    }

    Connections {
        target: _vehicles
        function onCountChanged() {
            rebuildDrones(true)
        }
    }

    Connections {
        target: swarmBackend
        ignoreUnknownSignals: true
        function onDronesChanged() {
            rebuildDrones(true)
        }
    }

    onSwarmBackendChanged: rebuildDrones(true)

    FileDialog {
        id: kmlDialog
        title: "Open land KML"
        fileMode: FileDialog.OpenFile
        nameFilters: ["KML files (*.kml)", "Shape files (*.shp)", "All files (*)"]
        onAccepted: {
            var local = ""
            try {
                local = QGCFileDialogController.urlToLocalFile(selectedFile)
            } catch (e) {
                local = String(selectedFile)
            }
            loadKml(local)
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        padding: ScreenTools.defaultFontPixelWidth

        ColumnLayout {
            width: Math.max(scroll.width - ScreenTools.defaultFontPixelWidth * 2, 1)
            spacing: ScreenTools.defaultFontPixelHeight * 0.85

            QGCLabel {
                Layout.fillWidth: true
                text: "SPLIT LAND"
                font.family: ScreenTools.fixedFontFamily
                font.weight: Font.Bold
                font.pointSize: ScreenTools.defaultFontPointSize * 1.25
            }
            QGCLabel {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.family: ScreenTools.fixedFontFamily
                font.pointSize: ScreenTools.smallFontPointSize
                color: "#8B9199"
                text: "Three steps. Same drones you fly. Does not arm or take off."
            }

            // Step 1
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: step1.implicitHeight + 20
                color: qgcPal.windowShade
                border.width: 1
                border.color: qgcPal.buttonBorder
                ColumnLayout {
                    id: step1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        QGCLabel {
                            text: "1"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                            color: qgcPal.colorBlue
                        }
                        QGCLabel {
                            text: "Find drones"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.05
                        }
                        Item { Layout.fillWidth: true }
                        QGCLabel {
                            text: _droneCount > 0 ? (_droneCount + " ready") : "None yet"
                            font.family: ScreenTools.fixedFontFamily
                            color: _droneCount > 0 ? qgcPal.colorGreen : qgcPal.colorYellow
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: "#8B9199"
                        text: "Plug in radios or use UDP. Swarm backend is used automatically when it is running."
                    }
                    QGCButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
                        text: _droneCount > 0 ? "Drones found" : "Connect"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        primary: _droneCount === 0
                        onClicked: connectRadios()
                    }
                    QGCLabel {
                        text: showUsbLinks ? "Hide USB ports" : "I am using USB"
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: qgcPal.colorBlue
                        font.underline: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showUsbLinks = !showUsbLinks
                        }
                    }
                    Repeater {
                        model: showUsbLinks ? getAvailablePorts() : []
                        QGCButton {
                            Layout.fillWidth: true
                            visible: showUsbLinks
                            text: (modelData.connected ? "Linked  " : "Use  ") + modelData.port
                            enabled: !modelData.connected
                            font.family: ScreenTools.fixedFontFamily
                            onClicked: connectToPort(modelData.port, modelData.index + 1)
                        }
                    }
                }
            }

            // Step 2
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: step2.implicitHeight + 20
                color: qgcPal.windowShade
                border.width: 1
                border.color: landPath.length >= 3 ? qgcPal.colorGreen : qgcPal.buttonBorder
                ColumnLayout {
                    id: step2
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        QGCLabel {
                            text: "2"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                            color: qgcPal.colorBlue
                        }
                        QGCLabel {
                            text: "Choose the land"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.05
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: ScreenTools.fixedFontFamily
                        text: fileName.length
                              ? (fileName + "  ·  " + formatArea(totalAreaM2) + "  ·  100%")
                              : "Set scan size, then use the map — or open a KML polygon."
                        color: fileName.length ? qgcPal.text : qgcPal.colorGrey
                        elide: Text.ElideMiddle
                    }
                    QGCLabel {
                        visible: fileName !== "Land on map" && fileName.length > 0
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: "#8B9199"
                        text: "KML sets the size. Clear land to use the slider."
                    }
                    RowLayout {
                        visible: _mapLand || fileName.length === 0
                        Layout.fillWidth: true
                        QGCLabel {
                            text: "SCAN SIZE"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: "#8B9199"
                        }
                        Item { Layout.fillWidth: true }
                        QGCLabel {
                            text: formatScanSize(scanSizeM)
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                        }
                    }
                    Slider {
                        id: scanSizeSlider
                        visible: _mapLand || fileName.length === 0
                        Layout.fillWidth: true
                        from: 200
                        to: 5000
                        stepSize: 50
                        value: scanSizeM
                        live: true
                        onMoved: setScanSize(value)
                    }
                    RowLayout {
                        visible: _mapLand || fileName.length === 0
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: [
                                { label: "250 m", m: 250 },
                                { label: "500 m", m: 500 },
                                { label: "1 km", m: 1000 },
                                { label: "2 km", m: 2000 },
                                { label: "5 km", m: 5000 }
                            ]
                            QGCButton {
                                Layout.fillWidth: true
                                text: modelData.label
                                font.family: ScreenTools.fixedFontFamily
                                font.pointSize: ScreenTools.smallFontPointSize
                                primary: Math.abs(scanSizeM - modelData.m) < 1
                                onClicked: setScanSize(modelData.m)
                            }
                        }
                    }
                    QGCLabel {
                        visible: _mapLand || fileName.length === 0
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: "#8B9199"
                        text: "Zoom does not change size. This is the field the drones split."
                    }
                    QGCButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
                        text: "Use land on this map"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        primary: landPath.length < 3
                        onClicked: landFromMap()
                    }
                    QGCButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                        text: fileName.length && fileName !== "Land on map" ? "Choose a different KML" : "Choose KML file"
                        font.family: ScreenTools.fixedFontFamily
                        onClicked: kmlDialog.open()
                    }
                    QGCLabel {
                        visible: landPath.length > 0
                        text: "Clear land"
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: "#8B9199"
                        font.underline: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: clearAll()
                        }
                    }
                }
            }

            // Step 3
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: step3.implicitHeight + 20
                color: qgcPal.windowShade
                border.width: 1
                border.color: qgcPal.buttonBorder
                ColumnLayout {
                    id: step3
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        QGCLabel {
                            text: "3"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                            color: qgcPal.colorBlue
                        }
                        QGCLabel {
                            text: "Enter each drone's % — not forced equal"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.05
                        }
                        Item { Layout.fillWidth: true }
                        QGCLabel {
                            visible: _droneCount > 0
                            text: percentSum().toFixed(0) + " / 100%"
                            font.family: ScreenTools.fixedFontFamily
                            color: Math.abs(percentSum() - 100) < 0.6 ? qgcPal.colorGreen : qgcPal.colorYellow
                        }
                    }
                    QGCLabel {
                        visible: _droneCount === 0
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: ScreenTools.fixedFontFamily
                        color: qgcPal.colorYellow
                        text: "Connect drones in step 1 first."
                    }
                    Repeater {
                        model: shareModel
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                Layout.fillWidth: true
                                Rectangle { width: 10; height: 10; color: accent; border.width: 1; border.color: Qt.darker(accent, 1.4) }
                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: name
                                    font.family: ScreenTools.fixedFontFamily
                                    font.bold: true
                                }
                                QGCTextField {
                                    text: percent.toString()
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                                    font.family: ScreenTools.fixedFontFamily
                                    onTextChanged: {
                                        var n = parseInt(text)
                                        if (!isNaN(n) && n !== percent)
                                            setPercent(index, n)
                                    }
                                    onEditingFinished: {
                                        var n = parseInt(text)
                                        if (!isNaN(n))
                                            setPercent(index, n)
                                    }
                                }
                                QGCLabel {
                                    text: "%"
                                    font.family: ScreenTools.fixedFontFamily
                                    font.bold: true
                                }
                            }
                            Slider {
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                stepSize: 5
                                value: percent
                                live: true
                                onMoved: setPercent(index, value)
                            }
                        }
                    }
                    QGCButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.0
                        text: "Draw split on map"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        primary: true
                        enabled: true
                        onClicked: applySplit()
                    }
                    QGCLabel {
                        visible: _droneCount > 0 && Math.abs(percentSum() - 100) >= 0.6
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: qgcPal.colorYellow
                        text: "Percents must add to 100%. Type a value or use the slider."
                    }
                    QGCLabel {
                        text: "Equal shares"
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: qgcPal.colorBlue
                        font.underline: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: equalSplit()
                        }
                    }
                }
            }

            // Step 4 — survey + upload
            Rectangle {
                Layout.fillWidth: true
                visible: assignments.length > 0
                implicitHeight: step4.implicitHeight + 20
                color: qgcPal.windowShade
                border.width: 1
                border.color: qgcPal.buttonBorder
                ColumnLayout {
                    id: step4
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        QGCLabel {
                            text: "4"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                            color: qgcPal.colorBlue
                        }
                        QGCLabel {
                            text: "Survey and upload"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.05
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: "#8B9199"
                        text: "Each colored piece gets its own lawnmower survey. Waypoints upload to that drone only."
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel {
                            text: "HEIGHT"
                            font.family: ScreenTools.fixedFontFamily
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: "#8B9199"
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 10
                            to: 120
                            stepSize: 5
                            value: surveyAltM
                            onMoved: surveyAltM = value
                        }
                        QGCLabel {
                            text: Math.round(surveyAltM) + " m"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel {
                            text: "SPACING"
                            font.family: ScreenTools.fixedFontFamily
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: "#8B9199"
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 8
                            to: 80
                            stepSize: 2
                            value: surveySpacingM
                            onMoved: surveySpacingM = value
                        }
                        QGCLabel {
                            text: Math.round(surveySpacingM) + " m"
                            font.family: ScreenTools.fixedFontFamily
                            font.bold: true
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                        }
                    }
                    QGCButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
                        text: "Make survey waypoints"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        primary: true
                        onClicked: makeSurvey()
                    }
                    QGCButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
                        text: "Upload to each drone"
                        font.family: ScreenTools.fixedFontFamily
                        font.weight: Font.Bold
                        onClicked: uploadSurveys()
                    }
                }
            }

            Repeater {
                model: assignments
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    color: qgcPal.windowShadeDark
                    border.width: 1
                    border.color: modelData.color
                    QGCLabel {
                        anchors.fill: parent
                        anchors.margins: 8
                        text: modelData.name + "   " + modelData.percent.toFixed(0) + "%   " + formatArea(modelData.areaM2) + (modelData.wpCount ? ("   " + modelData.wpCount + " wp") : "")
                        font.family: ScreenTools.fixedFontFamily
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth: true
                Layout.bottomMargin: ScreenTools.defaultFontPixelHeight
                wrapMode: Text.WordWrap
                font.family: ScreenTools.fixedFontFamily
                font.pointSize: ScreenTools.smallFontPointSize
                color: "#8B9199"
                text: statusText
            }
        }
    }

    function getAvailablePorts() {
        var ports = []
        var linkConfigs = QGroundControl.linkManager ? QGroundControl.linkManager.linkConfigurations : null
        var acmPorts = ["/dev/ttyACM0", "/dev/ttyACM1", "/dev/ttyACM2"]
        for (var i = 0; i < acmPorts.length; i++) {
            var port = acmPorts[i]
            var isConnected = false
            if (linkConfigs) {
                for (var j = 0; j < linkConfigs.count; j++) {
                    var config = linkConfigs.get(j)
                    if (config && config.portName === port) {
                        isConnected = true
                        break
                    }
                }
            }
            ports.push({ port: port, index: i, connected: isConnected })
        }
        return ports
    }

    function connectToPort(portName, vehicleNumber) {
        _lastError = ""
        var linkManager = QGroundControl.linkManager
        if (!linkManager) {
            showError("Connection Error", "LinkManager not available")
            return
        }
        var linkConfigs = linkManager.linkConfigurations
        var existingConfig = null
        for (var i = 0; i < linkConfigs.count; i++) {
            var config = linkConfigs.get(i)
            if (config && config.portName === portName) {
                existingConfig = config
                break
            }
        }
        if (existingConfig) {
            try {
                linkManager.createConnectedLink(existingConfig)
                statusText = "Connecting " + portName + "…"
            } catch (e) {
                showError("Connection Error", e.toString())
            }
            return
        }
        try {
            var linkName = "Vehicle " + vehicleNumber + " - " + portName
            var newConfig = linkManager.createConfiguration(LinkConfiguration.TypeSerial, linkName)
            if (!newConfig) {
                showError("Configuration Error", "Could not create serial link. Use Settings → Comm Links.")
                return
            }
            newConfig.portName = portName
            newConfig.baud = 115200
            newConfig.dynamic = false
            linkManager.endCreateConfiguration(newConfig)
            Qt.callLater(function () {
                var savedConfig = null
                var cfgs = linkManager.linkConfigurations
                for (var k = 0; k < cfgs.count; k++) {
                    var cfg = cfgs.get(k)
                    if (cfg && (cfg.portName === portName || cfg.name === linkName)) {
                        savedConfig = cfg
                        break
                    }
                }
                if (!savedConfig) {
                    showError("Configuration Error", "Link saved but not found. Try Settings → Comm Links.")
                    return
                }
                try {
                    linkManager.createConnectedLink(savedConfig)
                    statusText = "Connecting " + portName + " as vehicle " + vehicleNumber + "…"
                } catch (e2) {
                    showError("Connection Error", e2.toString())
                }
            })
        } catch (e) {
            showError("Connection Error", e.toString() + "\nUse Settings → Comm Links if this keeps failing.")
        }
    }

    function showError(title, message) {
        if (mainWindow && typeof mainWindow.showMessageDialog === "function")
            mainWindow.showMessageDialog(title, message, Dialog.Ok)
        else
            console.error("ASTHRA ERROR:", title, "-", message)
    }
}
