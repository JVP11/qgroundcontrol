/****************************************************************************
 *
 * ASTHRA Swarm Backend Integration
 * QML type registration
 *
 ****************************************************************************/

#include "SwarmWebSocketClient.h"
#include <QtQml>

static void _swarmBackendRegisterQmlTypes()
{
    qmlRegisterType<SwarmWebSocketClient>("ASTHRA.Swarm", 1, 0, "SwarmWebSocketClient");
    qmlRegisterUncreatableType<SwarmDrone>("ASTHRA.Swarm", 1, 0, "SwarmDrone", "SwarmDrone is created by SwarmWebSocketClient");
}

Q_COREAPP_STARTUP_FUNCTION(_swarmBackendRegisterQmlTypes)
