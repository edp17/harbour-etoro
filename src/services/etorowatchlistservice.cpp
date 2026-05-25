#include "etorowatchlistservice.h"
#include "../networkutils.h"
#include "../applog.h"

#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDateTime>
#include <QUrlQuery>
#include <QBuffer>
#include <QIODevice>
#include <QDebug>

EtoroWatchlistService::EtoroWatchlistService(QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent)
    , m_nam(nam)
{
}

static QString cleanWatchlistName(const QString &name)
{
    const QString trimmed = name.trimmed();

    if (trimmed == QStringLiteral("watchlistItem.emptyState.favouriteWatchlistName"))
        return QStringLiteral("Favourites");

    if (trimmed == QStringLiteral("watchlistItem.emptyState.recentlyInvestedWatchlistName"))
        return QStringLiteral("Recently Invested");

    if (trimmed.isEmpty())
        return QStringLiteral("Unnamed watchlist");

    return trimmed;
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
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO WATCHLISTS STATUS:" << httpStatus;
            qWarning() << "ETORO WATCHLISTS BODY:" << body;
        }

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
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO WATCHLIST STATUS:" << httpStatus;
            qWarning() << "ETORO WATCHLIST BODY:" << body;
        }

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
            watchlistName = cleanWatchlistName(wl.value("name").toString());
            items = wl.value("items").toList();
        } else {
            watchlistName = cleanWatchlistName(root.value("name").toString());
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

void EtoroWatchlistService::addInstrumentToWatchlist(const QString &watchlistId,
                                                     const QVariantMap &instrument,
                                                     const QString &apiKey,
                                                     const QString &userKey)
{
    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/watchlists/%1/items").arg(watchlistId),
                apiKey,
                userKey);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    QVariantMap item;
    item.insert(QStringLiteral("itemId"), instrument.value(QStringLiteral("instrumentId")).toInt());
    item.insert(QStringLiteral("itemType"), QStringLiteral("Instrument"));
    item.insert(QStringLiteral("itemRank"), 0);
    item.insert(QStringLiteral("itemAddedReason"), QStringLiteral("Manual"));
    item.insert(QStringLiteral("itemAddedDate"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));

    QVariantMap market;
    market.insert(QStringLiteral("id"), instrument.value(QStringLiteral("instrumentId")));
    market.insert(QStringLiteral("symbolName"), instrument.value(QStringLiteral("symbol")));
    market.insert(QStringLiteral("displayName"), instrument.value(QStringLiteral("displayName")));
    market.insert(QStringLiteral("assetTypeId"), instrument.value(QStringLiteral("instrumentTypeId")));
    market.insert(QStringLiteral("exchangeId"), instrument.value(QStringLiteral("exchangeId")));
    item.insert(QStringLiteral("market"), market);

    QVariantList payload;
    payload << item;

    const QByteArray body = QJsonDocument::fromVariant(payload).toJson(QJsonDocument::Compact);
    if (AppLog::debugEnabled())
        qWarning() << "ETORO ADD WATCHLIST ITEM PAYLOAD:" << body;

    QNetworkReply *reply = m_nam->post(req, body);

    connect(reply, &QNetworkReply::finished, this, [this, reply, watchlistId, instrument]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO ADD WATCHLIST ITEM STATUS:" << httpStatus;
            qWarning() << "ETORO ADD WATCHLIST ITEM BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        emit watchlistItemAdded(watchlistId, instrument);
    });
}

void EtoroWatchlistService::createWatchlist(const QString &name,
                                            const QString &apiKey,
                                            const QString &userKey)
{
    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/watchlists"),
                apiKey,
                userKey);

    QUrl url = req.url();
    QUrlQuery query(url);
    query.addQueryItem(QStringLiteral("type"), QStringLiteral("Static"));
    query.addQueryItem(QStringLiteral("name"), name.trimmed());
    url.setQuery(query);
    req.setUrl(url);
    if (AppLog::debugEnabled())
        qWarning() << "ETORO CREATE WATCHLIST URL:" << req.url().toString();

    QNetworkReply *reply = m_nam->post(req, QByteArray());

    connect(reply, &QNetworkReply::finished, this, [this, reply, name]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO CREATE WATCHLIST STATUS:" << httpStatus;
            qWarning() << "ETORO CREATE WATCHLIST BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QString watchlistId;

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
        if (pe.error == QJsonParseError::NoError && doc.isObject()) {
            const QVariantMap root = doc.object().toVariantMap();

            watchlistId = root.value(QStringLiteral("watchlistId")).toString();
            if (watchlistId.isEmpty())
                watchlistId = root.value(QStringLiteral("id")).toString();

            const QVariantList watchlists = root.value(QStringLiteral("watchlists")).toList();
            if (watchlistId.isEmpty() && !watchlists.isEmpty()) {
                const QVariantMap wl = watchlists.first().toMap();
                watchlistId = wl.value(QStringLiteral("watchlistId")).toString();
                if (watchlistId.isEmpty())
                    watchlistId = wl.value(QStringLiteral("id")).toString();
            }
        }

        emit watchlistCreated(watchlistId, name.trimmed());
    });
}

