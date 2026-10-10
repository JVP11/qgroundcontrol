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

    readonly property var _fleetColors: ["#4A90D9", "#2FA866", "#C9A227", "#D97706", "#C0392B", "#7A6FE0"]

    readonly property color skyColor: "#0E1317"
    readonly property color groundColor: "#151B21"
    readonly property color gridMinorColor: "#1D262E"
    readonly property color gridMajorColor: "#2B3844"
    readonly property color axisColor: "#3C7FA6"
    readonly property color ringColor: "#3E5468"
    readonly property color frameColor: "#4A5A6A"
    readonly property color accentColor: "#C9A227"

    // Screen space the host panel's own overlays occupy on the right-hand side.
    property real topInset: 8
    property real bottomInset: 8
    readonly property real cornerWidth: Math.max(compass.width, scaleBox.width)

    // Bumped every frame so screen-projected overlays follow the camera.
    property int frameTick: 0

    // Ground metres covered by one screen pixel at the view centre; keeps lines about a pixel wide.
    property real metresPerPx: 0.05
    readonly property real lineM: Math.max(0.02, Math.min(6, metresPerPx))

    function _updateMetresPerPx() {
        var h = Math.max(1, view3d.height)
        metresPerPx = 2 * centreGroundDistance() * Math.tan(perspCam.fieldOfView * Math.PI / 360) / h
    }

    readonly property var ringRadii: [gridStep, gridStep * 2, plotHalf]

    function project(p) {
        frameTick
        return view3d.mapFrom3DScene(p)
    }

    // Ground distance at screen centre, used for the scale bar.
    function centreGroundDistance() {
        frameTick
        var pitch = perspCam.eulerRotation.x * Math.PI / 180
        var fy = Math.sin(pitch)
        var p = perspCam.position
        if (fy < -0.05 && p.y > 0)
            return p.y / -fy
        if (cameraController)
            return p.minus(cameraController.lookTarget).length()
        return 100
    }

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
        plotHalf = Math.min(2000, Math.max(100, Math.ceil(r * 1.6 / 50) * 50))
        gridStep = plotHalf / 4
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
        function onCoordinateChanged() { _updateVehicleDerived() }
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
            if (cameraController) {
                cameraController.targetPos = _active ? droneEnu : Qt.vector3d(0, 0, 0)
                cameraController.targetHeading = _active && _active.heading ? _active.heading.value : 0
                cameraController.operatorPos = Qt.vector3d(operatorEnu.x, 1.7, operatorEnu.z)
                cameraController.operatorValid = operatorValid
                if (cameraController.mode !== "free")
                    cameraController.apply()
            }
            _updateMetresPerPx()
        }
    }

    FrameAnimation {
        running: spatialScene.visible
        onTriggered: spatialScene.frameTick++
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
            clearColor: spatialScene.skyColor
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            fog: Fog {
                enabled: true
                color: spatialScene.skyColor
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
                baseColor: spatialScene.groundColor
                roughness: 0.92
                metalness: 0
            }
        }

        // Minor grid: five cells per major cell
        Repeater3D {
            model: 41
            ASTHRASpatialLine3D {
                property real g: (index - 20) * spatialScene.gridStep / 5
                visible: index % 5 !== 0
                p1: Qt.vector3d(-spatialScene.plotHalf, 0.02, g)
                p2: Qt.vector3d(spatialScene.plotHalf, 0.02, g)
                color: spatialScene.gridMinorColor
                lineWidth: spatialScene.lineM * 0.8
            }
        }
        Repeater3D {
            model: 41
            ASTHRASpatialLine3D {
                property real g: (index - 20) * spatialScene.gridStep / 5
                visible: index % 5 !== 0
                p1: Qt.vector3d(g, 0.02, -spatialScene.plotHalf)
                p2: Qt.vector3d(g, 0.02, spatialScene.plotHalf)
                color: spatialScene.gridMinorColor
                lineWidth: spatialScene.lineM * 0.8
            }
        }

        // Major grid
        Repeater3D {
            model: 9
            ASTHRASpatialLine3D {
                property real g: (index - 4) * spatialScene.gridStep
                visible: index !== 4
                p1: Qt.vector3d(-spatialScene.plotHalf, 0.03, g)
                p2: Qt.vector3d(spatialScene.plotHalf, 0.03, g)
                color: spatialScene.gridMajorColor
                lineWidth: spatialScene.lineM * 1.3
            }
        }
        Repeater3D {
            model: 9
            ASTHRASpatialLine3D {
                property real g: (index - 4) * spatialScene.gridStep
                visible: index !== 4
                p1: Qt.vector3d(g, 0.03, -spatialScene.plotHalf)
                p2: Qt.vector3d(g, 0.03, spatialScene.plotHalf)
                color: spatialScene.gridMajorColor
                lineWidth: spatialScene.lineM * 1.3
            }
        }

        // North-south and east-west axes through the origin
        ASTHRASpatialLine3D {
            p1: Qt.vector3d(0, 0.05, spatialScene.plotHalf)
            p2: Qt.vector3d(0, 0.05, -spatialScene.plotHalf)
            color: spatialScene.axisColor
            lineWidth: spatialScene.lineM * 1.6
            opacityFactor: 0.8
        }
        ASTHRASpatialLine3D {
            p1: Qt.vector3d(-spatialScene.plotHalf, 0.05, 0)
            p2: Qt.vector3d(spatialScene.plotHalf, 0.05, 0)
            color: spatialScene.axisColor
            lineWidth: spatialScene.lineM * 1.6
            opacityFactor: 0.8
        }

        // Range rings
        Repeater3D {
            model: spatialScene.ringRadii
            Node {
                id: ringNode
                required property var modelData
                readonly property real ringR: modelData
                Repeater3D {
                    model: 72
                    ASTHRASpatialLine3D {
                        readonly property real a0: index / 72 * Math.PI * 2
                        readonly property real a1: (index + 1) / 72 * Math.PI * 2
                        p1: Qt.vector3d(Math.sin(a0) * ringNode.ringR, 0.06, -Math.cos(a0) * ringNode.ringR)
                        p2: Qt.vector3d(Math.sin(a1) * ringNode.ringR, 0.06, -Math.cos(a1) * ringNode.ringR)
                        color: spatialScene.ringColor
                        lineWidth: spatialScene.lineM * 1.4
                    }
                }
            }
        }

        // Plot boundary with amber corner brackets
        Repeater3D {
            model: 4
            ASTHRASpatialLine3D {
                readonly property real h: spatialScene.plotHalf
                readonly property var c: [[-1, -1], [1, -1], [1, 1], [-1, 1]]
                p1: Qt.vector3d(c[index][0] * h, 0.07, c[index][1] * h)
                p2: Qt.vector3d(c[(index + 1) % 4][0] * h, 0.07, c[(index + 1) % 4][1] * h)
                color: spatialScene.frameColor
                lineWidth: spatialScene.lineM * 1.6
            }
        }
        Repeater3D {
            model: 8
            ASTHRASpatialLine3D {
                readonly property real h: spatialScene.plotHalf
                readonly property real len: h * 0.12
                readonly property int corner: Math.floor(index / 2)
                readonly property real sx: (corner === 1 || corner === 2) ? 1 : -1
                readonly property real sz: corner >= 2 ? 1 : -1
                p1: Qt.vector3d(sx * h, 0.09, sz * h)
                p2: index % 2 === 0 ? Qt.vector3d(sx * (h - len), 0.09, sz * h) : Qt.vector3d(sx * h, 0.09, sz * (h - len))
                color: spatialScene.accentColor
                lineWidth: spatialScene.lineM * 3
            }
        }

        ASTHRASpatialLine3D {
            visible: _active && !isNaN(spatialScene.droneEnu.x)
            p1: Qt.vector3d(0, 1.6, 0)
            p2: Qt.vector3d(spatialScene.droneEnu.x, Math.max(0.2, spatialScene.droneEnu.y), spatialScene.droneEnu.z)
            color: spatialScene.stale ? "#3D4247" : "#7A72D8"
            lineWidth: 0.05
            opacityFactor: 0.45
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
                lineWidth: 0.12
                opacityFactor: 0.9
            }
        }

        Repeater3D {
            model: wpSegModel
            delegate: ASTHRASpatialLine3D {
                p1: Qt.vector3d(x1, y1, z1)
                p2: Qt.vector3d(x2, y2, z2)
                color: "#D4A017"
                lineWidth: 0.11
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
                lineWidth: 0.16
            }
        }
    }

    // Screen-space overlay: callouts and labels are projected from the 3D scene every frame
    Item {
        id: overlay
        anchors.fill: parent
        visible: spatialScene.visible

        readonly property real _fontPx: ScreenTools.defaultFontPixelHeight * 0.72
        readonly property real _cellH: Math.round(_fontPx * 1.6)

        // Range ring distances, placed on the south-east diagonal to stay clear of the axes
        Repeater {
            model: spatialScene.ringRadii
            delegate: Rectangle {
                required property var modelData
                readonly property vector3d _s: spatialScene.project(Qt.vector3d(modelData * 0.7071, 0.1, modelData * 0.7071))
                visible: _s.z > 0 && _s.x > 0 && _s.x < spatialScene.width && _s.y > 0 && _s.y < spatialScene.height
                x: _s.x - width / 2
                y: _s.y - height / 2
                width: ringText.implicitWidth + 8
                height: ringText.implicitHeight + 2
                color: "#CC0E1317"
                Text {
                    id: ringText
                    anchors.centerIn: parent
                    text: Math.round(parent.modelData) + " m"
                    color: "#7D93A8"
                    font.family: ScreenTools.fixedFontFamily
                    font.pixelSize: overlay._fontPx * 0.9
                }
            }
        }

        // Cardinal markers just outside the plot boundary
        Repeater {
            model: [["N", 0, -1], ["E", 1, 0], ["S", 0, 1], ["W", -1, 0]]
            delegate: Rectangle {
                required property var modelData
                readonly property real _r: spatialScene.plotHalf * 1.07
                readonly property vector3d _s: spatialScene.project(Qt.vector3d(modelData[1] * _r, 0.1, modelData[2] * _r))
                visible: _s.z > 0 && _s.x > 0 && _s.x < spatialScene.width && _s.y > 0 && _s.y < spatialScene.height
                x: _s.x - width / 2
                y: _s.y - height / 2
                width: overlay._cellH
                height: overlay._cellH
                color: "#E60E1317"
                border.width: 1
                border.color: modelData[0] === "N" ? spatialScene.accentColor : spatialScene.frameColor
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData[0]
                    color: parent.modelData[0] === "N" ? spatialScene.accentColor : "#AEB8C2"
                    font.family: ScreenTools.fixedFontFamily
                    font.pixelSize: overlay._fontPx
                    font.bold: true
                }
            }
        }

        // Drone callouts: ID block, altitude, mode, arm state, with a leader line to the airframe
        Repeater {
            model: _mvm ? _mvm.vehicles : []
            delegate: Item {
                id: tag
                required property var object
                required property int index
                readonly property vector3d _screen: {
                    var e = spatialScene.enuFor(object)
                    return spatialScene.project(e)
                }
                readonly property real _alt: object && object.altitudeRelative ? object.altitudeRelative.value : NaN
                readonly property color _col: spatialScene.fleetColorAt(index)
                readonly property bool _isActive: object === spatialScene._active
                readonly property bool _lost: object && object.vehicleLinkManager && object.vehicleLinkManager.communicationLost
                readonly property bool _armed: object && object.armed
                readonly property real _lead: 34

                visible: _screen.z > 0 && _screen.x > -60 && _screen.x < spatialScene.width + 60
                         && _screen.y > -20 && _screen.y < spatialScene.height + 80
                x: Math.round(_screen.x)
                y: Math.round(_screen.y)
                z: _isActive ? 2 : 1

                Rectangle {
                    x: -7; y: -7
                    width: 14; height: 14
                    rotation: 45
                    color: "transparent"
                    border.width: tag._isActive ? 2 : 1
                    border.color: tag._lost ? "#8B9199" : tag._col
                }

                Rectangle {
                    x: -0.5
                    y: -tag._lead
                    width: 1
                    height: tag._lead - 9
                    color: tag._lost ? "#8B9199" : tag._col
                    opacity: 0.85
                }

                Rectangle {
                    x: Math.max(4 - tag.x, Math.min(spatialScene.width - 4 - tag.x - width, -width / 2))
                    y: -tag._lead - height
                    width: calloutRow.implicitWidth + 2
                    height: overlay._cellH + 2
                    color: "#EB0F1418"
                    border.width: 1
                    border.color: tag._isActive ? tag._col : "#34404B"

                    Row {
                        id: calloutRow
                        x: 1; y: 1
                        height: overlay._cellH

                        Rectangle {
                            width: idText.implicitWidth + 12
                            height: parent.height
                            color: tag._lost ? "#5A6168" : tag._col
                            Text {
                                id: idText
                                anchors.centerIn: parent
                                text: "V" + (tag.object && tag.object.fleetSlot > 0 ? tag.object.fleetSlot : tag.index + 1)
                                color: "#0E1317"
                                font.family: ScreenTools.fixedFontFamily
                                font.pixelSize: overlay._fontPx
                                font.bold: true
                            }
                        }
                        Text {
                            height: parent.height
                            leftPadding: 7; rightPadding: 5
                            verticalAlignment: Text.AlignVCenter
                            text: isNaN(tag._alt) ? "-- m" : tag._alt.toFixed(1) + " m"
                            color: "#E2E7EC"
                            font.family: ScreenTools.fixedFontFamily
                            font.pixelSize: overlay._fontPx
                            font.bold: true
                        }
                        Text {
                            visible: spatialScene.width > 560
                            height: parent.height
                            leftPadding: 2; rightPadding: 7
                            verticalAlignment: Text.AlignVCenter
                            text: tag.object && tag.object.flightMode ? String(tag.object.flightMode).toUpperCase() : "--"
                            color: "#8B9AA8"
                            font.family: ScreenTools.fixedFontFamily
                            font.pixelSize: overlay._fontPx * 0.9
                        }
                        Rectangle {
                            width: stateText.implicitWidth + 12
                            height: parent.height
                            color: tag._lost ? "#7A5A12" : (tag._armed ? "#B03A2E" : "#26323C")
                            Text {
                                id: stateText
                                anchors.centerIn: parent
                                text: tag._lost ? "LOST" : (tag._armed ? "ARMED" : "SAFE")
                                color: tag._lost || tag._armed ? "#F4F6F8" : "#7FA88E"
                                font.family: ScreenTools.fixedFontFamily
                                font.pixelSize: overlay._fontPx * 0.85
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }

        // Compass: needle tracks true north as the camera turns
        Item {
            id: compass
            readonly property real _yaw: { spatialScene.frameTick; return perspCam.eulerRotation.y }
            readonly property int _bearing: Math.round(((-_yaw % 360) + 360) % 360) % 360
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 12
            anchors.topMargin: spatialScene.topInset
            width: ScreenTools.defaultFontPixelHeight * 4.2
            height: width + bearingText.implicitHeight + 4

            Rectangle {
                id: dial
                width: parent.width
                height: width
                radius: width / 2
                color: "#D90E1317"
                border.width: 1
                border.color: spatialScene.frameColor

                Item {
                    anchors.fill: parent
                    rotation: compass._yaw

                    Repeater {
                        model: 12
                        Rectangle {
                            required property int index
                            x: dial.width / 2 - width / 2
                            y: 2
                            width: index % 3 === 0 ? 2 : 1
                            height: index % 3 === 0 ? 7 : 4
                            color: index === 0 ? spatialScene.accentColor : "#5C6E80"
                            transform: Rotation {
                                origin.x: width / 2
                                origin.y: dial.height / 2 - 2
                                angle: index * 30
                            }
                        }
                    }

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            var c = width / 2
                            var r = width / 2 - 10
                            ctx.reset()
                            ctx.fillStyle = spatialScene.accentColor
                            ctx.beginPath()
                            ctx.moveTo(c, c - r)
                            ctx.lineTo(c - 5, c)
                            ctx.lineTo(c + 5, c)
                            ctx.closePath()
                            ctx.fill()
                            ctx.fillStyle = "#4A5A6A"
                            ctx.beginPath()
                            ctx.moveTo(c, c + r)
                            ctx.lineTo(c - 5, c)
                            ctx.lineTo(c + 5, c)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }

                    Text {
                        x: dial.width / 2 - width / 2
                        y: 9
                        text: "N"
                        color: spatialScene.accentColor
                        font.family: ScreenTools.fixedFontFamily
                        font.pixelSize: overlay._fontPx * 0.9
                        font.bold: true
                        rotation: -compass._yaw
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 5; height: 5; radius: 2.5
                    color: "#E2E7EC"
                }
            }

            Text {
                id: bearingText
                anchors.top: dial.bottom
                anchors.topMargin: 4
                anchors.horizontalCenter: dial.horizontalCenter
                text: "BRG " + ("00" + compass._bearing).slice(-3) + "°"
                color: "#AEB8C2"
                font.family: ScreenTools.fixedFontFamily
                font.pixelSize: overlay._fontPx * 0.9
            }
        }

        // Scale bar and camera readout
        Rectangle {
            id: scaleBox
            readonly property real _mpp: spatialScene.metresPerPx
            readonly property real _barM: {
                var raw = _mpp * ScreenTools.defaultFontPixelHeight * 7
                if (!(raw > 0))
                    return 0
                var p = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10))
                var steps = [1, 2, 5, 10]
                var best = p
                for (var i = 0; i < steps.length; i++) {
                    if (steps[i] * p <= raw)
                        best = steps[i] * p
                }
                return best
            }
            readonly property real _barPx: _mpp > 0 ? _barM / _mpp : 0
            readonly property real _elev: { spatialScene.frameTick; return -perspCam.eulerRotation.x }
            readonly property real _range: spatialScene.centreGroundDistance()

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 10
            anchors.bottomMargin: spatialScene.bottomInset
            width: Math.max(readout.implicitWidth, _barPx) + 16
            height: readout.implicitHeight + overlay._cellH + 14
            color: "#D90E1317"
            border.width: 1
            border.color: "#34404B"
            visible: _barM > 0

            Text {
                id: readout
                anchors.top: parent.top
                anchors.topMargin: 5
                anchors.right: parent.right
                anchors.rightMargin: 8
                text: "CAM " + (spatialScene.cameraController ? spatialScene.cameraController.modeTitle : "--")
                      + "  EL " + Math.round(scaleBox._elev) + "°"
                      + "  R " + (scaleBox._range >= 1000 ? (scaleBox._range / 1000).toFixed(2) + " km" : Math.round(scaleBox._range) + " m")
                color: "#AEB8C2"
                font.family: ScreenTools.fixedFontFamily
                font.pixelSize: overlay._fontPx * 0.9
            }

            Item {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                width: scaleBox._barPx
                height: overlay._cellH

                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 2; color: "#E2E7EC" }
                Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 2; height: 8; color: "#E2E7EC" }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; width: 1; height: 5; color: "#E2E7EC" }
                Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 2; height: 8; color: "#E2E7EC" }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    text: scaleBox._barM >= 1000 ? (scaleBox._barM / 1000) + " km" : scaleBox._barM + " m"
                    color: "#E2E7EC"
                    font.family: ScreenTools.fixedFontFamily
                    font.pixelSize: overlay._fontPx * 0.9
                    font.bold: true
                }
            }
        }
    }

    onCameraControllerChanged: {
        if (cameraController)
            cameraController.camera = perspCam
    }
}
