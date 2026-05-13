#ifndef ETOROCLIENT_H
#define ETOROCLIENT_H

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QNetworkAccessManager>
#include <QSettings>
#include <QTimer>

#include "tokenstore.h"
#include "services/etoroportfolioservice.h"
#include "services/etoromarketservice.h"
#include "services/etorotradingservice.h"
#include "services/etorowatchlistservice.h"
#include "services/etorohistoryservice.h"

class EtoroClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasCredentials READ hasCredentials NOTIFY credentialsChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool locked READ locked NOTIFY lockedChanged)
    Q_PROPERTY(bool online READ online NOTIFY onlineChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QString pinSettingsError READ pinSettingsError NOTIFY pinSettingsErrorChanged)
    Q_PROPERTY(QVariantMap portfolioSummary READ portfolioSummary NOTIFY portfolioSummaryChanged)
    Q_PROPERTY(QVariantList openPositions READ openPositions NOTIFY openPositionsChanged)
    Q_PROPERTY(QVariantList topPositions READ topPositions NOTIFY openPositionsChanged)
    Q_PROPERTY(QVariantMap positionsQuotes READ positionsQuotes NOTIFY positionsQuotesChanged)
    Q_PROPERTY(bool positionsQuotesLoading READ positionsQuotesLoading NOTIFY positionsQuotesChanged)
    Q_PROPERTY(QVariantList watchlists READ watchlists NOTIFY watchlistsChanged)
    Q_PROPERTY(QVariantList currentWatchlistItems READ currentWatchlistItems NOTIFY currentWatchlistItemsChanged)
    Q_PROPERTY(QString currentWatchlistName READ currentWatchlistName NOTIFY currentWatchlistItemsChanged)
    Q_PROPERTY(bool watchlistItemsLoading READ watchlistItemsLoading NOTIFY currentWatchlistItemsChanged)
    Q_PROPERTY(QVariantMap currentWatchlistQuotes READ currentWatchlistQuotes NOTIFY currentWatchlistQuotesChanged)
    Q_PROPERTY(bool currentWatchlistQuotesLoading READ currentWatchlistQuotesLoading NOTIFY currentWatchlistQuotesChanged)
    Q_PROPERTY(QVariantList tradeHistory READ tradeHistory NOTIFY tradeHistoryChanged)
    Q_PROPERTY(QString historyMinDate READ historyMinDate NOTIFY tradeHistoryChanged)
    Q_PROPERTY(int historyCurrentPage READ historyCurrentPage NOTIFY tradeHistoryChanged)
    Q_PROPERTY(int historyPageSize READ historyPageSize NOTIFY tradeHistoryChanged)
    Q_PROPERTY(bool historyHasMore READ historyHasMore NOTIFY tradeHistoryChanged)
    Q_PROPERTY(bool historyLoading READ historyLoading NOTIFY tradeHistoryChanged)
    Q_PROPERTY(QVariantMap selectedInstrumentQuote READ selectedInstrumentQuote NOTIFY selectedInstrumentQuoteChanged)
    Q_PROPERTY(bool selectedInstrumentQuoteLoading READ selectedInstrumentQuoteLoading NOTIFY selectedInstrumentQuoteChanged)
    Q_PROPERTY(bool pinEnabled READ pinEnabled NOTIFY pinChanged)

    Q_PROPERTY(bool lockOnBackground READ lockOnBackground WRITE setLockOnBackground NOTIFY lockSettingsChanged)
    Q_PROPERTY(int autoLockMinutes READ autoLockMinutes WRITE setAutoLockMinutes NOTIFY lockSettingsChanged)

    Q_PROPERTY(bool portfolioShowFilter READ portfolioShowFilter WRITE setPortfolioShowFilter NOTIFY portfolioUiChanged)
    Q_PROPERTY(bool portfolioShowSort READ portfolioShowSort WRITE setPortfolioShowSort NOTIFY portfolioUiChanged)
    Q_PROPERTY(QString portfolioSortMode READ portfolioSortMode WRITE setPortfolioSortMode NOTIFY portfolioUiChanged)
    Q_PROPERTY(QString portfolioViewMode READ portfolioViewMode WRITE setPortfolioViewMode NOTIFY portfolioUiChanged)
    Q_PROPERTY(QString portfolioFilterText READ portfolioFilterText WRITE setPortfolioFilterText NOTIFY portfolioUiChanged)

    Q_PROPERTY(QVariantList groupedOpenPositions READ groupedOpenPositions NOTIFY groupedOpenPositionsChanged)

    Q_PROPERTY(QString historyFilterText READ historyFilterText WRITE setHistoryFilterText NOTIFY historyUiChanged)
    Q_PROPERTY(QString statisticsSortMode READ statisticsSortMode WRITE setStatisticsSortMode NOTIFY statisticsUiChanged)
    Q_PROPERTY(QString watchlistFilterText READ watchlistFilterText WRITE setWatchlistFilterText NOTIFY watchlistUiChanged)

    Q_PROPERTY(int quoteRefreshIntervalSeconds READ quoteRefreshIntervalSeconds WRITE setQuoteRefreshIntervalSeconds NOTIFY quoteRefreshSettingsChanged)

    Q_PROPERTY(QString quoteRateLimitMessage READ quoteRateLimitMessage NOTIFY quoteRefreshSettingsChanged)
    Q_PROPERTY(bool quoteRefreshCoolingDown READ quoteRefreshCoolingDown NOTIFY quoteRefreshSettingsChanged)

    Q_PROPERTY(QString portfolioColumn1 READ portfolioColumn1 WRITE setPortfolioColumn1 NOTIFY portfolioColumnsChanged)
    Q_PROPERTY(QString portfolioColumn2 READ portfolioColumn2 WRITE setPortfolioColumn2 NOTIFY portfolioColumnsChanged)
    Q_PROPERTY(QString portfolioColumn3 READ portfolioColumn3 WRITE setPortfolioColumn3 NOTIFY portfolioColumnsChanged)

    Q_PROPERTY(bool tradingEnabled READ tradingEnabled WRITE setTradingEnabled NOTIFY tradingModeChanged)

    Q_PROPERTY(QString apiKey READ apiKey NOTIFY credentialsChanged)
    Q_PROPERTY(QString userKey READ userKey NOTIFY credentialsChanged)

