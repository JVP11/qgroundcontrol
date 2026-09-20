/****************************************************************************
 *
 * ASTHRA Swarm — draw KML land and per-drone coverage on the FLY map.
 *
 ****************************************************************************/

import QtQuick
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property var map: null
    property var coverage: null

    property var _items: []

    function _coordLat(c) { return (c.latitude !== undefined) ? c.latitude : c.lat }
    function _coordLon(c) { return (c.longitude !== undefined) ? c.longitude : c.lng }

    function _centroid(path) {
        if (!path || path.length === 0)
            return null
        var lat = 0
        var lon = 0
        var n = path.length
        for (var i = 0; i < n; i++) {
            lat += _coordLat(path[i])
            lon += _coordLon(path[i])
        }
        return QtPositioning.coordinate(lat / n, lon / n)
    }

    function _clear() {
        if (!map)
            return
        for (var i = 0; i < _items.length; i++) {
            if (_items[i]) {
                map.removeMapItem(_items[i])
                _items[i].destroy()
            }
        }
        _items = []
    }

    function _addPolygon(path, fill, border, z) {
        if (!map || !path || path.length < 3)
            return
        var coords = []
        for (var i = 0; i < path.length; i++) {
            coords.push(QtPositioning.coordinate(_coordLat(path[i]), _coordLon(path[i])))
        }
        var poly = Qt.createQmlObject(
                    'import QtLocation; import QtPositioning; MapPolygon { border.width: 3 }',
                    map)
        if (!poly)
            return
        poly.path = coords
        poly.color = fill
        poly.border.color = border
        poly.z = z
        map.addMapItem(poly)
        _items.push(poly)
    }

    function _addPolyline(coords, color) {
        if (!map || !coords || coords.length < 2)
            return
        var line = Qt.createQmlObject(
                    'import QtLocation; import QtPositioning; MapPolyline { line.width: 3 }',
                    map)
        if (!line)
            return
        line.path = coords
        line.line.color = color
        line.z = QGroundControl.zOrderMapItems + 3
        map.addMapItem(line)
        _items.push(line)
    }

    function _addLabel(coord, text, color) {
        if (!map || !coord)
            return
        var item = labelComp.createObject(map, { coordinate: coord, labelText: text, accent: color })
        if (!item)
            return
        map.addMapItem(item)
        _items.push(item)
    }

    function _fillFromHex(c, alpha) {
        if (!c || c.length < 7)
            return Qt.rgba(0.83, 0.63, 0.09, alpha)
        return Qt.rgba(parseInt(c.substr(1, 2), 16) / 255,
                       parseInt(c.substr(3, 2), 16) / 255,
                       parseInt(c.substr(5, 2), 16) / 255, alpha)
    }

    function rebuild() {
        _clear()
        if (!map || !coverage)
            return
        if (coverage.landPath && coverage.landPath.length >= 3) {
            _addPolygon(coverage.landPath, Qt.rgba(0.16, 0.18, 0.21, 0.18), "#2A3036", QGroundControl.zOrderMapItems)
        }
        var list = coverage.assignments || []
        for (var i = 0; i < list.length; i++) {
            var a = list[i]
            var c = a.color ? a.color : "#D4A017"
            _addPolygon(a.path, _fillFromHex(c, 0.45), c, QGroundControl.zOrderMapItems + 1)
            var label = (a.name ? a.name : ("DRONE " + (i + 1))) + "  " + Number(a.percent).toFixed(0) + "%"
            if (a.wpCount)
                label += "  " + a.wpCount + " wp"
            _addLabel(_centroid(a.path), label, c)
            if (a.waypoints && a.waypoints.length > 1) {
                var line = []
                for (var w = 0; w < a.waypoints.length; w++) {
                    var wp = a.waypoints[w]
                    var lat = wp.lat !== undefined ? wp.lat : wp.latitude
                    var lon = wp.lon !== undefined ? wp.lon : wp.longitude
                    line.push(QtPositioning.coordinate(lat, lon))
                }
                _addPolyline(line, c)
            }
        }
    }

    Component {
        id: labelComp
        MapQuickItem {
            property string labelText: ""
            property color accent: "#D4A017"
            anchorPoint.x: sourceItem.width / 2
            anchorPoint.y: sourceItem.height / 2
            z: QGroundControl.zOrderMapItems + 2
            sourceItem: Rectangle {
                color: Qt.rgba(0.08, 0.09, 0.10, 0.88)
                border.width: 1
                border.color: accent
                radius: 2
                implicitWidth: labelTxt.implicitWidth + 10
                implicitHeight: labelTxt.implicitHeight + 6
                Text {
                    id: labelTxt
                    anchors.centerIn: parent
                    text: labelText
                    color: "#E6E8EA"
                    font.family: ScreenTools.fixedFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                    font.bold: true
                }
            }
        }
    }

    Connections {
        target: coverage
        ignoreUnknownSignals: true
        function onAssignmentsChanged() { rebuild() }
        function onLandPathChanged() { rebuild() }
        function onRevisionChanged() { rebuild() }
    }

    Connections {
        target: map
        ignoreUnknownSignals: true
        function onMapReadyChanged() {
            if (map && map.mapReady)
                rebuild()
        }
    }

    onMapChanged: rebuild()
    onCoverageChanged: rebuild()
    Component.onCompleted: rebuild()
    Component.onDestruction: _clear()
}
