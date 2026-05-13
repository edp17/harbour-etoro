#include "etoroportfolioservice.h"
#include "../networkutils.h"

#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

EtoroPortfolioService::EtoroPortfolioService(QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent)
    , m_nam(nam)
{
}

void EtoroPortfolioService::fetchPortfolioSummary(const QString &apiKey, const QString &userKey)
{
    QNetworkRequest req = NetworkUtils::buildAuthenticatedRequest(
                QStringLiteral("/trading/info/real/pnl"),
                apiKey,
                userKey);

    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QNetworkReply::NetworkError netError = reply->error();
        reply->deleteLater();

        qWarning() << "ETORO HTTP STATUS:" << httpStatus;
        qWarning() << "ETORO RAW BODY:" << body;

        if (netError != QNetworkReply::NoError) {
            emit requestFailed(reply->errorString(), httpStatus, body);
            return;
        }

        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
        if (pe.error != QJsonParseError::NoError || !doc.isObject()) {
            emit requestFailed(QStringLiteral("Invalid JSON response"), httpStatus, body);
            return;
        }

        const QVariantMap root = doc.object().toVariantMap();
        qWarning() << "ETORO ROOT KEYS:" << root.keys();

        const QVariantMap summary = parseSummary(root);
        const QVariantList positions = parsePositions(root);

        qWarning() << "ETORO PARSED SUMMARY:" << summary;
        qWarning() << "ETORO PARSED POSITIONS COUNT:" << positions.count();

        emit portfolioReady(summary, positions);
    });
}

QVariantMap EtoroPortfolioService::parseSummary(const QVariantMap &root) const
{
    QVariantMap out;

    const QVariantMap portfolio = root.value("clientPortfolio").toMap();

    const QVariantList positionsList = portfolio.value("positions").toList();
    const QVariantList ordersList = portfolio.value("orders").toList();
    const QVariantList mirrorsList = portfolio.value("mirrors").toList();

    double invested = 0.0;
    double equity = 0.0;

    for (const QVariant &item : positionsList) {
        const QVariantMap pos = item.toMap();

        const double amount = toDouble(pos.value("amount"));
        invested += amount;

        const QVariantMap pnl = pos.value("unrealizedPnL").toMap();
        const double exposure = toDouble(pnl.value("exposureInAccountCurrency"));
        equity += exposure;
    }

    const double totalNetProfit = toDouble(portfolio.value("unrealizedPnL"));
    const double credit = toDouble(portfolio.value("credit"));

    out.insert("equity", equity + credit);
    out.insert("portfolioValue", equity);
    out.insert("totalNetProfit", totalNetProfit);
    out.insert("credit", credit);
    out.insert("availableCash", 0.0);
    out.insert("invested", invested);
    out.insert("openPositionsCount", positionsList.size());
    out.insert("ordersCount", ordersList.size());
    out.insert("mirrorsCount", mirrorsList.size());

    return out;
}

QVariantList EtoroPortfolioService::parsePositions(const QVariantMap &root) const
{
    const QVariantMap portfolio = root.value("clientPortfolio").toMap();
    const QVariantList raw = portfolio.value("positions").toList();

    QVariantList out;
    for (const QVariant &item : raw) {
        const QVariantMap in = item.toMap();
        const QVariantMap pnl = in.value("unrealizedPnL").toMap();

        QVariantMap p;
        p.insert("instrumentId", in.value("instrumentID"));
        p.insert("positionId", in.value("positionID"));
        p.insert("displayName", QString("Instrument %1").arg(in.value("instrumentID").toString()));
        p.insert("symbol", QString("#%1").arg(in.value("instrumentID").toString()));
        p.insert("invested", toDouble(in.value("amount")));
        p.insert("netProfit", toDouble(pnl.value("pnL")));
        p.insert("currentRate", toDouble(pnl.value("closeRate")));
        p.insert("direction", in.value("isBuy").toBool() ? QStringLiteral("Buy")
                                                         : QStringLiteral("Sell"));
        p.insert("units", toDouble(in.value("units")));
        p.insert("openRate", toDouble(in.value("openRate")));
        p.insert("openDateTime", in.value("openDateTime").toString());
        p.insert("leverage", toDouble(in.value("leverage")));
        p.insert("exposureInAccountCurrency", toDouble(pnl.value("exposureInAccountCurrency")));

        p.insert("isBuy", in.value("isBuy").toBool());
        p.insert("takeProfitRate", toDouble(in.value("takeProfitRate")));
        p.insert("stopLossRate", toDouble(in.value("stopLossRate")));
        p.insert("isNoTakeProfit", in.value("isNoTakeProfit").toBool());
        p.insert("isNoStopLoss", in.value("isNoStopLoss").toBool());

        out.append(p);
    }

    return out;
}

double EtoroPortfolioService::toDouble(const QVariant &v)
{
    bool ok = false;
    const double d = v.toDouble(&ok);
    return ok ? d : 0.0;
}

QString EtoroPortfolioService::firstNonEmpty(const QVariantMap &map, const QStringList &keys)
{
    for (const QString &k : keys) {
        const QString value = map.value(k).toString().trimmed();
        if (!value.isEmpty())
            return value;
    }
    return QString();
}
