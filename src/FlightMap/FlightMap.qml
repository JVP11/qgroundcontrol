/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
import QtQuick.Dialogs
import Qt.labs.animation

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
    property bool   allowGCSLocationCenter:         false   ///< true: map will center/zoom to gcs location one time
    property bool   allowVehicleLocationCenter:     false   ///< true: map will center/zoom to vehicle location one time
    property bool   firstGCSPositionReceived:       false   ///< true: first gcs position update was responded to
    property bool   firstVehiclePositionReceived:   false   ///< true: first vehicle position update was responded to
    property bool   planView:                       false   ///< true: map being using for Plan view, items should be draggable

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property var    _activeVehicleCoordinate:   _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()

    function setVisibleRegion(region) {
        // TODO: Is this still necessary with Qt 5.11?
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

    function _possiblyCenterToVehiclePosition() {
        if (!firstVehiclePositionReceived && allowVehicleLocationCenter && _activeVehicleCoordinate.isValid) {
            firstVehiclePositionReceived = true
            center = _activeVehicleCoordinate
            zoomLevel = QGroundControl.flightMapInitialZoom
        }
    }

    function centerToSpecifiedLocation() {
        specifyMapPositionDialog.createObject(mainWindow).open()
    }

    Component {
        id: specifyMapPositionDialog
        EditPositionDialog {
            title:                  qsTr("Specify Position")
            coordinate:             center
            onCoordinateChanged:    center = coordinate
        }
    }

    // Center map to gcs location
    onGcsPositionChanged: {
        if (gcsPosition.isValid && allowGCSLocationCenter && !firstGCSPositionReceived && !firstVehiclePositionReceived) {
            firstGCSPositionReceived = true
            //-- Only center on gsc if we have no vehicle (and we are supposed to do so)
            var _activeVehicleCoordinate = _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()
            if(QGroundControl.settingsManager.flyViewSettings.keepMapCenteredOnVehicle.rawValue || !_activeVehicleCoordinate.isValid)
                center = gcsPosition
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

    on_ActiveVehicleCoordinateChanged: _possiblyCenterToVehiclePosition()

    onMapReadyChanged: {
        if (_map.mapReady) {
            updateActiveMapType()
            ensureMapHasCenter()
            _possiblyCenterToVehiclePosition()
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
        id:     pinchHandler
        target: null

        property var pinchStartCentroid

        onActiveChanged: {
            if (active) {
                pinchStartCentroid = _map.toCoordinate(pinchHandler.centroid.position, false)
            } else {
                clampZoomLevel()
            }
        }
        onScaleChanged: (delta) => {
            let newZoomLevel = Math.max(_map.zoomLevel + Math.log2(delta), 0)
            _map.zoomLevel = newZoomLevel
            _map.alignCoordinateToPoint(pinchStartCentroid, pinchHandler.centroid.position)
        }
    }

    WheelHandler {
        // workaround for QTBUG-87646 / QTBUG-112394 / QTBUG-112432:
        // Magic Mouse pretends to be a trackpad but doesn't work with PinchHandler
        // and we don't yet distinguish mice and trackpads on Wayland either
        acceptedDevices:    Qt.platform.pluginName === "cocoa" || Qt.platform.pluginName === "wayland" ?
                                PointerDevice.Mouse | PointerDevice.TouchPad : PointerDevice.Mouse
        rotationScale:      1 / 120
        property:           "zoomLevel"

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
        visible:        gcsPosition.isValid
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
