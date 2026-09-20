#include "SwarmBridge.h"

#include "Vehicle.h"
#include "MultiVehicleManager.h"
#include "MissionManager.h"
#include "MissionItem.h"
#include "QmlObjectListModel.h"
#include "Fact.h"
#include "BatteryFactGroupListModel.h"

#include <QHash>

#include <QJsonDocument>
#include <QJsonArray>
#include <QVariantMap>
#include <QtMath>
#include <QDebug>

#include <QtPositioning/QGeoCoordinate>

#include "QGCApplication.h"
#include "QGCMAVLink.h"

SwarmBridge::SwarmBridge(QObject* parent)
    : QObject(parent)
{
    _socket = new QTcpSocket(this);
    connect(_socket, &QTcpSocket::connected,    this, &SwarmBridge::_onConnected);
    connect(_socket, &QTcpSocket::readyRead,    this, &SwarmBridge::_onReadyRead);
    connect(_socket, &QTcpSocket::errorOccurred, this, &SwarmBridge::_onError);

    _pollTimer = new QTimer(this);
    _pollTimer->setInterval(POLL_MS);
    connect(_pollTimer, &QTimer::timeout, this, &SwarmBridge::_pollCoordinator);

    _vehicleTimer = new QTimer(this);
    _vehicleTimer->setInterval(POLL_MS);
    connect(_vehicleTimer, &QTimer::timeout, this, &SwarmBridge::_refreshFromVehicles);
    _vehicleTimer->start();

    _reconnTimer = new QTimer(this);
    _reconnTimer->setInterval(2000);
    connect(_reconnTimer, &QTimer::timeout, this, [this]{ _connect(); });

    if (MultiVehicleManager* mgr = MultiVehicleManager::instance()) {
        connect(mgr, &MultiVehicleManager::vehicleAdded, this, [this](Vehicle*) { _refreshFromVehicles(); });
        connect(mgr, &MultiVehicleManager::vehicleRemoved, this, [this](Vehicle*) { _refreshFromVehicles(); });
    }

    _connect();
    _refreshFromVehicles();
}

SwarmBridge::~SwarmBridge()
{
    _pollTimer->stop();
    _vehicleTimer->stop();
    _reconnTimer->stop();
    _socket->disconnectFromHost();
}

bool SwarmBridge::webEngineAvailable() const
{
#ifdef QGC_SWARM_WEBENGINE
    return true;
#else
    return false;
#endif
}

void SwarmBridge::refreshNow()
{
    _refreshFromVehicles();
    _pollCoordinator();
}

void SwarmBridge::_connect()
{
    if (_socket->state() == QAbstractSocket::ConnectedState) {
        return;
    }
    _socket->connectToHost(QString::fromLatin1(HOST), PORT);
}

void SwarmBridge::_onConnected()
{
    qDebug() << "[SwarmBridge] Coordinator connected";
    if (!_coordinatorConnected) {
        _coordinatorConnected = true;
        emit coordinatorConnectedChanged();
        emit connectedChanged();
    }
    _reconnTimer->stop();
    _pollTimer->start();
}

void SwarmBridge::_onError(QAbstractSocket::SocketError)
{
    if (_coordinatorConnected) {
        _coordinatorConnected = false;
        emit coordinatorConnectedChanged();
        emit connectedChanged();
        _pollTimer->stop();
    }
    _reconnTimer->start();
    _mergeStates();
}

void SwarmBridge::_pollCoordinator()
{
    if (_socket->state() != QAbstractSocket::ConnectedState) {
        return;
    }
    QJsonObject req;
    req[QStringLiteral("cmd")] = QStringLiteral("state");
    _socket->write(QJsonDocument(req).toJson(QJsonDocument::Compact) + "\n");
}

void SwarmBridge::_onReadyRead()
{
    _readBuf += _socket->readAll();
    int nl;
    while ((nl = _readBuf.indexOf('\n')) != -1) {
        QByteArray line = _readBuf.left(nl);
        _readBuf.remove(0, nl + 1);
        _parseCoordinatorState(line);
    }
}

void SwarmBridge::_parseCoordinatorState(const QByteArray& json)
{
    QJsonDocument doc = QJsonDocument::fromJson(json);
    if (doc.isNull()) {
        return;
    }

    QJsonObject root = doc.object();

    QString mode = root[QStringLiteral("mode")].toString();
    if (!mode.isEmpty() && mode != _swarmMode) {
        _swarmMode = mode;
        emit swarmModeChanged();
    }

    QVariantList list;
    for (const QJsonValue& v : root[QStringLiteral("drones")].toArray()) {
        QJsonObject d = v.toObject();
        QVariantMap m;
        m[QStringLiteral("sysid")]             = d[QStringLiteral("sysid")].toInt();
        m[QStringLiteral("x")]                 = d[QStringLiteral("x")].toDouble();
        m[QStringLiteral("y")]                 = d[QStringLiteral("y")].toDouble();
        m[QStringLiteral("z")]                 = d[QStringLiteral("z")].toDouble();
        m[QStringLiteral("yaw")]               = d[QStringLiteral("yaw")].toDouble();
        m[QStringLiteral("armed")]             = d[QStringLiteral("armed")].toBool();
        m[QStringLiteral("mode")]              = d[QStringLiteral("mode")].toString();
        m[QStringLiteral("battery_pct")]       = d[QStringLiteral("battery_pct")].toInt();
        m[QStringLiteral("collision_warning")] = d[QStringLiteral("collision_warning")].toBool();
        m[QStringLiteral("last_seen")]         = d[QStringLiteral("last_seen")].toDouble();
        m[QStringLiteral("from_vehicle")]      = false;
        list.append(m);
    }
    _coordinatorStates = list;
    _mergeStates();
}

