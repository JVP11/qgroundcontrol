#pragma once

#include <QObject>
#include <QTimer>
#include <QTcpSocket>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantList>
#include <QtQmlIntegration/QtQmlIntegration>

/**
 * SwarmBridge — live vehicle telemetry + optional coordinator overlay.
 */
class SwarmBridge : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList droneStates READ droneStates NOTIFY droneStatesChanged)
    Q_PROPERTY(QString      swarmMode   READ swarmMode   NOTIFY swarmModeChanged)
    Q_PROPERTY(bool         connected   READ connected   NOTIFY connectedChanged)
    Q_PROPERTY(int          liveVehicleCount READ liveVehicleCount NOTIFY liveVehicleCountChanged)
    Q_PROPERTY(bool         coordinatorConnected READ coordinatorConnected NOTIFY coordinatorConnectedChanged)
    Q_PROPERTY(bool         webEngineAvailable READ webEngineAvailable CONSTANT)

public:
    explicit SwarmBridge(QObject* parent = nullptr);
    ~SwarmBridge() override;

    QVariantList droneStates() const { return _droneStates; }
    QString      swarmMode()   const { return _swarmMode; }
    bool         connected()   const { return _hasLiveVehicles || _coordinatorConnected; }
    int          liveVehicleCount() const { return _liveVehicleCount; }
    bool         coordinatorConnected() const { return _coordinatorConnected; }
    bool         webEngineAvailable() const;

    /// @return true if mission write was started
    Q_INVOKABLE bool uploadLocalWaypoints(int vehicleId, const QVariantList& waypoints);
    Q_INVOKABLE void refreshNow();

public slots:
    void sendCommand(const QJsonObject& cmd);
    Q_INVOKABLE void setMode(const QString& mode);
    Q_INVOKABLE void setFormationOffsets(const QVariantMap& offsets);

signals:
    void droneStatesChanged();
    void swarmModeChanged();
    void connectedChanged();
    void liveVehicleCountChanged();
    void coordinatorConnectedChanged();

private slots:
    void _pollCoordinator();
    void _refreshFromVehicles();
    void _onConnected();
    void _onReadyRead();
    void _onError(QAbstractSocket::SocketError err);

private:
    void _connect();
    void _parseCoordinatorState(const QByteArray& json);
    void _mergeStates();
    QVariantMap _stateFromVehicle(class Vehicle* vehicle) const;

    QTcpSocket*  _socket      = nullptr;
    QTimer*      _pollTimer   = nullptr;
    QTimer*      _vehicleTimer = nullptr;
    QTimer*      _reconnTimer = nullptr;

    QVariantList _coordinatorStates;
    QVariantList _vehicleStates;
    QVariantList _droneStates;
    QString      _swarmMode   = QStringLiteral("formation");
    bool         _coordinatorConnected = false;
    bool         _hasLiveVehicles = false;
    int          _liveVehicleCount = 0;
    QByteArray   _readBuf;

    static constexpr const char* HOST = "127.0.0.1";
    static constexpr int         PORT = 7900;
    static constexpr int         POLL_MS = 100;
};