void EtoroWatchlistService::renameWatchlist(const QString &watchlistId,
                                            const QString &name,
                                            const QString &apiKey,
                                            const QString &userKey)
{
    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/watchlists/%1").arg(watchlistId),
                apiKey,
                userKey);

    QUrl url = req.url();
    QUrlQuery query(url);
    query.addQueryItem(QStringLiteral("newName"), name.trimmed());
    url.setQuery(query);
    req.setUrl(url);
    if (AppLog::debugEnabled())
        qWarning() << "ETORO RENAME WATCHLIST URL:" << req.url().toString();

    QBuffer *buffer = new QBuffer;
    buffer->setData(QByteArray());
    buffer->open(QIODevice::ReadOnly);

    QNetworkReply *reply = m_nam->sendCustomRequest(req, QByteArrayLiteral("PUT"), buffer);
    buffer->setParent(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply, watchlistId, name]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO RENAME WATCHLIST STATUS:" << httpStatus;
            qWarning() << "ETORO RENAME WATCHLIST BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        emit watchlistRenamed(watchlistId, name.trimmed());
    });
}

void EtoroWatchlistService::deleteWatchlist(const QString &watchlistId,
                                            const QString &apiKey,
                                            const QString &userKey)
{
    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/watchlists/%1").arg(watchlistId),
                apiKey,
                userKey);
    if (AppLog::debugEnabled())
        qWarning() << "ETORO DELETE WATCHLIST URL:" << req.url().toString();

    QBuffer *buffer = new QBuffer;
    buffer->setData(QByteArray());
    buffer->open(QIODevice::ReadOnly);

    QNetworkReply *reply = m_nam->sendCustomRequest(req, QByteArrayLiteral("DELETE"), buffer);
    buffer->setParent(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply, watchlistId]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO DELETE WATCHLIST STATUS:" << httpStatus;
            qWarning() << "ETORO DELETE WATCHLIST BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        emit watchlistDeleted(watchlistId);
    });
}

void EtoroWatchlistService::removeInstrumentFromWatchlist(const QString &watchlistId,
                                                          const QVariantMap &instrument,
                                                          const QString &apiKey,
                                                          const QString &userKey)
{
    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/watchlists/%1/items").arg(watchlistId),
                apiKey,
                userKey);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    QVariantMap item;
    item.insert(QStringLiteral("ItemId"), instrument.value(QStringLiteral("instrumentId")).toInt());
    item.insert(QStringLiteral("ItemType"), QStringLiteral("Instrument"));
    item.insert(QStringLiteral("ItemRank"), instrument.value(QStringLiteral("itemRank")).toInt());

    QVariantList payload;
    payload << item;

    const QByteArray body = QJsonDocument::fromVariant(payload).toJson(QJsonDocument::Compact);
    if (AppLog::debugEnabled())
        qWarning() << "ETORO REMOVE WATCHLIST ITEM PAYLOAD:" << body;

    QBuffer *buffer = new QBuffer;
    buffer->setData(body);
    buffer->open(QIODevice::ReadOnly);

    QNetworkReply *reply = m_nam->sendCustomRequest(req, QByteArrayLiteral("DELETE"), buffer);
    buffer->setParent(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply, watchlistId, instrument]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO REMOVE WATCHLIST ITEM STATUS:" << httpStatus;
            qWarning() << "ETORO REMOVE WATCHLIST ITEM BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        emit watchlistItemRemoved(watchlistId, instrument);
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
        wl.insert("name", cleanWatchlistName(in.value("name").toString()));
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
