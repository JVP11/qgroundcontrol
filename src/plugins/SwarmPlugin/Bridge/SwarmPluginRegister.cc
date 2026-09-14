#include "SwarmBridge.h"

#include <QtQml/qqml.h>

namespace {

void registerSwarmPluginQmlTypes()
{
    qmlRegisterType<SwarmBridge>("QGroundControl.SwarmPlugin", 1, 0, "SwarmBridge");
}

} // namespace

Q_COREAPP_STARTUP_FUNCTION(registerSwarmPluginQmlTypes)
