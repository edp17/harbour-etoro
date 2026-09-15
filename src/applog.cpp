#include "applog.h"
#include "settingsutils.h"

static const char *KEY_DEBUG_LOGGING_ENABLED = "debug/loggingEnabled";

bool AppLog::debugEnabled()
{
    QSettings settings = SettingsUtils::createSettings();
    return settings.value(KEY_DEBUG_LOGGING_ENABLED, false).toBool();
}

void AppLog::setDebugEnabled(bool enabled)
{
    QSettings settings = SettingsUtils::createSettings();
    settings.setValue(KEY_DEBUG_LOGGING_ENABLED, enabled);
}
