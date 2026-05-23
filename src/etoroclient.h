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
    Q_PROPERTY(QVariantList topGroupedPositions READ topGroupedPositions NOTIFY groupedOpenPositionsChanged)

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
    Q_PROPERTY(bool liveOrderSubmissionEnabled READ liveOrderSubmissionEnabled WRITE setLiveOrderSubmissionEnabled NOTIFY tradingModeChanged)

    Q_PROPERTY(QString apiKey READ apiKey NOTIFY credentialsChanged)
    Q_PROPERTY(QString userKey READ userKey NOTIFY credentialsChanged)

    Q_PROPERTY(QString realUserKey READ realUserKey NOTIFY credentialsChanged)
    Q_PROPERTY(QString demoUserKey READ demoUserKey NOTIFY credentialsChanged)
    Q_PROPERTY(bool hasRealCredentials READ hasRealCredentials NOTIFY credentialsChanged)
    Q_PROPERTY(bool hasDemoCredentials READ hasDemoCredentials NOTIFY credentialsChanged)

    Q_PROPERTY(bool demoMode READ demoMode WRITE setDemoMode NOTIFY accountModeChanged)
    Q_PROPERTY(QString accountModeLabel READ accountModeLabel NOTIFY accountModeChanged)

    Q_PROPERTY(QString realUserKey READ realUserKey NOTIFY credentialsChanged)
    Q_PROPERTY(QString demoUserKey READ demoUserKey NOTIFY credentialsChanged)
    Q_PROPERTY(bool hasRealCredentials READ hasRealCredentials NOTIFY credentialsChanged)
    Q_PROPERTY(bool hasDemoCredentials READ hasDemoCredentials NOTIFY credentialsChanged)

    Q_PROPERTY(QVariantList discoverResults READ discoverResults NOTIFY discoverResultsChanged)
    Q_PROPERTY(bool discoverLoading READ discoverLoading NOTIFY discoverResultsChanged)

    Q_PROPERTY(QVariantMap discoverQuotes READ discoverQuotes NOTIFY discoverQuotesChanged)
    Q_PROPERTY(bool discoverQuotesLoading READ discoverQuotesLoading NOTIFY discoverQuotesChanged)

    Q_PROPERTY(QString discoverSearchText READ discoverSearchText WRITE setDiscoverSearchText NOTIFY discoverSearchTextChanged)
    Q_PROPERTY(bool debugLoggingEnabled READ debugLoggingEnabled WRITE setDebugLoggingEnabled NOTIFY debugLoggingChanged)
    Q_PROPERTY(QVariantList instrumentWatchlistMatches READ instrumentWatchlistMatches NOTIFY instrumentWatchlistMatchesChanged)
    Q_PROPERTY(bool instrumentWatchlistLookupActive READ instrumentWatchlistLookupActive NOTIFY instrumentWatchlistMatchesChanged)

    Q_PROPERTY(QString historyCustomFromDate READ historyCustomFromDate WRITE setHistoryCustomFromDate NOTIFY historyUiChanged)
    Q_PROPERTY(bool historyCustomRangeEnabled READ historyCustomRangeEnabled WRITE setHistoryCustomRangeEnabled NOTIFY historyUiChanged)
    Q_PROPERTY(QString historyCustomToDate READ historyCustomToDate WRITE setHistoryCustomToDate NOTIFY historyUiChanged)

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
    QVariantList topGroupedPositions() const;

    QString historyFilterText() const;
    QString statisticsSortMode() const;
    QString watchlistFilterText() const;

    QString apiKey() const;
    QString userKey() const;

    QString realUserKey() const;
    QString demoUserKey() const;

    bool hasRealCredentials() const;
    bool hasDemoCredentials() const;

    QVariantList discoverResults() const;
    bool discoverLoading() const;

    QVariantMap discoverQuotes() const;
    bool discoverQuotesLoading() const;

    QString discoverSearchText() const;
    void setDiscoverSearchText(const QString &text);

    bool tradingEnabled() const;
    Q_INVOKABLE void setTradingEnabled(bool enabled);

    bool liveOrderSubmissionEnabled() const;
    Q_INVOKABLE void setLiveOrderSubmissionEnabled(bool enabled);

    bool debugLoggingEnabled() const;
    Q_INVOKABLE void setDebugLoggingEnabled(bool enabled);

    bool demoMode() const;
    Q_INVOKABLE void setDemoMode(bool enabled);
    Q_INVOKABLE QString accountModePathSegment() const;

    bool instrumentWatchlistLookupActive() const;

    QVariantList instrumentWatchlistMatches() const;
    Q_INVOKABLE void findWatchlistsForInstrument(const QVariant &instrumentId);

    Q_INVOKABLE void saveApiKey(const QString &apiKey);
    Q_INVOKABLE void saveUserKeyForMode(bool demo, const QString &userKey);
    Q_INVOKABLE void clearUserKeyForMode(bool demo);
    Q_INVOKABLE QString accountModeLabel() const;

    int quoteRefreshIntervalSeconds() const;
    Q_INVOKABLE void setQuoteRefreshIntervalSeconds(int seconds);

    QString historyCustomFromDate() const;
    bool historyCustomRangeEnabled() const;
    QString historyCustomToDate() const;
    Q_INVOKABLE void setHistoryCustomToDate(const QString &value);

    Q_INVOKABLE void setHistoryCustomFromDate(const QString &value);
    Q_INVOKABLE void setHistoryCustomRangeEnabled(bool value);
    Q_INVOKABLE void applyHistoryCustomRange();
    Q_INVOKABLE void clearHistoryCustomRange();

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

    Q_INVOKABLE bool prepareMarketOrder(const QVariantMap &order);
    Q_INVOKABLE bool closePosition(const QVariantMap &position, const QString &unitsToDeduct = QString());
    Q_INVOKABLE void clearLastError();

    Q_INVOKABLE bool updatePositionProtection(const QVariantMap &position, const QVariantMap &protection);

    Q_INVOKABLE void searchDiscoverInstruments(const QString &query);
    Q_INVOKABLE void clearDiscoverResults();

    Q_INVOKABLE QVariantMap quoteForDiscoverInstrument(const QVariant &instrumentId) const;
    Q_INVOKABLE void refreshDiscoverQuotes();

    Q_INVOKABLE bool addInstrumentToWatchlist(const QString &watchlistId, const QVariantMap &instrument);
    Q_INVOKABLE bool createWatchlist(const QString &name);
    Q_INVOKABLE bool currentWatchlistContainsInstrument(const QVariant &instrumentId) const;
    Q_INVOKABLE bool removeInstrumentFromWatchlist(const QString &watchlistId, const QVariantMap &instrument);
    Q_INVOKABLE bool renameWatchlist(const QString &watchlistId, const QString &name);
    Q_INVOKABLE bool deleteWatchlist(const QString &watchlistId);
    Q_INVOKABLE QVariantMap currentWatchlistItemForInstrument(const QVariant &instrumentId) const;

    Q_INVOKABLE QVariantMap restrictionsForInstrument(const QVariant &instrumentId) const;

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
    void accountModeChanged();
    void positionCloseSubmitted();
    void discoverResultsChanged();
    void watchlistItemAdded();
    void watchlistCreated(const QString &watchlistId, const QString &name);
    void watchlistItemRemoved();
    void watchlistRenamed(const QString &watchlistId, const QString &name);
    void watchlistDeleted(const QString &watchlistId);
    void discoverQuotesChanged();
    void discoverSearchTextChanged();
    void debugLoggingChanged();
    void instrumentWatchlistMatchesChanged();

