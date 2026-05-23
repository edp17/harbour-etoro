#include "etoromarketservice.h"
#include "../networkutils.h"
#include "../applog.h"

#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QSet>
#include <QDebug>

EtoroMarketService::EtoroMarketService(QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent)
    , m_nam(nam)
{
}

void EtoroMarketService::fetchInstrumentMetadata(const QList<int> &instrumentIds,
                                                 const QString &apiKey,
                                                 const QString &userKey)
{
    if (instrumentIds.isEmpty()) {
        emit instrumentMetadataReady(QVariantMap());
        return;
    }

    QStringList idStrings;
    QSet<int> seen;
    for (int id : instrumentIds) {
        if (id <= 0 || seen.contains(id))
            continue;
        seen.insert(id);
        idStrings << QString::number(id);
    }

    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/market-data/instruments"),
                apiKey,
                userKey);

    QUrl url = req.url();
    QUrlQuery query(url);
    query.addQueryItem(QStringLiteral("instrumentIds"), idStrings.join(","));
    url.setQuery(query);
    req.setUrl(url);

    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO METADATA STATUS:" << httpStatus;
            qWarning() << "ETORO METADATA BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
        if (pe.error != QJsonParseError::NoError || !doc.isObject()) {
            emit requestFailed(QStringLiteral("Invalid metadata JSON response"), httpStatus, body);
            return;
        }

        const QVariantMap root = doc.object().toVariantMap();
        const QVariantList rows = root.value("instrumentDisplayDatas").toList();

        QVariantMap metadataById;
        for (const QVariant &rowVar : rows) {
            const QVariantMap row = rowVar.toMap();
            const QString id = row.value("instrumentID").toString();
            if (id.isEmpty())
                continue;

            QVariantMap item;
            item.insert("instrumentId", row.value("instrumentID"));
            item.insert("displayName", row.value("instrumentDisplayName").toString());
            item.insert("symbol", row.value("symbolFull").toString());
            item.insert("instrumentTypeId", row.value("instrumentTypeID"));
            item.insert("exchangeId", row.value("exchangeID"));
            item.insert("priceSource", row.value("priceSource").toString());
            item.insert(QStringLiteral("isBuyEnabled"), row.value(QStringLiteral("isBuyEnabled")));
            item.insert(QStringLiteral("isCurrentlyTradable"), row.value(QStringLiteral("isCurrentlyTradable")));
            item.insert(QStringLiteral("isExchangeOpen"), row.value(QStringLiteral("isExchangeOpen")));
            item.insert(QStringLiteral("tradingDisabled"), row.value(QStringLiteral("tradingDisabled")));

            metadataById.insert(id, item);
        }

        emit instrumentMetadataReady(metadataById);
    });
}

void EtoroMarketService::fetchInstrumentRates(const QList<int> &instrumentIds,
                                              const QString &apiKey,
                                              const QString &userKey)
{
    if (instrumentIds.isEmpty()) {
        emit instrumentRatesReady(QVariantMap());
        return;
    }

    QStringList idStrings;
    QSet<int> seen;
    for (int id : instrumentIds) {
        if (id <= 0 || seen.contains(id))
            continue;
        seen.insert(id);
        idStrings << QString::number(id);
    }

    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/market-data/instruments/rates"),
                apiKey,
                userKey);

    QUrl url = req.url();
    QUrlQuery query(url);
    query.addQueryItem(QStringLiteral("instrumentIds"), idStrings.join(","));
    url.setQuery(query);
    req.setUrl(url);

    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO RATES STATUS:" << httpStatus;
            qWarning() << "ETORO RATES BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
        if (pe.error != QJsonParseError::NoError) {
            emit requestFailed(QStringLiteral("Invalid rates JSON response"), httpStatus, body);
            return;
        }

        QVariantList rows;
        if (doc.isArray()) {
            rows = doc.array().toVariantList();
        } else if (doc.isObject()) {
            const QVariantMap root = doc.object().toVariantMap();
            if (root.contains("instrumentRates") && root.value("instrumentRates").type() == QVariant::List)
                rows = root.value("instrumentRates").toList();
            else if (root.contains("rates") && root.value("rates").type() == QVariant::List)
                rows = root.value("rates").toList();
            else if (root.contains("items") && root.value("items").type() == QVariant::List)
                rows = root.value("items").toList();
        }

        QVariantMap ratesById;
        for (const QVariant &rowVar : rows) {
            const QVariantMap row = rowVar.toMap();

            QString id = row.value("instrumentId").toString();
            if (id.isEmpty())
                id = row.value("instrumentID").toString();
            if (id.isEmpty())
                id = row.value("id").toString();
            if (id.isEmpty())
                continue;

            QVariantMap out;
            out.insert("instrumentId", id);

            out.insert("bid", row.value("bid"));
            out.insert("ask", row.value("ask"));

            // Map the actual fields returned by eToro
            out.insert("lastExecution", row.value("lastExecution"));
            out.insert("date", row.value("date"));
            out.insert("unitMargin", row.value("unitMargin"));
            out.insert("unitMarginAsk", row.value("unitMarginAsk"));
            out.insert("unitMarginBid", row.value("unitMarginBid"));
            out.insert("conversionRateAsk", row.value("conversionRateAsk"));
            out.insert("conversionRateBid", row.value("conversionRateBid"));

            // Keep a few compatibility aliases for the QML layer
            out.insert("close", row.value("lastExecution"));
            out.insert("lastExecutionPrice", row.value("lastExecution"));
            out.insert("buyPrice", row.value("unitMarginAsk"));
            out.insert("sellPrice", row.value("unitMarginBid"));
            out.insert("timestamp", row.value("date"));

            out.insert("raw", row);

            ratesById.insert(id, out);
        }

        emit instrumentRatesReady(ratesById);
    });
}

