#ifndef ETOROMARKETSERVICE_H
#define ETOROMARKETSERVICE_H

#include <QObject>
#include <QVariantMap>
#include <QNetworkAccessManager>
#include <QList>

class EtoroMarketService : public QObject
{
    Q_OBJECT
public:
    explicit EtoroMarketService(QNetworkAccessManager *nam, QObject *parent = nullptr);

    void fetchInstrumentMetadata(const QList<int> &instrumentIds,
                                 const QString &apiKey,
                                 const QString &userKey);

    void fetchInstrumentRates(const QList<int> &instrumentIds,
                              const QString &apiKey,
                              const QString &userKey);

signals:
    void instrumentMetadataReady(const QVariantMap &metadataById);
    void instrumentRatesReady(const QVariantMap &ratesById);
    void requestFailed(const QString &errorString, int httpStatus, const QByteArray &body);

private:
    QNetworkAccessManager *m_nam;
};

#endif // ETOROMARKETSERVICE_H