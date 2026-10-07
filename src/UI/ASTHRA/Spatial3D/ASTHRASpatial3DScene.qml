/****************************************************************************
 *
 * ASTHRA Spatial 3D — Qt Quick 3D scene. Telemetry-driven, read-only.
 *
 ****************************************************************************/

import QtQuick
import QtQuick3D
import QtPositioning

import QGroundControl
import QGroundControl.Controls

Item {
    id: spatialScene
    anchors.fill: parent

    property var planMasterController: null
    property var cameraController: null

    readonly property var _mvm: QGroundControl.multiVehicleManager
    readonly property var _active: _mvm ? _mvm.activeVehicle : null
    readonly property var _gcsPos: QGroundControl.qgcPositionManger ? QGroundControl.qgcPositionManger.gcsPosition : QtPositioning.coordinate()
    readonly property bool operatorValid: _gcsPos && _gcsPos.isValid
    readonly property var _missionController: planMasterController ? planMasterController.missionController : null
    readonly property var _geoFenceController: planMasterController ? planMasterController.geoFenceController : null

    property var gpsRef: QtPositioning.coordinate()
    property string originLabel: "ORIGIN UNSET"
    property string originKind: ""
    property bool originLocked: false
    property vector3d droneEnu: Qt.vector3d(0, 0, 0)
    property vector3d operatorEnu: Qt.vector3d(0, 0, 0)
    property bool stale: false
    property bool headingEstimated: false
    property bool fovEstimated: true
    property bool gpsWeak: false
    property vector3d frozenEnu: Qt.vector3d(0, 0, 0)
    property bool poseFrozen: false
    property real fovYaw: 0
    property real fovPitch: 0
    property real groundSpeed: 0
    property real courseDeg: 0
    property string altSource: "REL"
    property string lookLabel: "—"
    property real plotHalf: 100
    property real gridStep: 25
    property string rangeLegend: "25/50/100"
    property real fleetExtent: 0

    readonly property var _fleetColors: ["#4A90D9", "#2A8B55", "#C9A227", "#D97706", "#C0392B", "#534AB7"]
    readonly property color _bg: "#0E1216"
    readonly property color _amber: "#E0A526"
    readonly property color _steel: "#4A6378"

    // World size of one screen pixel at the focus distance, stepped so lines don't rebuild every frame.
    readonly property real _pxRaw: perspCam.position.minus(droneEnu).length()
                                   * 2 * Math.tan(perspCam.fieldOfView * Math.PI / 360) / Math.max(1, view3d.height)
    readonly property real px: Math.pow(1.15, Math.round(Math.log(Math.max(1e-4, _pxRaw)) / Math.log(1.15)))

    function fleetColorAt(index) {
        return _fleetColors[Math.max(0, index) % _fleetColors.length]
    }

    function enuFor(veh) {
        if (!veh)
            return Qt.vector3d(0, 0, 0)
        if (veh === _active)
            return droneEnu
        if (!veh.coordinate || !veh.coordinate.isValid)
            return Qt.vector3d(0, 0, 0)
        var alt = veh.altitudeRelative ? veh.altitudeRelative.value : 0
        return toEnu(veh.coordinate, isNaN(alt) ? 0 : alt)
    }

    function _updateFleetFrame() {
        var vehicles = _mvm ? _mvm.vehicles : null
        var n = 0
        var cx = 0, cy = 0, cz = 0
        var pts = []
        for (var i = 0; vehicles && i < vehicles.count; i++) {
            var v = vehicles.get(i)
            if (!v || !v.coordinate || !v.coordinate.isValid)
                continue
            var e = enuFor(v)
            pts.push(e)
            cx += e.x; cy += e.y; cz += e.z
            n++
        }
        var ext = 0
        var r = 0
        if (n > 0) {
            cx /= n; cy /= n; cz /= n
            for (var k = 0; k < pts.length; k++) {
                var dx = pts[k].x - cx, dz = pts[k].z - cz, dy = pts[k].y - cy
                r = Math.max(r, Math.sqrt(dx * dx + dy * dy + dz * dz))
                ext = Math.max(ext, Math.abs(pts[k].x), Math.abs(pts[k].z))
            }
        }
        fleetExtent = ext
        if (cameraController) {
            cameraController.fleetCenter = Qt.vector3d(cx, cy, cz)
            cameraController.fleetRadius = r
            cameraController.fleetCount = n
            cameraController.viewAspect = view3d.width / Math.max(1, view3d.height)
            cameraController.fovDeg = perspCam.fieldOfView
        }
    }

    function _driveCamera() {
        if (!cameraController)
            return
        cameraController.targetPos = _active ? droneEnu : Qt.vector3d(0, 0, 0)
        cameraController.targetHeading = _active && _active.heading ? _active.heading.value : 0
        cameraController.operatorPos = Qt.vector3d(operatorEnu.x, 1.7, operatorEnu.z)
        cameraController.operatorValid = operatorValid
        if (cameraController.mode !== "free")
            cameraController.apply()
    }

    function toEnu(coord, altM) {
        var ref = gpsRef
        if (!coord || !ref || !ref.isValid)
            return Qt.vector3d(0, 0, 0)
        var lat0 = ref.latitude * Math.PI / 180.0
        var dLat = (coord.latitude - ref.latitude) * Math.PI / 180.0
        var dLon = (coord.longitude - ref.longitude) * Math.PI / 180.0
        var east = dLon * Math.cos(lat0) * 6378137.0
        var north = dLat * 6378137.0
        var up = (altM !== undefined && altM !== null && !isNaN(altM))
                 ? altM
                 : ((coord.altitude || 0) - (ref.altitude || 0))
        return Qt.vector3d(east, up, -north)
    }

    function _setOrigin(coord, label, kind) {
        if (!coord || !coord.isValid)
            return
        var prevKind = originKind
        gpsRef = QtPositioning.coordinate(coord.latitude, coord.longitude, 0)
        originLabel = label
        originKind = kind
        originLocked = true
        if (prevKind !== kind)
            rebuildOverlays()
    }

    function _updateOrigin() {
        // Prefer a stable origin. Never keep recentering on a moving vehicle.
        if (operatorValid) {
            _setOrigin(_gcsPos, "GCS", "gcs")
            return
        }
        if (_active && _active.homePosition && _active.homePosition.isValid) {
            _setOrigin(_active.homePosition, "Home", "home")
            return
        }
        if (originLocked && gpsRef && gpsRef.isValid)
            return
        if (_active && _active.coordinate && _active.coordinate.isValid) {
            _setOrigin(_active.coordinate, "Vehicle (frozen)", "vehicle")
            return
        }
        originLabel = "Not set"
        originKind = ""
        originLocked = false
    }

    function _relAltOfCoord(coord) {
        var altRel = (_active && _active.altitudeRelative) ? _active.altitudeRelative.value : 0
        if (!coord || isNaN(coord.altitude) || !_active || !_active.coordinate)
            return altRel
        var nowAmsl = _active.coordinate.altitude
        if (isNaN(nowAmsl))
            return altRel
        return altRel + (coord.altitude - nowAmsl)
    }

    function _updatePlotScale() {
        var r = 80
        r = Math.max(r, Math.abs(droneEnu.x), Math.abs(droneEnu.z), Math.abs(droneEnu.y), fleetExtent)
        if (_active && _active.homePosition && _active.homePosition.isValid && gpsRef && gpsRef.isValid) {
            var h = toEnu(_active.homePosition, 0)
            r = Math.max(r, Math.abs(h.x), Math.abs(h.z))
        }
        var steps = [25, 50, 100, 200, 250, 500]
        var want = r * 1.6 / 4
        var step = steps[steps.length - 1]
        for (var i = 0; i < steps.length; i++) {
            if (steps[i] >= want) {
                step = steps[i]
                break
            }
        }
        gridStep = step
        plotHalf = step * 4
        rangeLegend = Math.round(gridStep) + "/" + Math.round(gridStep * 2) + "/" + Math.round(plotHalf)
    }

    function _magUnhealthy() {
        if (!_active)
            return false
        var present = (_active.sensorsPresentBits & 0x04) !== 0
        var healthy = (_active.sensorsHealthBits & 0x04) !== 0
        return present && !healthy
    }

    function _rangefinderM() {
        if (!_active || !_active.distanceSensors)
            return NaN
        var ds = _active.distanceSensors
        var v = ds.rotationPitch270 ? ds.rotationPitch270.value : NaN
        if (isNaN(v) || v <= 0 || v > 500)
            return NaN
        return v
    }

    function _gpsLock() {
        if (!_active || !_active.gps)
            return 0
        return _active.gps.lock.rawValue
    }

    function _hdop() {
        if (!_active || !_active.gps)
            return NaN
        return _active.gps.hdop.value
    }

    function _updateVehicleDerived() {
        var commLost = !_active || (_active.vehicleLinkManager && _active.vehicleLinkManager.communicationLost)
        stale = commLost
        headingEstimated = _magUnhealthy()
        gpsWeak = !_active || _gpsLock() < 3 || (!isNaN(_hdop()) && _hdop() > 2.5)
        if (!_active) {
            lookLabel = "—"
            fovEstimated = true
            altSource = "—"
            groundSpeed = 0
            courseDeg = 0
            poseFrozen = false
            droneEnu = Qt.vector3d(0, 0, 0)
            _updatePlotScale()
            return
        }

        var rng = _rangefinderM()
        if (!isNaN(rng))
            altSource = "RNG"
        else if (_active.altitudeRelative && !isNaN(_active.altitudeRelative.value))
            altSource = "REL"
        else
            altSource = "AMSL"

        var altRel = _active.altitudeRelative ? _active.altitudeRelative.value : 0
        if (altSource === "RNG")
            altRel = rng
        var coord = _active.coordinate
        var nextEnu = droneEnu
        if (coord && coord.isValid)
            nextEnu = toEnu(coord, altRel)

        if (stale) {
            if (!poseFrozen) {
                frozenEnu = nextEnu
                poseFrozen = true
            }
            droneEnu = frozenEnu
        } else {
            poseFrozen = false
            droneEnu = nextEnu
        }
        _updatePlotScale()

        groundSpeed = _active.groundSpeed ? _active.groundSpeed.value : 0
        if (isNaN(groundSpeed))
            groundSpeed = 0
        courseDeg = (_active.gps && _active.gps.courseOverGround) ? _active.gps.courseOverGround.value : 0

        var hdg = _active.heading ? _active.heading.value : 0
        if (headingEstimated && _active.gps)
            hdg = _active.gps.courseOverGround.value
        fovYaw = hdg
        fovPitch = 0
        fovEstimated = true
        lookLabel = "HDG"

        var gc = _active.gimbalController
        if (gc && gc.activeGimbal) {
            var g = gc.activeGimbal
            var ay = g.absoluteYaw ? g.absoluteYaw.value : NaN
            var ap = g.absolutePitch ? g.absolutePitch.value : NaN
            if (!isNaN(ay) && !isNaN(ap)) {
                fovYaw = ay
                fovPitch = ap
                fovEstimated = false
                lookLabel = "GIMBAL"
            }
        }

        operatorEnu = Qt.vector3d(0, 0, 0)
    }

    function rebuildOverlays() {
        trailModel.clear()
        wpModel.clear()
        wpSegModel.clear()
        fenceModel.clear()
        if (!gpsRef || !gpsRef.isValid)
            return

        if (_active && _active.trajectoryPoints) {
            var pts = _active.trajectoryPoints.list()
            var step = pts.length > 80 ? Math.ceil(pts.length / 80) : 1
            var prev = null
            for (var i = 0; i < pts.length; i += step) {
                var p = pts[i]
                if (!p || !p.isValid)
                    continue
                var e = toEnu(p, _relAltOfCoord(p))
                if (prev) {
                    trailModel.append({ x1: prev.x, y1: prev.y, z1: prev.z, x2: e.x, y2: e.y, z2: e.z })
                }
                prev = e
            }
        }

        if (_missionController && _missionController.visualItems) {
            var vis = _missionController.visualItems
            var lastWp = null
            for (var m = 0; m < vis.count; m++) {
                var item = vis.get(m)
                if (!item || !item.specifiesCoordinate || !item.coordinate || !item.coordinate.isValid)
                    continue
                if (item.isStandaloneCoordinate)
                    continue
                var walt = 10
                if (item.altitude && item.altitude.value !== undefined && !isNaN(item.altitude.value))
                    walt = item.altitude.value
                var we = toEnu(item.coordinate, walt)
                wpModel.append({ px: we.x, py: we.y, pz: we.z })
                if (lastWp) {
                    wpSegModel.append({ x1: lastWp.x, y1: lastWp.y, z1: lastWp.z, x2: we.x, y2: we.y, z2: we.z })
                }
                lastWp = we
            }
        }

        if (_geoFenceController) {
            _appendFencePolygons(_geoFenceController.polygons)
            _appendFenceCircles(_geoFenceController.circles)
        }
    }

    function _appendFencePolygons(polys) {
        if (!polys)
            return
        for (var i = 0; i < polys.count; i++) {
            var poly = polys.get(i)
            if (!poly || !poly.path)
                continue
            var path = poly.path
            var inclusion = poly.inclusion === true
            for (var k = 0; k < path.length; k++) {
                var a = path[k]
                var b = path[(k + 1) % path.length]
                if (!a || !b)
                    continue
                var ea = toEnu(a, 0.4)
                var eb = toEnu(b, 0.4)
                fenceModel.append({
                                      x1: ea.x, y1: ea.y, z1: ea.z,
                                      x2: eb.x, y2: eb.y, z2: eb.z,
                                      col: inclusion ? "#1D9E75" : "#E24B4A"
                                  })
            }
        }
    }

    function _appendFenceCircles(circles) {
        if (!circles)
            return
        for (var i = 0; i < circles.count; i++) {
            var c = circles.get(i)
            if (!c || !c.center || !c.center.isValid)
                continue
            var segs = 24
            var r = (c.radius && c.radius.value !== undefined) ? c.radius.value : 0
            var inclusion = c.inclusion === true
            var col = inclusion ? "#1D9E75" : "#E24B4A"
            var prevE = null
            var firstE = null
            for (var s = 0; s <= segs; s++) {
                var ang = (s / segs) * Math.PI * 2
                var cc = QtPositioning.coordinate(
                            c.center.latitude + (r * Math.cos(ang)) / 110540.0,
                            c.center.longitude + (r * Math.sin(ang)) / (111320.0 * Math.cos(c.center.latitude * Math.PI / 180)),
                            0)
                var e = toEnu(cc, 0.4)
                if (s === 0)
                    firstE = e
                if (prevE) {
                    fenceModel.append({ x1: prevE.x, y1: prevE.y, z1: prevE.z, x2: e.x, y2: e.y, z2: e.z, col: col })
                }
                prevE = e
            }
        }
    }

    Component.onCompleted: {
        _updateOrigin()
        _updateVehicleDerived()
        rebuildOverlays()
        if (cameraController)
            cameraController.camera = perspCam
    }

    on_GcsPosChanged: _updateOrigin()
    on_ActiveChanged: {
        originLocked = false
        originKind = ""
        _updateOrigin()
        _updateVehicleDerived()
        rebuildOverlays()
    }

    Connections {
        target: _active
        function onCoordinateChanged() {
            _updateVehicleDerived()
            if (spatialScene.visible)
                _driveCamera()
        }
        function onHomePositionChanged() { _updateOrigin(); rebuildOverlays() }
    }

    Connections {
        target: _active && _active.vehicleLinkManager ? _active.vehicleLinkManager : null
        function onCommunicationLostChanged() { _updateVehicleDerived() }
    }

    Connections {
        target: _missionController
        function onVisualItemsChanged() { rebuildOverlays() }
    }

    Timer {
        interval: 400
        running: spatialScene.visible
        repeat: true
        onTriggered: {
            _updateOrigin()
            _updateFleetFrame()
            _updateVehicleDerived()
            _driveCamera()
        }
    }

    Timer {
        interval: 1200
        running: spatialScene.visible
        repeat: true
        onTriggered: rebuildOverlays()
    }

    ListModel { id: trailModel }
    ListModel { id: wpModel }
    ListModel { id: wpSegModel }
    ListModel { id: fenceModel }

    View3D {
        id: view3d
        anchors.fill: parent
        camera: perspCam
        visible: spatialScene.visible
        enabled: spatialScene.visible
        renderMode: View3D.Offscreen

        environment: SceneEnvironment {
            clearColor: spatialScene._bg
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            fog: Fog {
                enabled: true
                color: spatialScene._bg
                depthEnabled: true
                depthNear: Math.max(spatialScene.plotHalf * 1.2, perspCam.position.length() * 1.3)
                depthFar: depthNear * 3.5
            }
        }

        PerspectiveCamera {
            id: perspCam
            position: Qt.vector3d(18, 16, 28)
            eulerRotation: Qt.vector3d(-28, 35, 0)
            clipNear: 0.2
            clipFar: 80000
            fieldOfView: 50
            property bool smooth: cameraController && cameraController.mode !== "free"
            Behavior on position {
                enabled: perspCam.smooth
                Vector3dAnimation { duration: 160; easing.type: Easing.Linear }
            }
        }

        DirectionalLight {
            eulerRotation.x: -58
            eulerRotation.y: 28
            brightness: 1.15
            castsShadow: true
            shadowFactor: 45
            shadowMapQuality: Light.ShadowMapQualityHigh
            shadowMapFar: Math.min(600, spatialScene.plotHalf * 2.5)
            csmNumSplits: 2
            pcfFactor: 2
        }

        DirectionalLight {
            eulerRotation.x: -20
            eulerRotation.y: -150
            brightness: 0.4
        }

        DirectionalLight {
            eulerRotation.x: 70
            brightness: 0.12
        }

        // Plot table
        Model {
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(Math.max(4, spatialScene.plotHalf / 50), Math.max(4, spatialScene.plotHalf / 50), 1)
            position: Qt.vector3d(0, 0, 0)
            pickable: false
            receivesShadows: true
            materials: PrincipledMaterial {
                baseColor: "#141A20"
                roughness: 1
                metalness: 0
            }
        }

        // Minor grid, five cells per major cell
        Repeater3D {
            model: 41
            ASTHRASpatialLine3D {
                property real g: (index - 20) * spatialScene.gridStep / 5
                visible: index % 5 !== 0
                p1: Qt.vector3d(-spatialScene.plotHalf, 0.01, g)
                p2: Qt.vector3d(spatialScene.plotHalf, 0.01, g)
                color: "#1C242C"
                lineWidth: spatialScene.px * 0.8
            }
        }
        Repeater3D {
            model: 41
            ASTHRASpatialLine3D {
                property real g: (index - 20) * spatialScene.gridStep / 5
                visible: index % 5 !== 0
                p1: Qt.vector3d(g, 0.01, -spatialScene.plotHalf)
                p2: Qt.vector3d(g, 0.01, spatialScene.plotHalf)
                color: "#1C242C"
                lineWidth: spatialScene.px * 0.8
            }
        }

        // Major grid; the two lines through the origin are the N-S / E-W axes
        Repeater3D {
            model: 9
            ASTHRASpatialLine3D {
                property real g: (index - 4) * spatialScene.gridStep
                p1: Qt.vector3d(-spatialScene.plotHalf, 0.02, g)
                p2: Qt.vector3d(spatialScene.plotHalf, 0.02, g)
                color: index === 4 ? "#3B4A57" : "#28323C"
                lineWidth: spatialScene.px * (index === 4 ? 1.6 : 1.1)
            }
        }
        Repeater3D {
            model: 9
            ASTHRASpatialLine3D {
                property real g: (index - 4) * spatialScene.gridStep
                p1: Qt.vector3d(g, 0.02, -spatialScene.plotHalf)
                p2: Qt.vector3d(g, 0.02, spatialScene.plotHalf)
                color: index === 4 ? "#3B4A57" : "#28323C"
                lineWidth: spatialScene.px * (index === 4 ? 1.6 : 1.1)
            }
        }

        // Range rings; the outer one marks the plot boundary
        Repeater3D {
            model: 3
            ASTHRASpatialRing3D {
                position: Qt.vector3d(0, 0.03, 0)
                radius: index === 2 ? spatialScene.plotHalf : spatialScene.gridStep * (index + 1)
                segments: 72
                color: index === 2 ? spatialScene._steel : "#31495B"
                lineWidth: spatialScene.px * (index === 2 ? 1.8 : 1.3)
            }
        }

        // Bearing ticks every 30 degrees outside the boundary ring, north in amber
        Repeater3D {
            model: 12
            ASTHRASpatialLine3D {
                readonly property real _b: index * 30 * Math.PI / 180
                readonly property real _r0: spatialScene.plotHalf
                readonly property real _r1: spatialScene.plotHalf + spatialScene.gridStep * (index % 3 === 0 ? 0.3 : 0.15)
                p1: Qt.vector3d(Math.sin(_b) * _r0, 0.03, -Math.cos(_b) * _r0)
                p2: Qt.vector3d(Math.sin(_b) * _r1, 0.03, -Math.cos(_b) * _r1)
                color: index === 0 ? spatialScene._amber : spatialScene._steel
                lineWidth: spatialScene.px * (index === 0 ? 3.0 : 2.0)
            }
        }

        // Origin reticle
        Node {
            position: Qt.vector3d(0, 0.05, 0)
            readonly property real _s: Math.max(2, spatialScene.px * 22)
            ASTHRASpatialLine3D { p1: Qt.vector3d(-parent._s, 0, 0); p2: Qt.vector3d(parent._s, 0, 0); color: spatialScene._amber; lineWidth: spatialScene.px * 2 }
            ASTHRASpatialLine3D { p1: Qt.vector3d(0, 0, -parent._s); p2: Qt.vector3d(0, 0, parent._s); color: spatialScene._amber; lineWidth: spatialScene.px * 2 }
            ASTHRASpatialRing3D { radius: parent._s * 0.55; segments: 32; color: spatialScene._amber; lineWidth: spatialScene.px * 2 }
        }

        ASTHRASpatialLine3D {
            visible: _active && !isNaN(spatialScene.droneEnu.x)
            p1: Qt.vector3d(0, 1.6, 0)
            p2: Qt.vector3d(spatialScene.droneEnu.x, Math.max(0.2, spatialScene.droneEnu.y), spatialScene.droneEnu.z)
            color: spatialScene.stale ? "#3D4247" : spatialScene._steel
            lineWidth: spatialScene.px * 1.2
            opacityFactor: 0.5
        }

        Node {
            visible: spatialScene.operatorValid
            position: Qt.vector3d(0, 0.85, 0)
            Model {
                source: "#Cube"
                scale: Qt.vector3d(0.008, 0.016, 0.008)
                materials: PrincipledMaterial { baseColor: "#D8DCE0"; roughness: 0.85; metalness: 0.05 }
            }
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, 1.05, 0)
                scale: Qt.vector3d(0.006, 0.006, 0.006)
                materials: PrincipledMaterial { baseColor: "#F0F2F4"; roughness: 0.8 }
            }
        }

        Node {
            id: homeNode
            visible: _active && _active.homePosition && _active.homePosition.isValid
            position: _active && _active.homePosition && _active.homePosition.isValid ? toEnu(_active.homePosition, 0.25) : Qt.vector3d(0, 0, 0)

            Model {
                source: "#Cube"
                scale: Qt.vector3d(0.014, 0.003, 0.014)
                materials: PrincipledMaterial { baseColor: "#8B9199"; roughness: 0.7 }
            }
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, 0.45, 0)
                scale: Qt.vector3d(0.004, 0.009, 0.004)
                materials: PrincipledMaterial { baseColor: "#F0F2F4"; roughness: 0.6 }
            }
        }

        Repeater3D {
            model: _mvm ? _mvm.vehicles : []
            delegate: ASTHRASpatialVehicleNode {
                vehicle: object
                fleetColor: spatialScene.fleetColorAt(index)
                isActive: _active && object && object === _active
                stale: spatialScene.stale && isActive
                gpsWeak: spatialScene.gpsWeak && isActive
                headingEstimated: spatialScene.headingEstimated && isActive
                fovEstimated: spatialScene.fovEstimated
                fovYaw: isActive ? spatialScene.fovYaw : (object && object.heading ? object.heading.value : 0)
                fovPitch: isActive ? spatialScene.fovPitch : 0
                showFov: isActive
                groundSpeed: isActive ? spatialScene.groundSpeed : 0
                courseDeg: isActive ? spatialScene.courseDeg : 0
                enuPos: spatialScene.enuFor(object)
                cameraPos: perspCam.position
                viewHeightPx: view3d.height
                viewFovDeg: perspCam.fieldOfView
            }
        }

        Repeater3D {
            model: trailModel
            delegate: ASTHRASpatialLine3D {
                p1: Qt.vector3d(x1, y1, z1)
                p2: Qt.vector3d(x2, y2, z2)
                color: "#2D4A5F"
                lineWidth: Math.max(0.08, spatialScene.px * 1.6)
                opacityFactor: 0.9
            }
        }

        Repeater3D {
            model: wpSegModel
            delegate: ASTHRASpatialLine3D {
                p1: Qt.vector3d(x1, y1, z1)
                p2: Qt.vector3d(x2, y2, z2)
                color: "#D4A017"
                lineWidth: Math.max(0.08, spatialScene.px * 2)
                opacityFactor: 0.85
            }
        }

        Repeater3D {
            model: wpModel
            delegate: Model {
                source: "#Cube"
                position: Qt.vector3d(px, py, pz)
                scale: Qt.vector3d(0.007, 0.007, 0.007)
                materials: PrincipledMaterial {
                    baseColor: "#D4A017"
                    roughness: 0.75
                    metalness: 0.05
                }
            }
        }

        Repeater3D {
            model: fenceModel
            delegate: ASTHRASpatialLine3D {
                p1: Qt.vector3d(x1, y1, z1)
                p2: Qt.vector3d(x2, y2, z2)
                color: col
                lineWidth: Math.max(0.1, spatialScene.px * 2.5)
            }
        }
    }

    function _deg3(v) {
        var n = Math.round(((v % 360) + 360) % 360) % 360
        return (n < 10 ? "00" : (n < 100 ? "0" : "")) + n
    }

    function _fmt(v, digits) {
        return isNaN(v) ? "--" : v.toFixed(digits)
    }

    component ProjectedText: Text {
        id: projText
        property vector3d worldPos
        property vector3d _s: Qt.vector3d(-1000, -1000, -1)
        x: _s.x - width / 2
        y: _s.y - height / 2
        visible: _s.z > 0
        font.family: ScreenTools.fixedFontFamily
        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
        FrameAnimation {
            running: spatialScene.visible
            onTriggered: projText._s = view3d.mapFrom3DScene(projText.worldPos)
        }
    }

    // 2D overlay projected from the 3D scene every frame
    Item {
        anchors.fill: parent
        visible: spatialScene.visible

        Repeater {
            model: 3
            ProjectedText {
                readonly property real _r: index === 2 ? spatialScene.plotHalf : spatialScene.gridStep * (index + 1)
                worldPos: Qt.vector3d(_r * 0.7071, 0.05, -_r * 0.7071)
                text: Math.round(_r) + " m"
                color: "#6F8597"
            }
        }

        Repeater {
            model: ["N", "E", "S", "W"]
            ProjectedText {
                required property string modelData
                required property int index
                readonly property real _r: spatialScene.plotHalf + spatialScene.gridStep * 0.6
                readonly property real _b: index * Math.PI / 2
                worldPos: Qt.vector3d(Math.sin(_b) * _r, 0.05, -Math.cos(_b) * _r)
                text: modelData
                color: index === 0 ? spatialScene._amber : "#8BA0B2"
                font.bold: true
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9
            }
        }

        // Per-drone data plates on a leader line
        Repeater {
            model: _mvm ? _mvm.vehicles : []
            delegate: Item {
                id: tag
                required property var object
                required property int index
                property vector3d _screen: Qt.vector3d(-1000, -1000, -1)
                readonly property real _alt: object && object.altitudeRelative ? object.altitudeRelative.value : NaN
                readonly property real _gs: object && object.groundSpeed ? object.groundSpeed.value : NaN
                readonly property real _hdg: object && object.heading ? object.heading.value : NaN
                readonly property bool _armed: object ? object.armed : false
                readonly property bool _lost: object && object.vehicleLinkManager ? object.vehicleLinkManager.communicationLost : false
                readonly property bool _isActive: object === spatialScene._active
                readonly property color _col: spatialScene.fleetColorAt(index)
                readonly property real _lead: _compact ? 26 : 34
                readonly property bool _compact: !_isActive && spatialScene.width < 600

                x: _screen.x
                y: _screen.y
                z: _isActive ? 2 : 1
                visible: _screen.z > 0 && _screen.x > -plate.width && _screen.x < spatialScene.width + plate.width
                         && _screen.y > 0 && _screen.y < spatialScene.height + plate.height

                FrameAnimation {
                    running: tag.object && spatialScene.visible
                    onTriggered: tag._screen = view3d.mapFrom3DScene(spatialScene.enuFor(tag.object))
                }

                Rectangle {
                    x: -0.5
                    y: -tag._lead
                    width: 1
                    height: tag._lead - 16
                    color: tag._col
                }

                Rectangle {
                    id: plate
                    x: Math.max(4 - tag.x, Math.min(-5, spatialScene.width - tag.x - width - 4))
                    y: -tag._lead - height
                    width: plateCol.implicitWidth + 16
                    height: plateCol.implicitHeight + 8
                    color: "#E60E1216"
                    border.width: 1
                    border.color: tag._isActive ? tag._col : "#2E3A45"

                    Rectangle {
                        width: 3
                        height: parent.height
                        color: tag._col
                    }

                    Column {
                        id: plateCol
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Row {
                            spacing: 6
                            Text {
                                text: "V" + (tag.object && tag.object.fleetSlot > 0 ? tag.object.fleetSlot : tag.index + 1)
                                color: tag._col
                                font.family: ScreenTools.fixedFontFamily
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                                font.bold: true
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: tag._compact
                                text: spatialScene._fmt(tag._alt, 1) + " m"
                                color: "#B8C2CC"
                                font.family: ScreenTools.fixedFontFamily
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: chipText.implicitWidth + 8
                                height: chipText.implicitHeight + 2
                                color: tag._lost ? spatialScene._amber : (tag._armed ? "#C0392B" : "#1E262E")
                                border.width: tag._lost || tag._armed ? 0 : 1
                                border.color: "#3A4652"
                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: tag._lost ? "LINK LOST" : (tag._armed ? "ARMED" : "DISARMED")
                                    color: tag._lost ? spatialScene._bg : (tag._armed ? "#FFFFFF" : "#8B9199")
                                    font.family: ScreenTools.fixedFontFamily
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            visible: !tag._compact
                            text: "ALT " + spatialScene._fmt(tag._alt, 1)
                                  + "  GS " + spatialScene._fmt(tag._gs, 1)
                                  + "  HDG " + (isNaN(tag._hdg) ? "---" : spatialScene._deg3(tag._hdg))
                            color: "#B8C2CC"
                            font.family: ScreenTools.fixedFontFamily
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                        }
                    }
                }
            }
        }

        // Camera compass: needle points to north as seen from the current view
        Item {
            id: compass
            visible: spatialScene.width > 420
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            width: dial.width
            height: dial.height + camLabel.implicitHeight + 4
            readonly property real _yaw: perspCam.eulerRotation.y

            Rectangle {
                id: dial
                width: ScreenTools.defaultFontPixelHeight * 4.6
                height: width
                radius: width / 2
                color: "#CC0E1216"
                border.width: 1
                border.color: spatialScene._steel

                Item {
                    anchors.fill: parent
                    rotation: compass._yaw

                    Repeater {
                        model: 12
                        Rectangle {
                            required property int index
                            x: dial.width / 2 - width / 2
                            y: 3
                            width: index % 3 === 0 ? 2 : 1
                            height: index % 3 === 0 ? 7 : 4
                            color: index === 0 ? spatialScene._amber : spatialScene._steel
                            transform: Rotation {
                                origin.x: width / 2
                                origin.y: dial.height / 2 - 3
                                angle: index * 30
                            }
                        }
                    }

                    Rectangle {
                        x: dial.width / 2 - 1
                        y: dial.height * 0.24
                        width: 2
                        height: dial.height * 0.26
                        color: spatialScene._amber
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: dial.height * 0.24 - height
                        text: "N"
                        color: spatialScene._amber
                        font.family: ScreenTools.fixedFontFamily
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                        font.bold: true
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 5
                    height: 5
                    radius: 2.5
                    color: "#B8C2CC"
                }
            }

            Text {
                id: camLabel
                anchors.top: dial.bottom
                anchors.topMargin: 4
                anchors.horizontalCenter: dial.horizontalCenter
                text: "CAM " + spatialScene._deg3(-compass._yaw) + "°"
                color: "#8B9199"
                font.family: ScreenTools.fixedFontFamily
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
            }
        }
    }

    onCameraControllerChanged: {
        if (cameraController)
            cameraController.camera = perspCam
    }
}
