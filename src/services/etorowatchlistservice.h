#ifndef ETOROWATCHLISTSERVICE_H
#define ETOROWATCHLISTSERVICE_H

#include <QObject>
#include <QVariantList>
#include <QNetworkAccessManager>

class EtoroWatchlistService : public QObject
{
    Q_OBJECT
public:
    explicit EtoroWatchlistService(QNetworkAccessManager *nam, QObject *parent = nullptr);

    void fetchWatchlists(const QString &apiKey, const QString &userKey);
    void fetchWatchlist(const QString &watchlistId, const QString &apiKey, const QString &userKey);

signals:
    void watchlistsReady(const QVariantList &watchlists);
    void watchlistItemsReady(const QString &watchlistId, const QString &watchlistName, const QVariantList &items);
    void requestFailed(const QString &errorString, int httpStatus, const QByteArray &body);

private:
    QVariantList parseWatchlistsRoot(const QVariantMap &root) const;
    QVariantList parseSingleWatchlistItems(const QVariantMap &root) const;
    static QString firstNonEmpty(const QVariantMap &map, const QStringList &keys);

private:
    QNetworkAccessManager *m_nam = nullptr;
};

#endif // ETOROWATCHLISTSERVICE_H
