#include "networkutils.h"
#include <QUrl>
#include <QUuid>

QString NetworkUtils::baseUrl()
{
    return QStringLiteral("https://public-api.etoro.com/api/v1");
}

QString NetworkUtils::createRequestId()
{
    QString id = QUuid::createUuid().toString();
    id.remove('{');
    id.remove('}');
    return id;
}

QNetworkRequest NetworkUtils::buildAuthenticatedRequest(const QString &path,
                                                        const QString &apiKey,
                                                        const QString &userKey)
{
    const QUrl url(baseUrl() + path);
    QNetworkRequest req(url);

    req.setRawHeader("Accept", "application/json");
    req.setRawHeader("Content-Type", "application/json");
    req.setRawHeader("x-api-key", apiKey.toUtf8());
    req.setRawHeader("x-user-key", userKey.toUtf8());
    req.setRawHeader("x-request-id", createRequestId().toUtf8());

    return req;
}
