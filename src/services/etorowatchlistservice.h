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

    void addInstrumentToWatchlist(const QString &watchlistId,
                                  const QVariantMap &instrument,
                                  const QString &apiKey,
                                  const QString &userKey);

    void createWatchlist(const QString &name,
                         const QString &apiKey,
                         const QString &userKey);

    void removeInstrumentFromWatchlist(const QString &watchlistId,
                                       const QVariantMap &instrument,
                                       const QString &apiKey,
                                       const QString &userKey);

    void renameWatchlist(const QString &watchlistId,
                         const QString &name,
                         const QString &apiKey,
                         const QString &userKey);

    void deleteWatchlist(const QString &watchlistId,
                         const QString &apiKey,
                         const QString &userKey);

signals:
    void watchlistsReady(const QVariantList &watchlists);
    void watchlistItemsReady(const QString &watchlistId, const QString &watchlistName, const QVariantList &items);
    void requestFailed(const QString &errorString, int httpStatus, const QByteArray &body);
    void watchlistItemAdded(const QString &watchlistId, const QVariantMap &instrument);
    void watchlistCreated(const QString &watchlistId, const QString &name);
    void watchlistItemRemoved(const QString &watchlistId, const QVariantMap &instrument);
    void watchlistRenamed(const QString &watchlistId, const QString &name);
    void watchlistDeleted(const QString &watchlistId);

private:
    QVariantList parseWatchlistsRoot(const QVariantMap &root) const;
    QVariantList parseSingleWatchlistItems(const QVariantMap &root) const;
    static QString firstNonEmpty(const QVariantMap &map, const QStringList &keys);

private:
    QNetworkAccessManager *m_nam = nullptr;
};

#endif // ETOROWATCHLISTSERVICE_H
