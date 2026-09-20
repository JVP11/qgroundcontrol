/****************************************************************************
 *
 * ASTHRA Spatial 3D — Qt Quick 3D scene. Telemetry-driven, read-only.
 *
 ****************************************************************************/

import QtQuick
import QtQuick3D
import QtPositioning

import QGroundControl

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
        r = Math.max(r, Math.abs(droneEnu.x), Math.abs(droneEnu.z), Math.abs(droneEnu.y))
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
            _updateVehicleDerived()
            if (cameraController) {
                cameraController.targetPos = _active ? droneEnu : Qt.vector3d(0, 0, 0)
                cameraController.targetHeading = _active && _active.heading ? _active.heading.value : 0
                cameraController.operatorPos = Qt.vector3d(operatorEnu.x, 1.7, operatorEnu.z)
                cameraController.operatorValid = operatorValid
                if (cameraController.mode !== "free")
                    cameraController.apply()
            }
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
            clearColor: "#050708"
            backgroundMode: SceneEnvironment.Color
        }

        PerspectiveCamera {
            id: perspCam
            position: Qt.vector3d(18, 16, 28)
            eulerRotation: Qt.vector3d(-28, 35, 0)
            clipNear: 0.4
            clipFar: 80000
            fieldOfView: 50
            property bool smooth: cameraController && cameraController.mode !== "free"
            Behavior on position {
                enabled: perspCam.smooth
                Vector3dAnimation { duration: 160; easing.type: Easing.Linear }
            }
        }

        DirectionalLight {
            eulerRotation.x: -62
            eulerRotation.y: 18
            brightness: 0.72
        }

        DirectionalLight {
            eulerRotation.x: 15
            eulerRotation.y: -140
            brightness: 0.18
        }

        // Plot table
        Model {
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(Math.max(4, spatialScene.plotHalf / 50), Math.max(4, spatialScene.plotHalf / 50), 1)
            position: Qt.vector3d(0, 0, 0)
            pickable: false
            materials: PrincipledMaterial {
                baseColor: "#0F1215"
                roughness: 1
                metalness: 0
            }
        }

        Repeater3D {
            model: 9
            ASTHRASpatialLine3D {
                property real g: (index - 4) * spatialScene.gridStep
                p1: Qt.vector3d(-spatialScene.plotHalf, 0.02, g)
                p2: Qt.vector3d(spatialScene.plotHalf, 0.02, g)
                color: "#1F2327"
                lineWidth: 0.07
                opacityFactor: 0.95
            }
        }
        Repeater3D {
            model: 9
            ASTHRASpatialLine3D {
                property real g: (index - 4) * spatialScene.gridStep
                p1: Qt.vector3d(g, 0.02, -spatialScene.plotHalf)
                p2: Qt.vector3d(g, 0.02, spatialScene.plotHalf)
                color: "#1F2327"
                lineWidth: 0.07
                opacityFactor: 0.95
            }
        }

        Repeater3D {
            model: 3
            Model {
                property real ringR: index === 0 ? spatialScene.gridStep : (index === 1 ? spatialScene.gridStep * 2 : spatialScene.plotHalf)
                source: "#Cylinder"
                position: Qt.vector3d(0, 0.04, 0)
                scale: Qt.vector3d(Math.max(0.2, ringR / 50.0), 0.00035, Math.max(0.2, ringR / 50.0))
                materials: PrincipledMaterial {
                    baseColor: "#2A3036"
                    opacity: 0.28
                    alphaMode: PrincipledMaterial.Blend
                    roughness: 1
                }
            }
        }

        ASTHRASpatialLine3D { p1: Qt.vector3d(0, 0.06, 0); p2: Qt.vector3d(0, 0.06, -Math.max(14, spatialScene.gridStep * 0.6)); color: "#2D4A5F"; lineWidth: 0.14 }
        ASTHRASpatialLine3D { p1: Qt.vector3d(0, 0.06, 0); p2: Qt.vector3d(Math.max(14, spatialScene.gridStep * 0.6), 0.06, 0); color: "#D4A017"; lineWidth: 0.14 }

        ASTHRASpatialLine3D {
            visible: _active && !isNaN(spatialScene.droneEnu.x)
            p1: Qt.vector3d(0, 1.6, 0)
            p2: Qt.vector3d(spatialScene.droneEnu.x, Math.max(0.2, spatialScene.droneEnu.y), spatialScene.droneEnu.z)
            color: spatialScene.stale ? "#3D4247" : "#534AB7"
            lineWidth: 0.10
            opacityFactor: 0.7
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
                enuPos: {
                    if (isActive)
                        return spatialScene.droneEnu
                    if (!object || !object.coordinate || !object.coordinate.isValid)
                        return Qt.vector3d(0, 0, 0)
                    var alt = object.altitudeRelative ? object.altitudeRelative.value : 0
                    return spatialScene.toEnu(object.coordinate, alt)
                }
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

    onCameraControllerChanged: {
        if (cameraController)
            cameraController.camera = perspCam
    }
}
