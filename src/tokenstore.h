#ifndef TOKENSTORE_H
#define TOKENSTORE_H

#include <QObject>
#include <QString>

class TokenStore : public QObject
{
    Q_OBJECT
public:
    explicit TokenStore(QObject *parent = nullptr);

    bool saveApiKey(const QString &value);
    bool saveUserKey(const QString &value);

    QString apiKey() const;
    QString userKey() const;

    bool clearAll();
    bool hasCredentials() const;

    bool pinEnabled() const;
    QString pin() const;
    bool setPin(const QString &pin);
    bool clearPin();

    QString lastError() const;

    bool saveRealUserKey(const QString &value);
    bool saveDemoUserKey(const QString &value);

    QString realUserKey() const;
    QString demoUserKey() const;

    bool clearRealUserKey();
    bool clearDemoUserKey();

    bool hasApiKey() const;
    bool hasRealUserKey() const;
    bool hasDemoUserKey() const;
    bool hasCredentialsForMode(bool demo) const;
    QString userKeyForMode(bool demo) const;

private:
    QString loadSecret(const QString &secretName) const;
    bool saveSecret(const QString &secretName, const QString &value);
    bool clearSecret(const QString &secretName);

    bool readFlag(const QString &key) const;
    void writeFlag(const QString &key, bool value);

    void setError(const QString &error) const;

private:
    mutable QString m_lastError;
};

#endif // TOKENSTORE_H
