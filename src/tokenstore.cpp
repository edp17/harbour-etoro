#include "tokenstore.h"

#include <QSettings>
#include <Sailfish/Secrets/secretmanager.h>
#include <Sailfish/Secrets/secret.h>
#include <Sailfish/Secrets/storedsecretrequest.h>
#include <Sailfish/Secrets/storesecretrequest.h>
#include <Sailfish/Secrets/deletesecretrequest.h>

namespace {

static const char *SECRET_API_KEY = "etoro-api-key";
static const char *SECRET_USER_KEY = "etoro-user-key";
static const char *SECRET_APP_PIN = "etoro-app-pin";

static const char *SETTINGS_ORG = "harbour-etoro";
static const char *SETTINGS_APP = "harbour-etoro";
static const char *SETTINGS_GROUP = "auth";
static const char *SETTINGS_KEY_HAS_API_KEY = "hasStoredApiKey";
static const char *SETTINGS_KEY_HAS_USER_KEY = "hasStoredUserKey";
static const char *SETTINGS_KEY_HAS_PIN = "hasStoredPin";

static Sailfish::Secrets::Secret::Identifier tokenIdentifier(const QString &secretName)
{
    return Sailfish::Secrets::Secret::Identifier(
                secretName,
                QString(),
                Sailfish::Secrets::SecretManager::DefaultStoragePluginName);
}

static bool isOwnedByDifferentApplicationError(const QString &error)
{
    return error.contains(QStringLiteral("owned by a different application"), Qt::CaseInsensitive);
}

static bool isIgnorableClearError(const QString &error)
{
    if (error.isEmpty())
        return true;

    return error.contains(QStringLiteral("not found"), Qt::CaseInsensitive)
            || error.contains(QStringLiteral("does not exist"), Qt::CaseInsensitive)
            || isOwnedByDifferentApplicationError(error);
}

} // namespace

TokenStore::TokenStore(QObject *parent)
    : QObject(parent)
{
}

QString TokenStore::loadSecret(const QString &secretName) const
{
    m_lastError.clear();

    Sailfish::Secrets::SecretManager manager;
    Sailfish::Secrets::StoredSecretRequest request;
    request.setManager(&manager);
    request.setIdentifier(tokenIdentifier(secretName));
    request.setUserInteractionMode(Sailfish::Secrets::SecretManager::SystemInteraction);
    request.startRequest();
    request.waitForFinished();

    if (request.result().code() == Sailfish::Secrets::Result::Succeeded) {
        return QString::fromUtf8(request.secret().data()).trimmed();
    }

    m_lastError = request.result().errorMessage();
    return QString();
}

bool TokenStore::saveSecret(const QString &secretName, const QString &value)
{
    m_lastError.clear();

    const QString cleaned = value.trimmed();
    if (cleaned.isEmpty()) {
        setError(QStringLiteral("Value is empty"));
        return false;
    }

    auto tryStore = [&](QString *errorOut) -> bool {
        Sailfish::Secrets::Secret secret(tokenIdentifier(secretName));
        secret.setData(cleaned.toUtf8());
        secret.setType(Sailfish::Secrets::Secret::TypeBlob);

        Sailfish::Secrets::SecretManager manager;
        Sailfish::Secrets::StoreSecretRequest request;
        request.setManager(&manager);
        request.setSecretStorageType(Sailfish::Secrets::StoreSecretRequest::StandaloneDeviceLockSecret);
        request.setDeviceLockUnlockSemantic(
                    Sailfish::Secrets::SecretManager::DeviceLockKeepUnlocked);
        request.setAccessControlMode(
                    Sailfish::Secrets::SecretManager::OwnerOnlyMode);
        request.setEncryptionPluginName(
                    Sailfish::Secrets::SecretManager::DefaultEncryptionPluginName);
        request.setUserInteractionMode(
                    Sailfish::Secrets::SecretManager::SystemInteraction);
        request.setSecret(secret);
        request.startRequest();
        request.waitForFinished();

        if (request.result().code() == Sailfish::Secrets::Result::Succeeded)
            return true;

        if (errorOut)
            *errorOut = request.result().errorMessage();
        return false;
    };

    // First try: best-effort delete old value, then store.
    clearSecret(secretName);

    QString error;
    if (tryStore(&error))
        return true;

    // Some devices/images can still report that the standalone secret exists.
    // Retry once after another explicit delete.
    if (error.contains(QStringLiteral("Cannot overwrite existing standalone secret"),
                       Qt::CaseInsensitive)) {
        clearSecret(secretName);
        error.clear();
        if (tryStore(&error))
            return true;
    }

    setError(error);
    return false;
}