QVariantMap SwarmBridge::_stateFromVehicle(Vehicle* vehicle) const
{
    QVariantMap m;
    if (!vehicle) {
        return m;
    }

    const int sysid = vehicle->id();
    m[QStringLiteral("sysid")] = sysid;
    m[QStringLiteral("from_vehicle")] = true;

    FactGroup* const localPos = vehicle->localPositionFactGroup();
    const double x = localPos->getFact(QStringLiteral("x"))->rawValue().toDouble();
    const double y = localPos->getFact(QStringLiteral("y"))->rawValue().toDouble();
    const double z = localPos->getFact(QStringLiteral("z"))->rawValue().toDouble();

    if (localPos->telemetryAvailable() && !qIsNaN(x) && !qIsNaN(y)) {
        m[QStringLiteral("x")] = x;
        m[QStringLiteral("y")] = y;
        m[QStringLiteral("z")] = qIsNaN(z) ? 0.0 : z;
        m[QStringLiteral("has_local_position")] = true;
    } else {
        const QGeoCoordinate coord = vehicle->coordinate();
        const QGeoCoordinate home = vehicle->homePosition();
        if (coord.isValid() && home.isValid()) {
            const double dist = home.distanceTo(coord);
            const double azRad = qDegreesToRadians(home.azimuthTo(coord));
            m[QStringLiteral("x")] = dist * qCos(azRad);
            m[QStringLiteral("y")] = dist * qSin(azRad);
            m[QStringLiteral("z")] = home.altitude() - coord.altitude();
            m[QStringLiteral("has_local_position")] = true;
            m[QStringLiteral("position_source")] = QStringLiteral("gps");
        } else {
            m[QStringLiteral("x")] = 0.0;
            m[QStringLiteral("y")] = 0.0;
            m[QStringLiteral("z")] = 0.0;
            m[QStringLiteral("has_local_position")] = false;
        }
    }

    const double headingDeg = vehicle->heading()->rawValue().toDouble();
    m[QStringLiteral("yaw")] = qDegreesToRadians(qIsNaN(headingDeg) ? 0.0 : headingDeg);
    m[QStringLiteral("armed")] = vehicle->armed();
    m[QStringLiteral("mode")] = vehicle->flightMode();

    int batteryPct = -1;
    QmlObjectListModel* const batteries = vehicle->batteries();
    if (batteries && batteries->count() > 0) {
        if (auto* battery = qobject_cast<BatteryFactGroup*>(batteries->get(0))) {
            batteryPct = static_cast<int>(battery->percentRemaining()->rawValue().toDouble());
        }
    }
    m[QStringLiteral("battery_pct")] = batteryPct < 0 ? -1 : qBound(0, batteryPct, 100);
    m[QStringLiteral("collision_warning")] = false;
    m[QStringLiteral("last_seen")] = 0.0;

    return m;
}

void SwarmBridge::_refreshFromVehicles()
{
    QVariantList list;
    MultiVehicleManager* const mgr = MultiVehicleManager::instance();
    if (mgr) {
        QmlObjectListModel* const vehicles = mgr->vehicles();
        for (int i = 0; i < vehicles->count(); ++i) {
            auto* const vehicle = qobject_cast<Vehicle*>(vehicles->get(i));
            if (vehicle) {
                list.append(_stateFromVehicle(vehicle));
            }
        }
    }

    const int newCount = list.size();
    if (newCount != _liveVehicleCount) {
        _liveVehicleCount = newCount;
        emit liveVehicleCountChanged();
    }

    const bool hadLive = _hasLiveVehicles;
    _hasLiveVehicles = newCount > 0;
    if (hadLive != _hasLiveVehicles) {
        emit connectedChanged();
    }

    _vehicleStates = list;
    _mergeStates();
}

