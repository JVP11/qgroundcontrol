/****************************************************************************
 *
 * ASTHRA - OFFBOARD Exit Point Marker
 * Visual marker for OFFBOARD exit events on the map
 *
 ****************************************************************************/

import QtQuick
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

/// Map marker for a single OFFBOARD exit event
MapQuickItem {
    id: marker
    
    property var eventData: null  // Event data with coordinates, reason, distance, direction
    
    anchorPoint.x: markerItem.width / 2
    anchorPoint.y: markerItem.height / 2
    z: QGroundControl.zOrderWaypointLines + 10  // Above waypoints
    
    sourceItem: Rectangle {
        id: markerItem
        width: ScreenTools.defaultFontPixelHeight * 2.5
        height: width
        radius: width / 2
        color: getMarkerColor()
        border.width: 2
        border.color: qgcPal.text
        
        QGCPalette { id: qgcPal }
        
        function getMarkerColor() {
            if (!eventData) return qgcPal.colorRed
            
            var reason = eventData.reason || "UNKNOWN"
            if (reason === "LINK_LOSS" || reason === "FAILSAFE") {
                return qgcPal.colorRed  // Critical - Alert Red
            } else if (reason === "MODE_CHANGE") {
                return qgcPal.colorYellow  // Warning - Caution Amber
            } else {
                return qgcPal.colorOrange  // Unknown - Caution
            }
        }
        
        // Inner circle for emphasis
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.6
            height: width
            radius: width / 2
            color: Qt.lighter(parent.color, 1.3)
            opacity: 0.7
        }
        
        // Crosshair for precision
        Item {
            anchors.fill: parent
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: parent.height * 0.2
                width: 2
                height: parent.height * 0.3
                color: qgcPal.text
            }
            Rectangle {
                anchors.horizontalCenter: parent.left
                anchors.horizontalCenterOffset: parent.width * 0.2
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.3
                height: 2
                color: qgcPal.text
            }
        }
        
        // Tooltip on hover
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            
            ToolTip.visible: containsMouse && eventData
            ToolTip.text: getTooltipText()
            
            function getTooltipText() {
                if (!eventData) return "OFFBOARD EXIT"
                
                var text = "OFFBOARD EXIT\n"
                text += "Reason: " + (eventData.reason || "UNKNOWN") + "\n"
                if (eventData.distanceText) {
                    text += "Distance: " + eventData.distanceText + "\n"
                }
                if (eventData.directionText) {
                    text += "Direction: " + eventData.directionText + "\n"
                }
                if (eventData.altitude) {
                    text += "Altitude: " + eventData.altitude.toFixed(1) + " m"
                }
                return text
            }
        }
    }
}