public:
    explicit EtoroClient(QObject *parent = nullptr);

    bool hasCredentials() const;
    bool busy() const;
    bool locked() const;
    bool online() const;
    QString lastError() const;
    QString pinSettingsError() const;
    QVariantMap portfolioSummary() const;
    QVariantList openPositions() const;
    QVariantList topPositions() const;
    QVariantMap positionsQuotes() const;
    bool positionsQuotesLoading() const;
    QVariantList watchlists() const;
    QVariantList currentWatchlistItems() const;
    QString currentWatchlistName() const;
    bool watchlistItemsLoading() const;
    QVariantMap currentWatchlistQuotes() const;
    bool currentWatchlistQuotesLoading() const;
    QVariantList tradeHistory() const;
    QString historyMinDate() const;
    int historyCurrentPage() const;
    int historyPageSize() const;
    bool historyHasMore() const;
    bool historyLoading() const;
    QVariantMap selectedInstrumentQuote() const;
    bool selectedInstrumentQuoteLoading() const;
    bool pinEnabled() const;

    bool lockOnBackground() const;
    int autoLockMinutes() const;

    bool portfolioShowFilter() const;
    bool portfolioShowSort() const;
    QString portfolioSortMode() const;
    QString portfolioViewMode() const;
    QString portfolioFilterText() const;

    QVariantList groupedOpenPositions() const;

    QString historyFilterText() const;
    QString statisticsSortMode() const;
    QString watchlistFilterText() const;

    QString apiKey() const;
    QString userKey() const;

    bool tradingEnabled() const;
    Q_INVOKABLE void setTradingEnabled(bool enabled);

    int quoteRefreshIntervalSeconds() const;
    Q_INVOKABLE void setQuoteRefreshIntervalSeconds(int seconds);

    Q_INVOKABLE void setPortfolioShowFilter(bool value);
    Q_INVOKABLE void setPortfolioShowSort(bool value);
    Q_INVOKABLE void setPortfolioSortMode(const QString &value);
    Q_INVOKABLE void setPortfolioViewMode(const QString &value);
    Q_INVOKABLE void setPortfolioFilterText(const QString &value);

    Q_INVOKABLE void refreshPortfolio();
    Q_INVOKABLE void refreshPositionsQuotes();
    Q_INVOKABLE QVariantMap quoteForPositionInstrument(const QVariant &instrumentId) const;
    Q_INVOKABLE void refreshWatchlists();
    Q_INVOKABLE void loadWatchlist(const QString &watchlistId, const QString &watchlistName = QString());
    Q_INVOKABLE void refreshCurrentWatchlistQuotes();
    Q_INVOKABLE QVariantMap quoteForWatchlistInstrument(const QVariant &instrumentId) const;
    Q_INVOKABLE void refreshTradeHistory();
    Q_INVOKABLE void refreshTradeHistoryFrom(const QString &minDateIso);
    Q_INVOKABLE void loadMoreTradeHistory();
    Q_INVOKABLE void loadInstrumentQuote(const QVariantMap &instrumentData);
    Q_INVOKABLE void clearSelectedInstrumentQuote();
    Q_INVOKABLE void saveCredentials(const QString &apiKey, const QString &userKey);
    Q_INVOKABLE void clearCredentials();
    Q_INVOKABLE QString apiKeyPreview() const;
    Q_INVOKABLE QString userKeyPreview() const;

    Q_INVOKABLE bool setPin(const QString &pin);
    Q_INVOKABLE bool changePin(const QString &currentPin, const QString &newPin);
    Q_INVOKABLE bool removePin(const QString &currentPin);
    Q_INVOKABLE bool verifyPin(const QString &pin) const;
    Q_INVOKABLE bool unlockWithPin(const QString &pin);
    Q_INVOKABLE void lockNow();

    Q_INVOKABLE void setLockOnBackground(bool value);
    Q_INVOKABLE void setAutoLockMinutes(int minutes);
    Q_INVOKABLE void registerUserActivity();
    Q_INVOKABLE void maybeLockForBackground();
    Q_INVOKABLE void clearPinSettingsError();

    Q_INVOKABLE void setHistoryFilterText(const QString &value);
    Q_INVOKABLE void setStatisticsSortMode(const QString &value);
    Q_INVOKABLE void setWatchlistFilterText(const QString &value);

    Q_INVOKABLE QString quoteRateLimitMessage() const;
    Q_INVOKABLE bool quoteRefreshCoolingDown() const;
    Q_INVOKABLE int effectiveQuoteRefreshIntervalSeconds(const QString &pageKind) const;

    Q_INVOKABLE QString portfolioColumn1() const;
    Q_INVOKABLE QString portfolioColumn2() const;
    Q_INVOKABLE QString portfolioColumn3() const;
    Q_INVOKABLE void setPortfolioColumn1(const QString &value);
    Q_INVOKABLE void setPortfolioColumn2(const QString &value);
    Q_INVOKABLE void setPortfolioColumn3(const QString &value);

