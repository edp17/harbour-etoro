#include "applog.h"

#include <QSettings>

static const char *KEY_DEBUG_LOGGING_ENABLED = "debug/loggingEnabled";

bool AppLog::debugEnabled()
{
    QSettings settings;
    return settings.value(KEY_DEBUG_LOGGING_ENABLED, false).toBool();
}

void AppLog::setDebugEnabled(bool enabled)
{
    QSettings settings;
    settings.setValue(KEY_DEBUG_LOGGING_ENABLED, enabled);
}
