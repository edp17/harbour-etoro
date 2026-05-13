#ifndef ETOROPORTFOLIOSERVICE_H
#define ETOROPORTFOLIOSERVICE_H

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QNetworkAccessManager>

class EtoroPortfolioService : public QObject
{
    Q_OBJECT
public:
    explicit EtoroPortfolioService(QNetworkAccessManager *nam, QObject *parent = nullptr);

    void fetchPortfolioSummary(const QString &apiKey, const QString &userKey);

signals:
    void portfolioReady(const QVariantMap &summary, const QVariantList &positions);
    void requestFailed(const QString &errorString, int httpStatus, const QByteArray &body);

private:
    QVariantMap parseSummary(const QVariantMap &root) const;
    QVariantList parsePositions(const QVariantMap &root) const;
    static double toDouble(const QVariant &v);
    static QString firstNonEmpty(const QVariantMap &map, const QStringList &keys);

private:
    QNetworkAccessManager *m_nam;
};

#endif // ETOROPORTFOLIOSERVICE_H
