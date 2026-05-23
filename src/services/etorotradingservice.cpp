#include "etorotradingservice.h"
#include "../networkutils.h"
#include "../applog.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QDebug>

EtoroTradingService::EtoroTradingService(QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent)
    , m_nam(nam)
{
}

void EtoroTradingService::openMarketOrder(const QVariantMap &order,
                                          const QString &apiKey,
                                          const QString &userKey,
                                          const QString &accountMode,
                                          bool dryRun)
{
    const QVariantMap payload = buildMarketOrderPayload(order);
    if (AppLog::debugEnabled())
        qWarning() << "ETORO MARKET ORDER PAYLOAD:" << QJsonDocument::fromVariant(payload).toJson(QJsonDocument::Compact);

    if (dryRun) {
        if (AppLog::debugEnabled())
            qWarning() << "ETORO MARKET ORDER DRY-RUN: request not sent.";
        emit marketOrderPrepared(payload);
        return;
    }

    const bool byAmount = order.value(QStringLiteral("byAmount")).toBool();
    const QString method = byAmount ? QStringLiteral("by-amount") : QStringLiteral("by-units");

    const QString path = accountMode == QStringLiteral("demo")
            ? QStringLiteral("/trading/execution/demo/market-open-orders/%1").arg(method)
            : QStringLiteral("/trading/execution/market-open-orders/%1").arg(method);

    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(path, apiKey, userKey);

    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    const QByteArray body = QJsonDocument::fromVariant(payload).toJson(QJsonDocument::Compact);

    QNetworkReply *reply = m_nam->post(req, body);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO MARKET ORDER STATUS:" << httpStatus;
            qWarning() << "ETORO MARKET ORDER BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);

        if (pe.error != QJsonParseError::NoError) {
            emit requestFailed(QStringLiteral("Invalid market order JSON response"), httpStatus, body);
            return;
        }

        if (doc.isObject())
            emit marketOrderSubmitted(doc.object().toVariantMap());
        else
            emit marketOrderSubmitted(QVariantMap());
    });
}

void EtoroTradingService::closeMarketPosition(const QVariantMap &position,
                                              const QString &unitsToDeduct,
                                              const QString &apiKey,
                                              const QString &userKey,
                                              const QString &accountMode,
                                              bool dryRun)
{
    const QString positionId = position.value(QStringLiteral("positionId")).toString();

    QVariantMap payload;
    payload.insert(QStringLiteral("InstrumentId"), position.value(QStringLiteral("instrumentId")).toInt());
    const QString trimmedUnits = unitsToDeduct.trimmed();

    if (trimmedUnits.isEmpty())
        payload.insert(QStringLiteral("UnitsToDeduct"), QVariant());
    else
        payload.insert(QStringLiteral("UnitsToDeduct"), trimmedUnits.toDouble());
        if (AppLog::debugEnabled())
            qWarning() << "ETORO CLOSE POSITION PAYLOAD:"
                       << QJsonDocument::fromVariant(payload).toJson(QJsonDocument::Compact);

    if (dryRun) {
        if (AppLog::debugEnabled())
            qWarning() << "ETORO CLOSE POSITION DRY-RUN: request not sent.";
        emit closePositionPrepared(payload);
        return;
    }

    const QString path = accountMode == QStringLiteral("demo")
            ? QStringLiteral("/trading/execution/demo/market-close-orders/positions/%1").arg(positionId)
            : QStringLiteral("/trading/execution/market-close-orders/positions/%1").arg(positionId);

    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(path, apiKey, userKey);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    const QByteArray body = QJsonDocument::fromVariant(payload).toJson(QJsonDocument::Compact);
    QNetworkReply *reply = m_nam->post(req, body);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO CLOSE POSITION STATUS:" << httpStatus;
            qWarning() << "ETORO CLOSE POSITION BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
        if (pe.error != QJsonParseError::NoError) {
            emit requestFailed(QStringLiteral("Invalid close position JSON response"), httpStatus, body);
            return;
        }

        if (doc.isObject())
            emit closePositionSubmitted(doc.object().toVariantMap());
        else
            emit closePositionSubmitted(QVariantMap());
    });
}

void EtoroTradingService::updatePositionProtection(const QVariantMap &position,
                                                   const QVariantMap &protection,
                                                   const QString &apiKey,
                                                   const QString &userKey,
                                                   bool dryRun)
{
    const QString positionId = position.value(QStringLiteral("positionId")).toString();

    QVariantMap payload;

    const QString stopLoss = protection.value(QStringLiteral("stopLoss")).toString().trimmed();
    if (!stopLoss.isEmpty())
        payload.insert(QStringLiteral("StopLoss"), stopLoss.toDouble());

    const QString takeProfit = protection.value(QStringLiteral("takeProfit")).toString().trimmed();
    if (!takeProfit.isEmpty())
        payload.insert(QStringLiteral("TakeProfit"), takeProfit.toDouble());
        if (AppLog::debugEnabled())
            qWarning() << "ETORO UPDATE POSITION PROTECTION PAYLOAD:"
                       << QJsonDocument::fromVariant(payload).toJson(QJsonDocument::Compact);

    if (dryRun) {
        if (AppLog::debugEnabled())
            qWarning() << "ETORO UPDATE POSITION PROTECTION DRY-RUN: request not sent.";
        emit positionProtectionPrepared(payload);
        return;
    }

    const QString path = QStringLiteral("/trading/positions/%1").arg(positionId);

    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(path, apiKey, userKey);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    const QByteArray body = QJsonDocument::fromVariant(payload).toJson(QJsonDocument::Compact);
    QNetworkReply *reply = m_nam->put(req, body);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();
        if (AppLog::debugEnabled())
        {
            qWarning() << "ETORO UPDATE POSITION PROTECTION STATUS:" << httpStatus;
            qWarning() << "ETORO UPDATE POSITION PROTECTION BODY:" << body;
        }

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
        if (pe.error != QJsonParseError::NoError) {
            emit requestFailed(QStringLiteral("Invalid update position protection JSON response"), httpStatus, body);
            return;
        }

        if (doc.isObject())
            emit positionProtectionUpdated(doc.object().toVariantMap());
        else
            emit positionProtectionUpdated(QVariantMap());
    });
}

QVariantMap EtoroTradingService::buildMarketOrderPayload(const QVariantMap &order) const
{
    QVariantMap payload;

    payload.insert(QStringLiteral("InstrumentId"), order.value(QStringLiteral("instrumentId")).toInt());
    payload.insert(QStringLiteral("IsBuy"), true);
    payload.insert(QStringLiteral("Leverage"), order.value(QStringLiteral("leverage")).toInt());

    const bool byAmount = order.value(QStringLiteral("byAmount")).toBool();

    if (byAmount) {
        payload.insert(QStringLiteral("Amount"), toDouble(order.value(QStringLiteral("amount"))));
    } else {
        payload.insert(QStringLiteral("AmountInUnits"), toDouble(order.value(QStringLiteral("units"))));
    }

    const QString stopLoss = order.value(QStringLiteral("stopLoss")).toString().trimmed();
    if (!stopLoss.isEmpty())
        payload.insert(QStringLiteral("StopLossRate"), stopLoss.toDouble());

    const QString takeProfit = order.value(QStringLiteral("takeProfit")).toString().trimmed();
    if (!takeProfit.isEmpty())
        payload.insert(QStringLiteral("TakeProfitRate"), takeProfit.toDouble());

    return payload;
}

double EtoroTradingService::toDouble(const QVariant &v)
{
    bool ok = false;
    const double d = v.toDouble(&ok);
    return ok ? d : 0.0;
}