private:
    enum MetadataTarget {
        MetadataNone,
        MetadataPositions,
        MetadataWatchlistItems,
        MetadataTradeHistory,
        MetadataWatchlistLookup
    };

    enum RatesTarget { RatesNone, RatesSelectedInstrument, RatesWatchlistItems, RatesPositions, RatesDiscover };

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

    QVariantList m_instrumentWatchlistMatches;
    QVariantList m_watchlistLookupQueue;
    int m_watchlistLookupInstrumentId = 0;
    bool m_watchlistLookupActive = false;

    QString m_pendingLookupWatchlistId;
    QString m_pendingLookupWatchlistName;

    QString m_historyCustomFromDate;
    bool m_historyCustomRangeEnabled = false;
    QString m_historyCustomToDate;

    void rememberInstrumentRestrictions(const QVariantList &items);
    void applyInstrumentRestrictions(QVariantMap &item) const;

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

    QVariantList m_discoverResults;
    bool m_discoverLoading = false;

    QVariantMap m_discoverQuotes;
    bool m_discoverQuotesLoading = false;

    QString m_discoverSearchText;

    bool m_debugLoggingEnabled = false;
    void loadNextWatchlistForInstrumentLookup();

    QVariantMap m_instrumentRestrictionsById;
};

#endif // ETOROCLIENT_H