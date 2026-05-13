#ifndef NETWORKUTILS_H
#define NETWORKUTILS_H

#include <QString>
#include <QNetworkRequest>

class NetworkUtils
{
public:
    static QString baseUrl();
    static QString createRequestId();

    static QNetworkRequest buildAuthenticatedRequest(const QString &path,
                                                     const QString &apiKey,
                                                     const QString &userKey);
};

#endif // NETWORKUTILS_H
