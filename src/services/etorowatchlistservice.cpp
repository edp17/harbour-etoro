#include "etorowatchlistservice.h"
#include "../networkutils.h"

#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

EtoroWatchlistService::EtoroWatchlistService(QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent)
    , m_nam(nam)
{
}

void EtoroWatchlistService::fetchWatchlists(const QString &apiKey, const QString &userKey)
{
    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/watchlists"),
                apiKey,
                userKey);

    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();

        qWarning() << "ETORO WATCHLISTS STATUS:" << httpStatus;
        qWarning() << "ETORO WATCHLISTS BODY:" << body;

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
        if (pe.error != QJsonParseError::NoError || !doc.isObject()) {
            emit requestFailed(QStringLiteral("Invalid watchlists JSON response"), httpStatus, body);
            return;
        }

        const QVariantMap root = doc.object().toVariantMap();
        emit watchlistsReady(parseWatchlistsRoot(root));
    });
}

void EtoroWatchlistService::fetchWatchlist(const QString &watchlistId,
                                           const QString &apiKey,
                                           const QString &userKey)
{
    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/watchlists/") + watchlistId,
                apiKey,
                userKey);

    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply, watchlistId]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();

        qWarning() << "ETORO WATCHLIST STATUS:" << httpStatus;
        qWarning() << "ETORO WATCHLIST BODY:" << body;

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
        if (pe.error != QJsonParseError::NoError || !doc.isObject()) {
            emit requestFailed(QStringLiteral("Invalid watchlist JSON response"), httpStatus, body);
            return;
        }

        const QVariantMap root = doc.object().toVariantMap();
        const QVariantList watchlists = root.value("watchlists").toList();

        QString watchlistName;
        QVariantList items;

        if (!watchlists.isEmpty()) {
            const QVariantMap wl = watchlists.first().toMap();
            watchlistName = wl.value("name").toString();
            items = wl.value("items").toList();
        } else {
            watchlistName = root.value("name").toString();
            items = parseSingleWatchlistItems(root);
        }

        QVariantList normalized;
        for (const QVariant &v : items) {
            const QVariantMap in = v.toMap();
            const QString itemType = in.value("itemType").toString();

            if (itemType.compare(QStringLiteral("Instrument"), Qt::CaseInsensitive) != 0)
                continue;

            QVariantMap out;
            out.insert("itemId", in.value("itemId"));
            out.insert("itemType", in.value("itemType"));
            out.insert("itemRank", in.value("itemRank"));

            const QVariantMap market = in.value("market").toMap();
            if (!market.isEmpty()) {
                out.insert("instrumentId", market.value("id"));
                out.insert("displayName", market.value("displayName"));
                out.insert("symbol", market.value("symbolName"));
                out.insert("exchangeId", market.value("exchangeId"));
                out.insert("assetTypeId", market.value("assetTypeId"));
            } else {
                out.insert("instrumentId", in.value("itemId"));
                out.insert("displayName", firstNonEmpty(in, {"displayName", "name"}));
                out.insert("symbol", firstNonEmpty(in, {"symbol", "symbolName"}));
            }

            normalized.append(out);
        }

        emit watchlistItemsReady(watchlistId, watchlistName, normalized);
    });
}

QVariantList EtoroWatchlistService::parseWatchlistsRoot(const QVariantMap &root) const
{
    const QVariantList raw = root.value("watchlists").toList();
    QVariantList out;

    for (const QVariant &v : raw) {
        const QVariantMap in = v.toMap();
        QVariantMap wl;

        wl.insert("watchlistId", in.value("watchlistId"));
        wl.insert("name", in.value("name"));
        wl.insert("watchlistType", in.value("watchlistType"));
        wl.insert("totalItems", in.value("totalItems"));
        wl.insert("isDefault", in.value("isDefault"));
        wl.insert("isUserSelectedDefault", in.value("isUserSelectedDefault"));
        wl.insert("watchlistRank", in.value("watchlistRank"));
        wl.insert("dynamicUrl", in.value("dynamicUrl"));

        const QVariantList items = in.value("items").toList();
        wl.insert("itemsCount", !items.isEmpty() ? items.count() : in.value("totalItems"));

        out.append(wl);
    }

    return out;
}

QVariantList EtoroWatchlistService::parseSingleWatchlistItems(const QVariantMap &root) const
{
    if (root.contains("items") && root.value("items").type() == QVariant::List)
        return root.value("items").toList();

    return QVariantList();
}

QString EtoroWatchlistService::firstNonEmpty(const QVariantMap &map, const QStringList &keys)
{
    for (const QString &k : keys) {
        const QString value = map.value(k).toString().trimmed();
        if (!value.isEmpty())
            return value;
    }
    return QString();
}