void SwarmBridge::_mergeStates()
{
    // Prefer live ASTHRA vehicle telemetry; coordinator adds collision + formation mode only.
    QHash<int, QVariantMap> merged;

    for (const QVariant& v : _vehicleStates) {
        const QVariantMap m = v.toMap();
        merged.insert(m[QStringLiteral("sysid")].toInt(), m);
    }

    for (const QVariant& v : _coordinatorStates) {
        const QVariantMap coord = v.toMap();
        const int sysid = coord[QStringLiteral("sysid")].toInt();
        if (merged.contains(sysid)) {
            QVariantMap veh = merged[sysid];
            // Keep vehicle position when available; coordinator only enriches warnings
            if (!veh[QStringLiteral("has_local_position")].toBool()) {
                veh[QStringLiteral("x")] = coord[QStringLiteral("x")];
                veh[QStringLiteral("y")] = coord[QStringLiteral("y")];
                veh[QStringLiteral("z")] = coord[QStringLiteral("z")];
                veh[QStringLiteral("yaw")] = coord[QStringLiteral("yaw")];
                veh[QStringLiteral("has_local_position")] = true;
                veh[QStringLiteral("position_source")] = QStringLiteral("coordinator");
            }
            veh[QStringLiteral("collision_warning")] = coord[QStringLiteral("collision_warning")];
            if (!coord[QStringLiteral("mode")].toString().isEmpty()) {
                veh[QStringLiteral("coordinator_mode")] = coord[QStringLiteral("mode")];
            }
            merged[sysid] = veh;
        }
        // Coordinator-only slots (DRONE_IDS placeholders at 0,0,0) are not shown
        // until a real vehicle is connected in ASTHRA (see merged.contains above).
    }

    QVariantList list;
    for (auto it = merged.constBegin(); it != merged.constEnd(); ++it) {
        list.append(it.value());
    }

    if (list.isEmpty() && !_vehicleStates.isEmpty()) {
        list = _vehicleStates;
    }

    _droneStates = list;
    emit droneStatesChanged();
}

void SwarmBridge::sendCommand(const QJsonObject& cmd)
{
    if (_socket->state() != QAbstractSocket::ConnectedState) {
        return;
    }
    _socket->write(QJsonDocument(cmd).toJson(QJsonDocument::Compact) + "\n");
}

void SwarmBridge::setMode(const QString& mode)
{
    _swarmMode = mode;
    emit swarmModeChanged();

    QJsonObject cmd;
    cmd[QStringLiteral("cmd")] = QStringLiteral("mode");
    cmd[QStringLiteral("val")] = mode;
    sendCommand(cmd);
}

void SwarmBridge::setFormationOffsets(const QVariantMap& offsets)
{
    QJsonObject jOffsets;
    for (auto it = offsets.begin(); it != offsets.end(); ++it) {
        QVariantList triple = it.value().toList();
        QJsonArray arr;
        for (const QVariant& v : triple) {
            arr.append(v.toDouble());
        }
        jOffsets[it.key()] = arr;
    }
    QJsonObject cmd;
    cmd[QStringLiteral("cmd")]     = QStringLiteral("formation");
    cmd[QStringLiteral("offsets")] = jOffsets;
    sendCommand(cmd);
}

bool SwarmBridge::uploadLocalWaypoints(int vehicleId, const QVariantList& waypoints)
{
    MultiVehicleManager* const mgr = MultiVehicleManager::instance();
    if (!mgr) {
        qgcApp()->showAppMessage(tr("Vehicle manager not available"));
        return false;
    }

    Vehicle* vehicle = mgr->getVehicleByGcsId(vehicleId);
    if (!vehicle)
        vehicle = mgr->getVehicleById(vehicleId);
    if (!vehicle) {
        qgcApp()->showAppMessage(tr("Vehicle %1 is not connected").arg(vehicleId));
        return false;
    }

    if (waypoints.isEmpty()) {
        qgcApp()->showAppMessage(tr("Add waypoints on the map before uploading"));
        return false;
    }

    if (vehicle->missionManager()->inProgress()) {
        qgcApp()->showAppMessage(tr("Vehicle %1 mission transfer already in progress").arg(vehicleId));
        return false;
    }

    QList<MissionItem*> items;
    int seq = 0;

    // DJI-style: first item is current position (hold) then mission waypoints
    FactGroup* const localPos = vehicle->localPositionFactGroup();
    if (localPos->telemetryAvailable()) {
        const double cx = localPos->getFact(QStringLiteral("x"))->rawValue().toDouble();
        const double cy = localPos->getFact(QStringLiteral("y"))->rawValue().toDouble();
        const double cz = localPos->getFact(QStringLiteral("z"))->rawValue().toDouble();
        if (!qIsNaN(cx) && !qIsNaN(cy)) {
            items.append(new MissionItem(
                seq++, MAV_CMD_NAV_WAYPOINT, MAV_FRAME_LOCAL_NED,
                0, 0, 0, qQNaN(), cx, cy, qIsNaN(cz) ? 0.0 : cz,
                true, true, vehicle));
        }
    }

    for (const QVariant& v : waypoints) {
        const QVariantMap wp = v.toMap();
        items.append(new MissionItem(
            seq++,
            MAV_CMD_NAV_WAYPOINT,
            MAV_FRAME_LOCAL_NED,
            0, 0, 0, qQNaN(),
            wp.value(QStringLiteral("x")).toDouble(),
            wp.value(QStringLiteral("y")).toDouble(),
            wp.value(QStringLiteral("z")).toDouble(),
            true,
            false,
            vehicle));
    }

    vehicle->missionManager()->writeMissionItems(items);

    qgcApp()->showAppMessage(
        tr("Mission sent to Vehicle %1 — %2 waypoint(s). Switch to AUTO/MISSION on the vehicle.")
            .arg(vehicleId)
            .arg(waypoints.size()));
    return true;
}
