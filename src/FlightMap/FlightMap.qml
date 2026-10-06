import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

Map {
    id: _map

    plugin:     Plugin { name: "QGroundControl" }
    opacity:    0.99 // https://bugreports.qt.io/browse/QTBUG-82185

    property string mapName:                        'defaultMap'
    property bool   isSatelliteMap:                 activeMapType.name.indexOf("Satellite") > -1 || activeMapType.name.indexOf("Hybrid") > -1
    property var    gcsPosition:                    QGroundControl.qgcPositionManger.gcsPosition
    property real   gcsHeading:                     QGroundControl.qgcPositionManger.gcsHeading
    property alias  allowGCSLocationCenter:         _positionTracker.allowGCSLocationCenter     ///< true: map will center to gcs location one time
    property alias  allowVehicleLocationCenter:     _positionTracker.allowVehicleLocationCenter ///< true: map will center/zoom to vehicle location one time
    property alias  firstVehiclePositionReceived:   _positionTracker.firstVehiclePositionReceived ///< true: first vehicle position update was responded to
    property alias  positionTracker:                _positionTracker                            ///< Auto-centering policy, for derived maps to layer follow behavior on
    property bool   planView:                       false   ///< true: map being using for Plan view, items should be draggable
    property bool   pinchZoomDisabledByVirtualJoysticks: false ///< true: disable pinch-to-zoom while virtual joystick thumbs are down

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property var    _activeVehicleCoordinate:   _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()

    function setVisibleRegion(region) {
        // This works around a bug on Qt where if you set a visibleRegion and then the user moves or zooms the map
        // and then you set the same visibleRegion the map will not move/scale appropriately since it thinks there
        // is nothing to do.
        let maxZoomLevel = 20
        _map.visibleRegion = QtPositioning.rectangle(QtPositioning.coordinate(0, 0), QtPositioning.coordinate(0, 0))
        _map.visibleRegion = region
        if (_map.zoomLevel > maxZoomLevel) {
            _map.zoomLevel = maxZoomLevel
        }
    }

    function centerToSpecifiedLocation() {
        specifyMapPositionDialogFactory.open()
    }

    MapPositionTracker {
        id: _positionTracker

        active: _map.mapReady
        gcsPosition: _map.gcsPosition
        vehicleCoordinate: _map._activeVehicleCoordinate
        centerGCSWhenVehicleValid: QGroundControl.settingsManager.flyViewSettings.keepMapCenteredOnVehicle.rawValue

        onCenterMap: (coordinate, firstPosition) => {
            _map.center = coordinate
            if (firstPosition) {
                _map.zoomLevel = QGroundControl.flightMapInitialZoom
            }
        }
    }

    QGCPopupDialogFactory {
        id: specifyMapPositionDialogFactory

        dialogComponent: specifyMapPositionDialog
    }

    Component {
        id: specifyMapPositionDialog
        EditPositionDialog {
            title:                  qsTr("Specify Position")
            coordinate:             center
            onCoordinateChanged:    center = coordinate
        }
    }

    function updateActiveMapType() {
        var settings =  QGroundControl.settingsManager.flightMapSettings
        var fullMapName = settings.mapProvider.value + " " + settings.mapType.value

        for (var i = 0; i < _map.supportedMapTypes.length; i++) {
            if (fullMapName === _map.supportedMapTypes[i].name) {
                _map.activeMapType = _map.supportedMapTypes[i]
                return
            }
        }

        // Saved provider/type missing — prefer Bing Road (Hybrid fails at high zoom)
        for (var j = 0; j < _map.supportedMapTypes.length; j++) {
            if (_map.supportedMapTypes[j].name === "Bing Road") {
                _map.activeMapType = _map.supportedMapTypes[j]
                return
            }
        }
        var fallbacks = ["Esri World Street", "Bing Satellite", "Street Map"]
        for (var k = 0; k < fallbacks.length; k++) {
            for (var n = 0; n < _map.supportedMapTypes.length; n++) {
                if (fallbacks[k] === _map.supportedMapTypes[n].name) {
                    _map.activeMapType = _map.supportedMapTypes[n]
                    return
                }
            }
        }
        if (_map.supportedMapTypes.length > 0) {
            _map.activeMapType = _map.supportedMapTypes[0]
        }
    }

    function clampZoomLevel() {
        var isBing = _map.activeMapType && _map.activeMapType.name.indexOf("Bing") >= 0
        var maxZoom = isBing ? 15 : 19
        var minZoom = 3
        var z = Math.round(_map.zoomLevel)
        if (z > maxZoom) {
            z = maxZoom
        } else if (z < minZoom) {
            z = minZoom
        }
        if (Math.abs(_map.zoomLevel - z) > 0.01) {
            _map.zoomLevel = z
            QGroundControl.flightMapZoom = z
        }
    }

    function ensureMapHasCenter() {
        clampZoomLevel()
        if (!_map.center || !_map.center.isValid) {
            var vehicle = _activeVehicle
            if (vehicle && vehicle.coordinate && vehicle.coordinate.isValid) {
                _map.center = vehicle.coordinate
            } else {
                _map.center = QtPositioning.coordinate(37.7749, -122.4194)
            }
            if (_map.zoomLevel < 12) {
                _map.zoomLevel = 12
                QGroundControl.flightMapZoom = 12
            }
        }
    }

    onMapReadyChanged: {
        if (_map.mapReady) {
            updateActiveMapType()
            ensureMapHasCenter()
        }
    }

    Connections {
        target: QGroundControl.settingsManager.flightMapSettings.mapType
        function onRawValueChanged() { updateActiveMapType() }
    }

    Connections {
        target: QGroundControl.settingsManager.flightMapSettings.mapProvider
        function onRawValueChanged() { updateActiveMapType() }
    }

    signal mapPanStart
    signal mapPanStop
    signal mapClicked(var position)
    signal mapRightClicked(var position)
    signal mapPressAndHold(var position)

    PinchHandler {
        id:      pinchHandler
        target:  null
        // Disabled while virtual joystick thumbs are down. The default grabPermissions include
        // CanTakeOverFromItems, which lets this handler steal touch grabs from the joystick pads'
        // MultiPointTouchAreas and zoom the map instead. The permission can't be removed since
        // pinch on the map itself must take over from the panning MultiPointTouchArea below.
        // See GitHub issue #13450.
        enabled: !_map.pinchZoomDisabledByVirtualJoysticks

        property var pinchStartGeoCoord     // geo coordinate under centroid at pinch start
        property var pinchStartScreenPoint  // screen point of centroid at pinch start

        onActiveChanged: {
            if (active) {
                // Capture both the screen point and its geo coordinate once at pinch start.
                // alignCoordinateToPoint requires a fixed screen anchor; using the live
                // centroid.position causes the map to pan as fingers drift.
                pinchStartScreenPoint = pinchHandler.centroid.position
                pinchStartGeoCoord    = _map.toCoordinate(pinchStartScreenPoint, false)
            } else {
                clampZoomLevel()
            }
        }
        onScaleChanged: (delta) => {
            _map.zoomLevel = Math.max(_map.zoomLevel + Math.log2(delta), 0)
            _map.alignCoordinateToPoint(pinchStartGeoCoord, pinchStartScreenPoint)
        }
    }

    WheelHandler {
        // WheelHandler's default acceptedDevices=Mouse silently drops trackpad scroll events on
        // multiple platforms:
        //   - Linux/Wayland (QTBUG-112394 / QTBUG-112432): the Wayland
        //     protocol exposes no way to distinguish a mouse from a trackpad, so Qt registers all
        //     pointer devices as TouchPad.
        //   - xcb / XWayland: Wayland pointer events are translated back to X11 and device-type
        //     metadata is lost — physical mouse scroll events arrive as PointerDevice.TouchPad.
        //   - macOS (cocoa): trackpad scroll events are correctly reported as PointerDevice.TouchPad
        //     but are excluded by the Mouse-only default.
        // Accepting both Mouse and TouchPad on all platforms is harmless and covers every case.
        acceptedDevices:    PointerDevice.Mouse | PointerDevice.TouchPad
        rotationScale:      1 / 120

        onWheel: (event) => {
            const zoomDelta = event.angleDelta.y * rotationScale
            const mouseGeoPos = _map.toCoordinate(Qt.point(event.x, event.y), false)
            _map.zoomLevel = Math.max(_map.zoomLevel + zoomDelta, 0)
            _map.alignCoordinateToPoint(mouseGeoPos, Qt.point(event.x, event.y))
        }
    }

    // We specifically do not use a DragHandler for panning. It just causes too many problems if you overlay anything else like a Flickable above it.
    // Causes all sorts of crazy problems where dragging/scrolling  no longerr works on items above in the hierarchy.
    // Since we are using a MouseArea we also can't use TapHandler for clicks. So we handle that here as well.
    MultiPointTouchArea {
        id: multiTouchArea
        anchors.fill: parent
        maximumTouchPoints: 1
        mouseEnabled: true

        property bool dragActive: false
        property real lastMouseX
        property real lastMouseY
        property bool isPressed: false
        property bool pressAndHold: false

        onPressed: (touchPoints) => {
            lastMouseX = touchPoints[0].x
            lastMouseY = touchPoints[0].y
            isPressed = true
            pressAndHold = false
            pressAndHoldTimer.start()
        }

        onGestureStarted: (gesture) => {
            dragActive = true
            gesture.grab()
            mapPanStart()
        }

        onUpdated: (touchPoints) => {
            if (dragActive) {
                let deltaX = touchPoints[0].x - lastMouseX
                let deltaY = touchPoints[0].y - lastMouseY
                if (Math.abs(deltaX) >= 1.0 || Math.abs(deltaY) >= 1.0) {
                    _map.pan(lastMouseX - touchPoints[0].x, lastMouseY - touchPoints[0].y)
                    lastMouseX = touchPoints[0].x
                    lastMouseY = touchPoints[0].y
                }
            }
        }

        onReleased: (touchPoints) => {
            isPressed = false
            pressAndHoldTimer.stop()
            if (dragActive) {
                _map.pan(lastMouseX - touchPoints[0].x, lastMouseY - touchPoints[0].y)
                dragActive = false
                mapPanStop()
            } else if (!pressAndHold) {
                mapClicked(Qt.point(touchPoints[0].x, touchPoints[0].y))
            }
            pressAndHold = false
        }

        Timer {
            id: pressAndHoldTimer
            interval: 600        // hold duration in ms
            repeat: false

            onTriggered: {
                if (multiTouchArea.isPressed && !multiTouchArea.dragActive) {
                    multiTouchArea.pressAndHold = true
                    mapPressAndHold(Qt.point(multiTouchArea.lastMouseX, multiTouchArea.lastMouseY))
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true

        onPressed: (mouseEvent) => {
            if (mouseEvent.button === Qt.RightButton) {
                mapRightClicked(Qt.point(mouseEvent.x, mouseEvent.y))
            }
        }
    }

    /// Ground Station location
    MapQuickItem {
        anchorPoint.x:  sourceItem.width / 2
        anchorPoint.y:  sourceItem.height / 2
        visible:        gcsPosition.isValid && !planView
        coordinate:     gcsPosition

        sourceItem: Rectangle {
            // QGC Logo removed for ASTHRA - Simple marker instead
            id:             mapMarker
            width:          ScreenTools.defaultFontPixelHeight * 1.5
            height:         width
            radius:         width / 2
            color:          qgcPal.colorBlue  // Steel Blue for GCS marker
            border.width:   2
            border.color:   qgcPal.text
            visible:        true

            QGCPalette { id: qgcPal }

            // Optional: Add direction indicator if heading is available
            Rectangle {
                anchors.centerIn: parent
                width:  parent.width * 0.3
                height: parent.height * 0.6
                color:  qgcPal.text
                visible: !isNaN(gcsHeading)
            transform: Rotation {
                    origin.x:       parent.width / 2
                    origin.y:       parent.height / 2
                angle:          isNaN(gcsHeading) ? 0 : gcsHeading
                }
            }
        }
    }

    // ASTHRA Swarm Backend Integration - load on demand
    property var _swarmMapItems: null
    
    function enableSwarmMapOverlay(swarmClient) {
        if (!_swarmMapItems && swarmClient) {
            var component = Qt.createComponent("qrc:/ASTHRA/Swarm/SwarmMapItems.qml")
            if (component.status === Component.Ready) {
                _swarmMapItems = component.createObject(_map, {
                    "map": _map,
                    "swarmClient": swarmClient
                })
            } else {
                console.error("Failed to load SwarmMapItems:", component.errorString())
            }
        }
    }
    
    function disableSwarmMapOverlay() {
        if (_swarmMapItems) {
            _swarmMapItems.destroy()
            _swarmMapItems = null
        }
    }
} // Map
