// WebEngine-backed 3D view (only built when Qt WebEngine is available)

import QtQuick
import QtWebEngine

Item {
    id: root

    function pushDroneJson(json) {
        webView.runJavaScript("typeof updateDrones === 'function' && updateDrones(" + json + ")")
    }

    WebEngineView {
        id: webView
        anchors.fill: parent
        url: "qrc:/qml/QGroundControl/SwarmPlugin/resources/3d-view-index.html"
    }
}