signals:
    void credentialsChanged();
    void busyChanged();
    void lockedChanged();
    void onlineChanged();
    void lastErrorChanged();
    void pinSettingsErrorChanged();
    void portfolioSummaryChanged();
    void openPositionsChanged();
    void positionsQuotesChanged();
    void watchlistsChanged();
    void currentWatchlistItemsChanged();
    void currentWatchlistQuotesChanged();
    void tradeHistoryChanged();
    void selectedInstrumentQuoteChanged();
    void pinChanged();
    void lockSettingsChanged();
    void portfolioUiChanged();
    void groupedOpenPositionsChanged();
    void historyUiChanged();
    void statisticsUiChanged();
    void watchlistUiChanged();
    void quoteRefreshSettingsChanged();
    void portfolioColumnsChanged();
    void tradingModeChanged();

private:
    enum MetadataTarget {
        MetadataNone,
        MetadataPositions,
        MetadataWatchlistItems,
        MetadataTradeHistory
    };

    enum RatesTarget {
        RatesNone,
        RatesSelectedInstrument,
        RatesWatchlistItems,
        RatesPositions
    };

    void setBusy(bool value);
    void setLocked(bool value);
    void setOnline(bool value);
    void setLastError(const QString &value);
    void setPinSettingsError(const QString &value);

    void enrichOpenPositions(const QVariantMap &metadataById);
    void enrichPendingWatchlistItems(const QVariantMap &metadataById);
    void enrichPendingTradeHistory(const QVariantMap &metadataById);
    QList<int> currentInstrumentIds() const;
    QList<int> pendingWatchlistInstrumentIds() const;
    QList<int> currentWatchlistInstrumentIds() const;
    QList<int> pendingTradeHistoryInstrumentIds() const;
    static bool positionLessThan(const QVariantMap &a, const QVariantMap &b);
    static bool tradeHistoryNewerThan(const QVariantMap &a, const QVariantMap &b);

    void resetInactivityTimer();
    void stopInactivityTimer();

    void rebuildGroupedOpenPositions();
    static QString groupingKeyForPosition(const QVariantMap &position);

    void reloadCachedCredentials();
    void clearCachedCredentials();

private:
    TokenStore m_tokenStore;
    QSettings m_settings;
    QNetworkAccessManager m_nam;
    EtoroPortfolioService m_portfolioService;
    EtoroMarketService m_marketService;
    EtoroTradingService m_tradingService;
    EtoroWatchlistService m_watchlistService;
    EtoroHistoryService m_historyService;
    QTimer m_inactivityTimer;

    bool m_busy = false;
    bool m_locked = false;
    bool m_online = true;
    QString m_lastError;
    QString m_pinSettingsError;
    QVariantMap m_portfolioSummary;
    QVariantList m_openPositions;
    QVariantMap m_positionsQuotes;
    bool m_positionsQuotesLoading = false;
    QVariantList m_watchlists;
    QVariantList m_currentWatchlistItems;
    QVariantList m_pendingWatchlistItems;
    QString m_currentWatchlistName;
    bool m_watchlistItemsLoading = false;
    QVariantMap m_currentWatchlistQuotes;
    bool m_currentWatchlistQuotesLoading = false;
    QVariantList m_tradeHistory;
    QVariantList m_pendingTradeHistory;
    QString m_historyMinDate;
    int m_historyCurrentPage = 0;
    int m_historyPageSize = 100;
    bool m_historyHasMore = false;
    bool m_historyLoading = false;
    QVariantMap m_selectedInstrumentQuote;
    bool m_selectedInstrumentQuoteLoading = false;
    MetadataTarget m_metadataTarget = MetadataNone;
    RatesTarget m_ratesTarget = RatesNone;

    QVariantList m_groupedOpenPositions;

    QDateTime m_quoteRateLimitUntil;
    QString m_quoteRateLimitMessage;

    QString m_cachedApiKey;
    QString m_cachedUserKey;
};

#endif // ETOROCLIENT_H