/****************************************************************************
 *
 * ASTHRA Swarm Backend Integration
 * WebSocket client to connect to Python swarm backend
 *
 ****************************************************************************/

#pragma once

#include <QObject>
#include <QWebSocket>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>
#include <QGeoCoordinate>

class SwarmDrone : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int droneId READ droneId NOTIFY droneIdChanged)
    Q_PROPERTY(double lat READ lat NOTIFY positionChanged)
    Q_PROPERTY(double lng READ lng NOTIFY positionChanged)
    Q_PROPERTY(double alt READ alt NOTIFY positionChanged)
    Q_PROPERTY(int batteryPct READ batteryPct NOTIFY batteryChanged)
    Q_PROPERTY(QString flightMode READ flightMode NOTIFY flightModeChanged)
    Q_PROPERTY(bool armed READ armed NOTIFY armedChanged)
    Q_PROPERTY(int rssi READ rssi NOTIFY rssiChanged)
    Q_PROPERTY(QGeoCoordinate coordinate READ coordinate NOTIFY positionChanged)

public:
    explicit SwarmDrone(int id, QObject* parent = nullptr)
        : QObject(parent), _droneId(id), _lat(0), _lng(0), _alt(0),
          _batteryPct(-1), _armed(false), _rssi(-1) {}

    int droneId() const { return _droneId; }
    double lat() const { return _lat; }
    double lng() const { return _lng; }
    double alt() const { return _alt; }
    int batteryPct() const { return _batteryPct; }
    QString flightMode() const { return _flightMode; }
    bool armed() const { return _armed; }
    int rssi() const { return _rssi; }
    QGeoCoordinate coordinate() const { return QGeoCoordinate(_lat, _lng, _alt); }

    void updateFromJson(const QJsonObject& data) {
        bool changed = false;
        if (data.contains("lat")) { _lat = data["lat"].toDouble(); changed = true; }
        if (data.contains("lng")) { _lng = data["lng"].toDouble(); changed = true; }
        if (data.contains("alt")) { _alt = data["alt"].toDouble(); changed = true; }
        else if (data.contains("alt_m")) { _alt = data["alt_m"].toDouble(); changed = true; }
        if (changed) emit positionChanged();

        if (data.contains("battery_pct")) {
            _batteryPct = data["battery_pct"].toInt();
            emit batteryChanged();
        }
        if (data.contains("flight_mode")) {
            _flightMode = data["flight_mode"].toString();
            emit flightModeChanged();
        }
        if (data.contains("armed")) {
            _armed = data["armed"].toBool();
            emit armedChanged();
        }
        if (data.contains("rssi")) {
            _rssi = data["rssi"].toInt();
            emit rssiChanged();
        }
    }

signals:
    void droneIdChanged();
    void positionChanged();
    void batteryChanged();
    void flightModeChanged();
    void armedChanged();
    void rssiChanged();

private:
    int _droneId;
    double _lat, _lng, _alt;
    int _batteryPct;
    QString _flightMode;
    bool _armed;
    int _rssi;
};

class SwarmWebSocketClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QVariantList drones READ drones NOTIFY dronesChanged)
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)

public:
    explicit SwarmWebSocketClient(QObject* parent = nullptr);
    ~SwarmWebSocketClient();

    bool connected() const { return _connected; }
    QVariantList drones() const;
    QString serverUrl() const { return _serverUrl; }
    void setServerUrl(const QString& url);

    Q_INVOKABLE void connectToBackend();
    Q_INVOKABLE void disconnectFromBackend();
    Q_INVOKABLE void sendArm(int droneId);
    Q_INVOKABLE void sendDisarm(int droneId);
    Q_INVOKABLE void sendSetMode(int droneId, const QString& mode);

signals:
    void connectedChanged();
    void dronesChanged();
    void serverUrlChanged();
    void errorOccurred(QString message);

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString& message);
    void onError(QAbstractSocket::SocketError error);
    void attemptReconnect();

private:
    void handleTelemetryMessage(const QJsonObject& data);
    void sendCommand(const QJsonObject& command);

    QWebSocket _webSocket;
    bool _connected;
    QString _serverUrl;
    QMap<int, SwarmDrone*> _droneMap;
    QTimer _reconnectTimer;
};
