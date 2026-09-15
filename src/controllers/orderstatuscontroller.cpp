#include "orderstatuscontroller.h"

#include "../networkutils.h"
#include "../applog.h"

#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QNetworkReply>
#include <QUrl>
#include <QUrlQuery>

OrderStatusController::OrderStatusController(QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent)
    , m_nam(nam)
{
    m_pollTimer.setSingleShot(true);
    m_pollTimer.setInterval(1800);
    connect(&m_pollTimer, &QTimer::timeout, this, &OrderStatusController::requestStatus);
}

QVariantMap OrderStatusController::orderStatus() const { return m_orderStatus; }
bool OrderStatusController::loading() const { return m_loading; }
QString OrderStatusController::errorMessage() const { return m_errorMessage; }
bool OrderStatusController::hasTrackedOrder() const { return !m_orderId.isEmpty() || !m_referenceId.isEmpty(); }

QVariant OrderStatusController::lookupValue(const QVariantMap &map, const QStringList &keys)
{
    for (const QString &key : keys) {
        const QVariant value = map.value(key);
        if (value.isValid() && !value.isNull() && !value.toString().isEmpty())
            return value;
    }

    const QVariantMap data = map.value(QStringLiteral("data")).toMap();
    for (const QString &key : keys) {
        const QVariant value = data.value(key);
        if (value.isValid() && !value.isNull() && !value.toString().isEmpty())
            return value;
    }

    return QVariant();
}

void OrderStatusController::trackSubmittedOrder(const QVariantMap &submission,
                                                 const QString &apiKey,
                                                 const QString &userKey,
                                                 bool demoMode)
{
    m_pollTimer.stop();
    m_orderStatus = submission;
    m_apiKey = apiKey;
    m_userKey = userKey;
    m_demoMode = demoMode;
    m_orderId = lookupValue(submission, { QStringLiteral("orderId"), QStringLiteral("OrderId"), QStringLiteral("orderID") }).toString();
    m_referenceId = lookupValue(submission, { QStringLiteral("referenceId"), QStringLiteral("ReferenceId"), QStringLiteral("_requestId") }).toString();
    m_errorMessage.clear();
    m_pollAttempts = 0;
    m_loading = false;
    emit changed();

    if (hasTrackedOrder())
        m_pollTimer.start(900);
}

void OrderStatusController::refresh()
{
    if (!m_loading && hasTrackedOrder())
        requestStatus();
}

void OrderStatusController::clear()
{
    m_pollTimer.stop();
    m_orderStatus.clear();
    m_orderId.clear();
    m_referenceId.clear();
    m_errorMessage.clear();
    m_loading = false;
    m_pollAttempts = 0;
    emit changed();
}

QString OrderStatusController::statusName(const QVariantMap &response)
{
    const QVariant statusValue = response.value(QStringLiteral("status"));
    if (statusValue.type() == QVariant::Map)
        return statusValue.toMap().value(QStringLiteral("name")).toString();
    return statusValue.toString();
}

bool OrderStatusController::isTerminalStatus(const QString &name)
{
    const QString value = name.trimmed().toLower();
    return value == QStringLiteral("filled")
            || value == QStringLiteral("rejected")
            || value == QStringLiteral("cancelled")
            || value == QStringLiteral("canceled")
            || value == QStringLiteral("failed")
            || value == QStringLiteral("expired");
}

void OrderStatusController::scheduleNextPoll()
{
    if (m_pollAttempts < 8)
        m_pollTimer.start();
}

void OrderStatusController::requestStatus()
{
    if (!hasTrackedOrder() || m_apiKey.isEmpty() || m_userKey.isEmpty())
        return;

    const QString path = m_demoMode
            ? QStringLiteral("/trading/info/demo/orders:lookup")
            : QStringLiteral("/trading/info/orders:lookup");

    QNetworkRequest request = NetworkUtils::buildAuthenticatedV2Request(path, m_apiKey, m_userKey);
    QUrl url = request.url();
    QUrlQuery query(url);
    if (!m_orderId.isEmpty())
        query.addQueryItem(QStringLiteral("orderId"), m_orderId);
    else
        query.addQueryItem(QStringLiteral("referenceId"), m_referenceId);
    url.setQuery(query);
    request.setUrl(url);

    m_loading = true;
    m_errorMessage.clear();
    ++m_pollAttempts;
    emit changed();

    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError networkError = reply->error();
        reply->deleteLater();

        m_loading = false;
        if (AppLog::debugEnabled()) {
            qWarning() << "ETORO ORDER STATUS:" << httpStatus;
            qWarning() << "ETORO ORDER STATUS BODY:" << body;
        }

        if (networkError != QNetworkReply::NoError) {
            m_errorMessage = tr("Could not load the latest order status.");
            emit changed();
            scheduleNextPoll();
            return;
        }

        QJsonParseError parseError{};
        const QJsonDocument document = QJsonDocument::fromJson(body, &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            m_errorMessage = tr("The order status response could not be read.");
            emit changed();
            scheduleNextPoll();
            return;
        }

        m_orderStatus = document.object().toVariantMap();
        m_errorMessage.clear();
        emit changed();

        const QString name = statusName(m_orderStatus);
        if (isTerminalStatus(name))
            emit terminalStatusReached(name);
        else
            scheduleNextPoll();
    });
}