static QVariantList parseSearchResults(const QJsonDocument &doc)
{
    QVariantList rows;

    if (doc.isArray()) {
        rows = doc.array().toVariantList();
    } else if (doc.isObject()) {
        const QVariantMap root = doc.object().toVariantMap();

        if (root.value(QStringLiteral("instrumentDisplayDatas")).type() == QVariant::List)
            rows = root.value(QStringLiteral("instrumentDisplayDatas")).toList();
        else if (root.value(QStringLiteral("instruments")).type() == QVariant::List)
            rows = root.value(QStringLiteral("instruments")).toList();
        else if (root.value(QStringLiteral("items")).type() == QVariant::List)
            rows = root.value(QStringLiteral("items")).toList();
        else if (root.value(QStringLiteral("results")).type() == QVariant::List)
            rows = root.value(QStringLiteral("results")).toList();
        else if (root.value(QStringLiteral("data")).type() == QVariant::List)
            rows = root.value(QStringLiteral("data")).toList();
    }

    QVariantList out;

    for (const QVariant &rowVar : rows) {
        const QVariantMap row = rowVar.toMap();

        QVariantMap item;

        QVariant instrumentId = row.value(QStringLiteral("instrumentID"));
        if (!instrumentId.isValid() || instrumentId.toString().isEmpty())
            instrumentId = row.value(QStringLiteral("instrumentId"));
        if (!instrumentId.isValid() || instrumentId.toString().isEmpty())
            instrumentId = row.value(QStringLiteral("internalInstrumentId"));
        if (!instrumentId.isValid() || instrumentId.toString().isEmpty())
            instrumentId = row.value(QStringLiteral("id"));

        if (!instrumentId.isValid() || instrumentId.toString().isEmpty())
            continue;

        QString symbol = row.value(QStringLiteral("symbolFull")).toString();
        if (symbol.isEmpty())
            symbol = row.value(QStringLiteral("symbol")).toString();
        if (symbol.isEmpty())
            symbol = row.value(QStringLiteral("internalSymbolFull")).toString();
        if (symbol.isEmpty())
            symbol = row.value(QStringLiteral("ticker")).toString();

        QString displayName = row.value(QStringLiteral("instrumentDisplayName")).toString();
        if (displayName.isEmpty())
            displayName = row.value(QStringLiteral("displayName")).toString();
        if (displayName.isEmpty())
            displayName = row.value(QStringLiteral("internalInstrumentDisplayName")).toString();
        if (displayName.isEmpty())
            displayName = row.value(QStringLiteral("name")).toString();

        QVariant typeId = row.value(QStringLiteral("instrumentTypeID"));
        if (!typeId.isValid() || typeId.toString().isEmpty())
            typeId = row.value(QStringLiteral("instrumentTypeId"));
        if (!typeId.isValid() || typeId.toString().isEmpty())
            typeId = row.value(QStringLiteral("internalAssetClassId"));

        item.insert(QStringLiteral("instrumentId"), instrumentId);
        item.insert(QStringLiteral("symbol"), symbol);
        item.insert(QStringLiteral("displayName"), displayName);
        item.insert(QStringLiteral("instrumentTypeId"), typeId);
        item.insert(QStringLiteral("exchangeId"), row.value(QStringLiteral("exchangeID")));
        item.insert(QStringLiteral("priceSource"), row.value(QStringLiteral("priceSource")));
        item.insert(QStringLiteral("isBuyEnabled"), row.value(QStringLiteral("isBuyEnabled")));
        item.insert(QStringLiteral("isCurrentlyTradable"), row.value(QStringLiteral("isCurrentlyTradable")));
        item.insert(QStringLiteral("isExchangeOpen"), row.value(QStringLiteral("isExchangeOpen")));
        item.insert(QStringLiteral("tradingDisabled"), row.value(QStringLiteral("tradingDisabled")));

        QString logo = row.value(QStringLiteral("logo50x50")).toString();
        if (logo.isEmpty())
            logo = row.value(QStringLiteral("logo35x35")).toString();
        if (logo.isEmpty())
            logo = row.value(QStringLiteral("logo150x150")).toString();

        item.insert(QStringLiteral("logoUrl"), logo);
        item.insert(QStringLiteral("raw"), row);

        out << item;
    }

    return out;
}

