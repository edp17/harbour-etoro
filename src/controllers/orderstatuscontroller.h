#ifndef ORDERSTATUSCONTROLLER_H
#define ORDERSTATUSCONTROLLER_H

#include <QObject>
#include <QVariantMap>
#include <QNetworkAccessManager>
#include <QTimer>
#include <QStringList>

class OrderStatusController : public QObject
{
    Q_OBJECT
public:
    explicit OrderStatusController(QNetworkAccessManager *nam, QObject *parent = nullptr);

    QVariantMap orderStatus() const;
    bool loading() const;
    QString errorMessage() const;
    bool hasTrackedOrder() const;

    void trackSubmittedOrder(const QVariantMap &submission,
                             const QString &apiKey,
                             const QString &userKey,
                             bool demoMode);
    void refresh();
    void clear();

signals:
    void changed();
    void terminalStatusReached(const QString &statusName);

private:
    void requestStatus();
    void scheduleNextPoll();
    static QVariant lookupValue(const QVariantMap &map, const QStringList &keys);
    static QString statusName(const QVariantMap &response);
    static bool isTerminalStatus(const QString &name);

    QNetworkAccessManager *m_nam;
    QTimer m_pollTimer;
    QVariantMap m_orderStatus;
    QString m_apiKey;
    QString m_userKey;
    QString m_orderId;
    QString m_referenceId;
    QString m_errorMessage;
    bool m_demoMode = false;
    bool m_loading = false;
    int m_pollAttempts = 0;
};

#endif // ORDERSTATUSCONTROLLER_H
