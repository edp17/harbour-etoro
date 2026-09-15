#include "pricechartcontroller.h"

#include "../networkutils.h"
#include "../applog.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QNetworkReply>
#include <QtGlobal>

PriceChartController::PriceChartController(QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent)
    , m_nam(nam)
{
}

QVariantList PriceChartController::candles() const { return m_candles; }
bool PriceChartController::loading() const { return m_loading; }
QString PriceChartController::errorMessage() const { return m_errorMessage; }
QString PriceChartController::interval() const { return m_interval; }
int PriceChartController::instrumentId() const { return m_instrumentId; }

void PriceChartController::load(int instrumentId,
                                const QString &interval,
                                int candleCount,
                                const QString &apiKey,
                                const QString &userKey)
{
    if (instrumentId <= 0 || apiKey.isEmpty() || userKey.isEmpty())
        return;

    const int safeCount = qBound(2, candleCount, 1000);
    const QString safeInterval = interval.isEmpty() ? QStringLiteral("OneDay") : interval;
    const QString path = QStringLiteral("/market-data/instruments/%1/history/candles/desc/%2/%3")
            .arg(instrumentId)
            .arg(safeInterval)
            .arg(safeCount);

    m_instrumentId = instrumentId;
    m_interval = safeInterval;
    m_candles.clear();
    m_errorMessage.clear();
    m_loading = true;
    const quint64 requestSerial = ++m_requestSerial;
    emit changed();

    QNetworkReply *reply = m_nam->get(NetworkUtils::buildAuthenticatedRequest(path, apiKey, userKey));
    connect(reply, &QNetworkReply::finished, this, [this, reply, requestSerial]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError networkError = reply->error();
        reply->deleteLater();

        if (requestSerial != m_requestSerial)
            return;

        m_loading = false;
        if (AppLog::debugEnabled()) {
            qWarning() << "ETORO CANDLES STATUS:" << httpStatus;
            qWarning() << "ETORO CANDLES BODY:" << body;
        }

        if (networkError != QNetworkReply::NoError) {
            m_errorMessage = tr("Could not load price history.");
            emit changed();
            return;
        }

        QJsonParseError parseError{};
        const QJsonDocument document = QJsonDocument::fromJson(body, &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            m_errorMessage = tr("The price history response could not be read.");
            emit changed();
            return;
        }

        const QJsonArray groups = document.object().value(QStringLiteral("candles")).toArray();
        if (!groups.isEmpty()) {
            QVariantList newestFirst = groups.first().toObject().value(QStringLiteral("candles")).toArray().toVariantList();
            for (int i = newestFirst.size() - 1; i >= 0; --i)
                m_candles.append(newestFirst.at(i));
        }

        if (m_candles.isEmpty())
            m_errorMessage = tr("No price history is available for this asset.");

        emit changed();
    });
}

void PriceChartController::clear()
{
    ++m_requestSerial;
    m_candles.clear();
    m_errorMessage.clear();
    m_interval.clear();
    m_instrumentId = 0;
    m_loading = false;
    emit changed();
}