void EtoroMarketService::searchInstruments(const QString &queryText,
                                           const QString &apiKey,
                                           const QString &userKey)
{
    const QString trimmed = queryText.trimmed();

    if (trimmed.isEmpty()) {
        emit instrumentSearchReady(QVariantList());
        return;
    }

    auto runSearch = [this, apiKey, userKey](const QString &fieldName,
                                             const QString &fieldValue,
                                             bool retryNameSearch,
                                             const QString &originalText) {
        QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                    QStringLiteral("/market-data/search"), apiKey, userKey);

        QUrl url = req.url();
        QUrlQuery query(url);
        query.addQueryItem(fieldName, fieldValue);
        url.setQuery(query);
        req.setUrl(url);

        QNetworkReply *reply = m_nam->get(req);

        connect(reply, &QNetworkReply::finished, this, [this, reply, retryNameSearch, originalText, apiKey, userKey]() {
            const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const QByteArray body = reply->readAll();
            const QNetworkReply::NetworkError netError = reply->error();
            reply->deleteLater();

            if (AppLog::debugEnabled()) {
                qWarning() << "ETORO SEARCH STATUS:" << httpStatus;
                qWarning() << "ETORO SEARCH BODY:" << body;
            }

            if (netError != QNetworkReply::NoError) {
                emit requestFailed(reply->errorString(), httpStatus, body);
                return;
            }

            QJsonParseError pe{};
            const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
            if (pe.error != QJsonParseError::NoError) {
                emit requestFailed(QStringLiteral("Invalid search JSON response"), httpStatus, body);
                return;
            }

            const QVariantList out = parseSearchResults(doc);

            if (out.isEmpty() && retryNameSearch) {
                searchInstrumentsByName(originalText, apiKey, userKey);
                return;
            }

            emit instrumentSearchReady(out);
        });
    };

    runSearch(QStringLiteral("internalSymbolFull"),
              trimmed.toUpper(),
              true,
              trimmed);
}

void EtoroMarketService::searchInstrumentsByName(const QString &queryText,
                                                 const QString &apiKey,
                                                 const QString &userKey)
{
    const QString trimmed = queryText.trimmed();

    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/market-data/search"), apiKey, userKey);

    QUrl url = req.url();
    QUrlQuery query(url);
    query.addQueryItem(QStringLiteral("internalInstrumentDisplayName"), trimmed);
    url.setQuery(query);
    req.setUrl(url);

    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();

        if (AppLog::debugEnabled()) {
            qWarning() << "ETORO NAME SEARCH STATUS:" << httpStatus;
            qWarning() << "ETORO NAME SEARCH BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
        if (pe.error != QJsonParseError::NoError) {
            emit requestFailed(QStringLiteral("Invalid name search JSON response"), httpStatus, body);
            return;
        }

        emit instrumentSearchReady(parseSearchResults(doc));
    });
}
