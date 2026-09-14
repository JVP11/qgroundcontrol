/****************************************************************************
 *
 * ASTHRA - OFFBOARD Event Map Markers
 * Displays OFFBOARD exit points on the tactical map
 *
 ****************************************************************************/

import QtQuick
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

/// Map markers for OFFBOARD exit events
Item {
    id: offboardMarkers
    
    property var map: null
    property var offboardEvents: []  // Array of OFFBOARD exit events
    
    property var _markers: []  // Array of MapQuickItem objects
    
    function addMarker(event) {
        if (!map || !event) return
        
        var component = Qt.createComponent("ASTHRAOffboardMarker.qml")
        if (component.status === Component.Ready) {
            var marker = component.createObject(map, {
                coordinate: QtPositioning.coordinate(event.latitude, event.longitude, event.altitude),
                eventData: event
            })
            
            if (marker) {
                map.addMapItem(marker)
                _markers.push(marker)
            }
        } else {
            console.error("Failed to create OFFBOARD marker:", component.errorString())
        }
    }
    
    function clearMarkers() {
        for (var i = 0; i < _markers.length; i++) {
            if (_markers[i]) {
                map.removeMapItem(_markers[i])
                _markers[i].destroy()
            }
        }
        _markers = []
    }
    
    function updateMarkers(events) {
        clearMarkers()
        offboardEvents = events || []
        
        for (var i = 0; i < offboardEvents.length; i++) {
            var event = offboardEvents[i]
            if (event.eventType === "OFFBOARD_EXIT" || (event.data && event.data.reason)) {
                addMarker(event.data || event)
            }
        }
    }
    
    onOffboardEventsChanged: {
        updateMarkers(offboardEvents)
    }
    
    Component.onDestruction: {
        clearMarkers()
    }
}

