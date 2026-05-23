#ifndef ETOROTRADINGSERVICE_H
#define ETOROTRADINGSERVICE_H

#include <QObject>
#include <QVariantMap>
#include <QNetworkAccessManager>

class EtoroTradingService : public QObject
{
    Q_OBJECT

public:
    explicit EtoroTradingService(QNetworkAccessManager *nam, QObject *parent = nullptr);

    void openMarketOrder(const QVariantMap &order,
                         const QString &apiKey,
                         const QString &userKey,
                         const QString &accountMode,
                         bool dryRun);

    void closeMarketPosition(const QVariantMap &position,
                             const QString &unitsToDeduct,
                             const QString &apiKey,
                             const QString &userKey,
                             const QString &accountMode,
                             bool dryRun);

    void updatePositionProtection(const QVariantMap &position,
                                  const QVariantMap &protection,
                                  const QString &apiKey,
                                  const QString &userKey,
                                  bool dryRun);

signals:
    void marketOrderPrepared(const QVariantMap &payload);
    void marketOrderSubmitted(const QVariantMap &response);
    void requestFailed(const QString &errorString, int httpStatus, const QByteArray &body);
    void closePositionPrepared(const QVariantMap &payload);
    void closePositionSubmitted(const QVariantMap &response);
    void positionProtectionPrepared(const QVariantMap &payload);
    void positionProtectionUpdated(const QVariantMap &response);

private:
    QVariantMap buildMarketOrderPayload(const QVariantMap &order) const;
    static double toDouble(const QVariant &v);

    QNetworkAccessManager *m_nam;
};

#endif // ETOROTRADINGSERVICE_H
