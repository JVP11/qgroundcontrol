/****************************************************************************
 *
 * ASTHRA Swarm Backend Integration
 * WebSocket client implementation
 *
 ****************************************************************************/

#include "SwarmWebSocketClient.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSet>
#include <QDebug>

SwarmWebSocketClient::SwarmWebSocketClient(QObject* parent)
    : QObject(parent)
    , _connected(false)
    , _serverUrl("ws://localhost:8765")
{
    connect(&_webSocket, &QWebSocket::connected, this, &SwarmWebSocketClient::onConnected);
    connect(&_webSocket, &QWebSocket::disconnected, this, &SwarmWebSocketClient::onDisconnected);
    connect(&_webSocket, &QWebSocket::textMessageReceived, this, &SwarmWebSocketClient::onTextMessageReceived);
    connect(&_webSocket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::errorOccurred),
            this, &SwarmWebSocketClient::onError);

    _reconnectTimer.setInterval(5000);
    _reconnectTimer.setSingleShot(true);
    connect(&_reconnectTimer, &QTimer::timeout, this, &SwarmWebSocketClient::attemptReconnect);
}

SwarmWebSocketClient::~SwarmWebSocketClient()
{
    _webSocket.close();
    qDeleteAll(_droneMap);
}

void SwarmWebSocketClient::setServerUrl(const QString& url)
{
    if (_serverUrl != url) {
        _serverUrl = url;
        emit serverUrlChanged();
        if (_connected) {
            disconnectFromBackend();
            connectToBackend();
        }
    }
}

QVariantList SwarmWebSocketClient::drones() const
{
    QVariantList list;
    for (SwarmDrone* drone : _droneMap.values()) {
        list.append(QVariant::fromValue(drone));
    }
    return list;
}

void SwarmWebSocketClient::connectToBackend()
{
    if (_connected) {
        qWarning() << "Already connected to swarm backend";
        return;
    }
    qDebug() << "Connecting to swarm backend:" << _serverUrl;
    _webSocket.open(QUrl(_serverUrl));
}

void SwarmWebSocketClient::disconnectFromBackend()
{
    _reconnectTimer.stop();
    _webSocket.close();
}

void SwarmWebSocketClient::onConnected()
{
    qDebug() << "✓ Connected to swarm backend";
    _connected = true;
    _reconnectTimer.stop();
    emit connectedChanged();
}

void SwarmWebSocketClient::onDisconnected()
{
    qDebug() << "✗ Disconnected from swarm backend";
    _connected = false;
    emit connectedChanged();
    _reconnectTimer.start();
}

void SwarmWebSocketClient::onError(QAbstractSocket::SocketError error)
{
    QString errorMsg = QString("WebSocket error: %1").arg(_webSocket.errorString());
    qWarning() << errorMsg;
    emit errorOccurred(errorMsg);
    if (!_connected) {
        _reconnectTimer.start();
    }
}

void SwarmWebSocketClient::attemptReconnect()
{
    if (!_connected) {
        qDebug() << "Attempting to reconnect to swarm backend...";
        connectToBackend();
    }
}

void SwarmWebSocketClient::onTextMessageReceived(const QString& message)
{
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    if (!doc.isObject()) {
        qWarning() << "Invalid JSON received from swarm backend";
        return;
    }

    QJsonObject obj = doc.object();
    const QString msgType = obj["type"].toString();

    if (msgType == "telemetry") {
        handleTelemetryMessage(obj);
    } else if (msgType == "error") {
        emit errorOccurred(obj.value("message").toString(obj.value("error").toString()));
    } else if (msgType == "response" || msgType == "ack") {
        qDebug() << "Backend response:" << obj;
    }
}

void SwarmWebSocketClient::handleTelemetryMessage(const QJsonObject& data)
{
    QSet<int> currentDroneIds;
    const QJsonValue dronesVal = data.value(QStringLiteral("drones"));

    auto ingest = [&](int droneId, const QJsonObject& raw) {
        if (droneId <= 0)
            return;
        currentDroneIds.insert(droneId);
        if (!_droneMap.contains(droneId)) {
            _droneMap.insert(droneId, new SwarmDrone(droneId, this));
            qDebug() << "New swarm drone detected:" << droneId;
        }
        _droneMap[droneId]->updateFromJson(raw);
    };

    if (dronesVal.isArray()) {
        const QJsonArray arr = dronesVal.toArray();
        for (const QJsonValue& v : arr) {
            const QJsonObject d = v.toObject();
            int droneId = d.value(QStringLiteral("local_id")).toInt(d.value(QStringLiteral("id")).toInt());
            ingest(droneId, d);
        }
    } else if (dronesVal.isObject()) {
        const QJsonObject dronesObj = dronesVal.toObject();
        for (auto it = dronesObj.begin(); it != dronesObj.end(); ++it) {
            bool ok = false;
            int droneId = it.key().toInt(&ok);
            const QJsonObject d = it.value().toObject();
            if (!ok)
                droneId = d.value(QStringLiteral("local_id")).toInt(d.value(QStringLiteral("id")).toInt());
            ingest(droneId, d);
        }
    }

    QList<int> toRemove;
    for (int id : _droneMap.keys()) {
        if (!currentDroneIds.contains(id))
            toRemove.append(id);
    }
    for (int id : toRemove) {
        delete _droneMap.take(id);
        qDebug() << "Swarm drone removed:" << id;
    }

    emit dronesChanged();
}

void SwarmWebSocketClient::sendCommand(const QJsonObject& command)
{
    if (!_connected) {
        emit errorOccurred("Not connected to swarm backend");
        return;
    }
    
    QJsonDocument doc(command);
    QString json = doc.toJson(QJsonDocument::Compact);
    _webSocket.sendTextMessage(json);
}

void SwarmWebSocketClient::sendArm(int droneId)
{
    QJsonObject cmd;
    cmd["type"] = QStringLiteral("arm");
    cmd["command"] = QStringLiteral("arm");
    cmd["drone_id"] = droneId;
    sendCommand(cmd);
    qDebug() << "Sent ARM command for drone" << droneId;
}

void SwarmWebSocketClient::sendDisarm(int droneId)
{
    QJsonObject cmd;
    cmd["type"] = QStringLiteral("disarm");
    cmd["command"] = QStringLiteral("disarm");
    cmd["drone_id"] = droneId;
    sendCommand(cmd);
    qDebug() << "Sent DISARM command for drone" << droneId;
}

void SwarmWebSocketClient::sendSetMode(int droneId, const QString& mode)
{
    QJsonObject cmd;
    cmd["type"] = QStringLiteral("set_mode");
    cmd["command"] = QStringLiteral("set_mode");
    cmd["drone_id"] = droneId;
    cmd["mode"] = mode.toUpper();
    sendCommand(cmd);
    qDebug() << "Sent SET_MODE" << mode << "for drone" << droneId;
}
