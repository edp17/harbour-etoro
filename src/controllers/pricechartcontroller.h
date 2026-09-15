#ifndef PRICECHARTCONTROLLER_H
#define PRICECHARTCONTROLLER_H

#include <QObject>
#include <QVariantList>
#include <QNetworkAccessManager>

class PriceChartController : public QObject
{
    Q_OBJECT
public:
    explicit PriceChartController(QNetworkAccessManager *nam, QObject *parent = nullptr);

    QVariantList candles() const;
    bool loading() const;
    QString errorMessage() const;
    QString interval() const;
    int instrumentId() const;

    void load(int instrumentId,
              const QString &interval,
              int candleCount,
              const QString &apiKey,
              const QString &userKey);
    void clear();

signals:
    void changed();

private:
    QNetworkAccessManager *m_nam;
    QVariantList m_candles;
    QString m_errorMessage;
    QString m_interval;
    bool m_loading = false;
    int m_instrumentId = 0;
    quint64 m_requestSerial = 0;
};

#endif // PRICECHARTCONTROLLER_H