bool TokenStore::clearSecret(const QString &secretName)
{
    m_lastError.clear();

    Sailfish::Secrets::SecretManager manager;
    Sailfish::Secrets::DeleteSecretRequest request;
    request.setManager(&manager);
    request.setIdentifier(tokenIdentifier(secretName));
    request.setUserInteractionMode(Sailfish::Secrets::SecretManager::SystemInteraction);
    request.startRequest();
    request.waitForFinished();

    if (request.result().code() == Sailfish::Secrets::Result::Succeeded)
        return true;

    const QString error = request.result().errorMessage();
    if (isIgnorableClearError(error)) {
        m_lastError.clear();
        return true;
    }

    setError(error);
    return false;
}

bool TokenStore::readFlag(const QString &key) const
{
    QSettings settings(QString::fromLatin1(SETTINGS_ORG), QString::fromLatin1(SETTINGS_APP));
    settings.beginGroup(QString::fromLatin1(SETTINGS_GROUP));
    const bool value = settings.value(key, false).toBool();
    settings.endGroup();
    return value;
}

void TokenStore::writeFlag(const QString &key, bool value)
{
    QSettings settings(QString::fromLatin1(SETTINGS_ORG), QString::fromLatin1(SETTINGS_APP));
    settings.beginGroup(QString::fromLatin1(SETTINGS_GROUP));
    settings.setValue(key, value);
    settings.endGroup();
    settings.sync();
}

bool TokenStore::saveApiKey(const QString &value)
{
    if (!saveSecret(QString::fromLatin1(SECRET_API_KEY), value))
        return false;

    writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_API_KEY), true);
    return true;
}

bool TokenStore::saveUserKey(const QString &value)
{
    if (!saveSecret(QString::fromLatin1(SECRET_USER_KEY), value))
        return false;

    writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_USER_KEY), true);
    return true;
}

QString TokenStore::apiKey() const
{
    return loadSecret(QString::fromLatin1(SECRET_API_KEY));
}

QString TokenStore::userKey() const
{
    return loadSecret(QString::fromLatin1(SECRET_USER_KEY));
}

bool TokenStore::clearAll()
{
    const bool a = clearSecret(QString::fromLatin1(SECRET_API_KEY));
    const bool b = clearSecret(QString::fromLatin1(SECRET_USER_KEY));
    const bool c = clearSecret(QString::fromLatin1(SECRET_APP_PIN));

    if (a)
        writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_API_KEY), false);
    if (b)
        writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_USER_KEY), false);
    if (c)
        writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_PIN), false);

    return a && b && c;
}

bool TokenStore::hasCredentials() const
{
    return readFlag(QString::fromLatin1(SETTINGS_KEY_HAS_API_KEY))
            && readFlag(QString::fromLatin1(SETTINGS_KEY_HAS_USER_KEY));
}

bool TokenStore::pinEnabled() const
{
    return readFlag(QString::fromLatin1(SETTINGS_KEY_HAS_PIN)) && !pin().isEmpty();
}

QString TokenStore::pin() const
{
    return loadSecret(QString::fromLatin1(SECRET_APP_PIN));
}

bool TokenStore::setPin(const QString &pin)
{
    if (!saveSecret(QString::fromLatin1(SECRET_APP_PIN), pin))
        return false;

    writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_PIN), true);
    return true;
}

bool TokenStore::clearPin()
{
    if (!clearSecret(QString::fromLatin1(SECRET_APP_PIN)))
        return false;

    writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_PIN), false);
    return true;
}

QString TokenStore::lastError() const
{
    return m_lastError;
}

void TokenStore::setError(const QString &error) const
{
    m_lastError = error;
}
