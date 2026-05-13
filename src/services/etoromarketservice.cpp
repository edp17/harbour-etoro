#include "etoromarketservice.h"
#include "../networkutils.h"

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

        qWarning() << "ETORO METADATA STATUS:" << httpStatus;
        qWarning() << "ETORO METADATA BODY:" << body;

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

        qWarning() << "ETORO RATES STATUS:" << httpStatus;
        qWarning() << "ETORO RATES BODY:" << body;

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
