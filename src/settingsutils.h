#ifndef SETTINGSUTILS_H
#define SETTINGSUTILS_H

#include <QCoreApplication>
#include <QSettings>
#include <QStandardPaths>

namespace SettingsUtils {

inline QString settingsFilePath()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)
            + QLatin1Char('/')
            + QCoreApplication::applicationName()
            + QStringLiteral(".conf");
}

inline QSettings createSettings()
{
    return QSettings(settingsFilePath(), QSettings::NativeFormat);
}

} // namespace SettingsUtils

#endif
