#include "etorohistoryservice.h"
#include "../networkutils.h"

#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QDebug>

EtoroHistoryService::EtoroHistoryService(QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent)
    , m_nam(nam)
{
}

void EtoroHistoryService::fetchTradeHistory(const QString &apiKey,
                                            const QString &userKey,
                                            const QString &minDateIso,
                                            int page,
                                            int pageSize)
{
    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/trading/info/trade/history"),
                apiKey,
                userKey);

    QUrl url = req.url();
    QUrlQuery query(url);
    query.addQueryItem(QStringLiteral("minDate"), minDateIso);
    query.addQueryItem(QStringLiteral("page"), QString::number(page));
    query.addQueryItem(QStringLiteral("pageSize"), QString::number(pageSize));
    url.setQuery(query);
    req.setUrl(url);

    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply, page, pageSize]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();

        qWarning() << "ETORO HISTORY STATUS:" << httpStatus;
        qWarning() << "ETORO HISTORY BODY:" << body;

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
        if (pe.error != QJsonParseError::NoError) {
            emit requestFailed(QStringLiteral("Invalid trade history JSON response"), httpStatus, body);
            return;
        }

        QVariantList raw;

        if (doc.isArray()) {
            raw = doc.array().toVariantList();
        } else if (doc.isObject()) {
            const QVariantMap root = doc.object().toVariantMap();

            if (root.contains("history") && root.value("history").type() == QVariant::List)
                raw = root.value("history").toList();
            else if (root.contains("items") && root.value("items").type() == QVariant::List)
                raw = root.value("items").toList();
            else if (root.contains("trades") && root.value("trades").type() == QVariant::List)
                raw = root.value("trades").toList();
            else if (root.contains("data") && root.value("data").type() == QVariant::List)
                raw = root.value("data").toList();
        } else {
            emit requestFailed(QStringLiteral("Invalid trade history JSON response"), httpStatus, body);
            return;
        }

        QVariantList out;
        for (const QVariant &v : raw) {
            const QVariantMap in = v.toMap();
            QVariantMap t;

            t.insert("positionId", in.value("positionId"));
            t.insert("instrumentId", in.value("instrumentId"));
            t.insert("isBuy", in.value("isBuy"));
            t.insert("direction", in.value("isBuy").toBool() ? QStringLiteral("Buy")
                                                             : QStringLiteral("Sell"));
            t.insert("leverage", in.value("leverage"));
            t.insert("openRate", in.value("openRate"));
            t.insert("closeRate", in.value("closeRate"));
            t.insert("openTimestamp", in.value("openTimestamp"));
            t.insert("closeTimestamp", in.value("closeTimestamp"));
            t.insert("investment", in.value("investment"));
            t.insert("initialInvestment", in.value("initialInvestment"));
            t.insert("netProfit", in.value("netProfit"));
            t.insert("fees", in.value("fees"));
            t.insert("units", in.value("units"));

            out.append(t);
        }

        const bool hasMore = (out.size() >= pageSize);
        emit tradeHistoryReady(out, page, pageSize, hasMore);
    });
}
