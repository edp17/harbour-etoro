#ifndef ETOROHISTORYSERVICE_H
#define ETOROHISTORYSERVICE_H

#include <QObject>
#include <QVariantList>
#include <QNetworkAccessManager>

class EtoroHistoryService : public QObject
{
    Q_OBJECT
public:
    explicit EtoroHistoryService(QNetworkAccessManager *nam, QObject *parent = nullptr);

    void fetchTradeHistory(const QString &apiKey,
                           const QString &userKey,
                           const QString &minDateIso,
                           int page = 1,
                           int pageSize = 100);

signals:
    void tradeHistoryReady(const QVariantList &trades,
                           int page,
                           int pageSize,
                           bool hasMore);
    void requestFailed(const QString &errorString, int httpStatus, const QByteArray &body);

private:
    QNetworkAccessManager *m_nam = nullptr;
};

#endif // ETOROHISTORYSERVICE_H