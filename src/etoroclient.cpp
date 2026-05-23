#include "etoroclient.h"
#include "applog.h"
#include <QDebug>
#include <QSet>
#include <algorithm>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QJsonObject>
#include <QVariantMap>

static const char *KEY_LOCK_ON_BACKGROUND = "security/lockOnBackground";
static const char *KEY_AUTO_LOCK_MINUTES = "security/autoLockMinutes";
static const char *KEY_PORTFOLIO_SHOW_FILTER = "ui/portfolioShowFilter";
static const char *KEY_PORTFOLIO_SHOW_SORT = "ui/portfolioShowSort";
static const char *KEY_PORTFOLIO_SORT_MODE = "ui/portfolioSortMode";
static const char *KEY_PORTFOLIO_VIEW_MODE = "ui/portfolioViewMode";
static const char *KEY_PORTFOLIO_FILTER_TEXT = "ui/portfolioFilterText";
static const char *KEY_HISTORY_FILTER_TEXT = "ui/historyFilterText";
static const char *KEY_STATISTICS_SORT_MODE = "ui/statisticsSortMode";
static const char *KEY_WATCHLIST_FILTER_TEXT = "ui/watchlistFilterText";
static const char *KEY_QUOTE_REFRESH_INTERVAL_SECONDS = "ui/quoteRefreshIntervalSeconds";
static const char *KEY_PORTFOLIO_COL1 = "portfolio_col1";
static const char *KEY_PORTFOLIO_COL2 = "portfolio_col2";
static const char *KEY_PORTFOLIO_COL3 = "portfolio_col3";
static const char *KEY_TRADING_ENABLED = "trading/enabled";
static const char *KEY_LIVE_ORDER_SUBMISSION_ENABLED = "trading/liveOrderSubmissionEnabled";
static const char *KEY_DEMO_MODE = "account/demoMode";
static const char *KEY_DEBUG_LOGGING_ENABLED = "debug/loggingEnabled";
static const char *KEY_HISTORY_CUSTOM_FROM_DATE = "history/customFromDate";
static const char *KEY_HISTORY_CUSTOM_RANGE_ENABLED = "history/customRangeEnabled";
static const char *KEY_HISTORY_CUSTOM_TO_DATE = "history/customToDate";

EtoroClient::EtoroClient(QObject *parent)
    : QObject(parent)
    , m_tokenStore(this)
    , m_settings("harbour-etoro", "harbour-etoro")
    , m_portfolioService(&m_nam, this)
    , m_marketService(&m_nam, this)
    , m_tradingService(&m_nam, this)
    , m_watchlistService(&m_nam, this)
    , m_historyService(&m_nam, this)
{
    m_locked = m_tokenStore.pinEnabled();

    m_debugLoggingEnabled = m_settings.value(KEY_DEBUG_LOGGING_ENABLED, false).toBool();
    m_historyCustomFromDate = m_settings.value(KEY_HISTORY_CUSTOM_FROM_DATE, QString()).toString();
    m_historyCustomRangeEnabled = m_settings.value(KEY_HISTORY_CUSTOM_RANGE_ENABLED, false).toBool();
    m_historyCustomToDate = m_settings.value(KEY_HISTORY_CUSTOM_TO_DATE, QString()).toString();

    if (!m_locked)
        reloadCachedCredentials();

    m_inactivityTimer.setSingleShot(true);
    connect(&m_inactivityTimer, &QTimer::timeout, this, [this]() {
        if (m_tokenStore.pinEnabled()) {
            setLocked(true);
            setLastError(QStringLiteral("App locked after inactivity."));
        }
    });

    // Portfolio connects ---
    connect(&m_portfolioService, &EtoroPortfolioService::portfolioReady,
            this, [this](const QVariantMap &summary, const QVariantList &positions) {
        m_portfolioSummary = summary;
        m_openPositions = positions;

        std::sort(m_openPositions.begin(), m_openPositions.end(), [](const QVariant &a, const QVariant &b) {
            return positionLessThan(a.toMap(), b.toMap());
        });

        rebuildGroupedOpenPositions();

        emit portfolioSummaryChanged();
        emit openPositionsChanged();
        emit groupedOpenPositionsChanged();

        if (!m_openPositions.isEmpty()) {
            m_metadataTarget = MetadataPositions;
            m_marketService.fetchInstrumentMetadata(currentInstrumentIds(),
                                                    m_cachedApiKey,
                                                    m_cachedUserKey);
        } else {
            setBusy(false);
            setOnline(true);
            setLastError(QString());
        }
    });

    connect(&m_portfolioService, &EtoroPortfolioService::requestFailed,
            this, [this](const QString &errorString, int httpStatus, const QByteArray &body) {
        if (m_debugLoggingEnabled)
        {
            qWarning() << "Portfolio request failed:" << httpStatus << errorString;
            qWarning() << "Body:" << body;
        }

        setBusy(false);

        if (httpStatus == 401 || httpStatus == 403) {
            setLastError(QStringLiteral("Authentication failed. Please check your API key and user key."));
        } else if (errorString.contains("Host not found", Qt::CaseInsensitive)
                   || errorString.contains("Network", Qt::CaseInsensitive)
                   || errorString.contains("Connection", Qt::CaseInsensitive)) {
            setOnline(false);
            setLastError(QStringLiteral("No internet connection."));
        } else {
            setLastError(QStringLiteral("Could not load portfolio. Please try again."));
        }
    });
    // Portfolio connects ---

    // Market connects ---
    connect(&m_marketService, &EtoroMarketService::instrumentMetadataReady,
            this, [this](const QVariantMap &metadataById) {
        if (m_metadataTarget == MetadataPositions) {
            enrichOpenPositions(metadataById);
            rebuildGroupedOpenPositions();
            emit openPositionsChanged();
            emit groupedOpenPositionsChanged();
            refreshPositionsQuotes();
        } else if (m_metadataTarget == MetadataWatchlistItems) {
            enrichPendingWatchlistItems(metadataById);
            m_currentWatchlistItems = m_pendingWatchlistItems;
            m_pendingWatchlistItems.clear();
            m_watchlistItemsLoading = false;
            emit currentWatchlistItemsChanged();

            refreshCurrentWatchlistQuotes();
        } else if (m_metadataTarget == MetadataTradeHistory) {
            enrichPendingTradeHistory(metadataById);
            m_tradeHistory = m_pendingTradeHistory;
            m_pendingTradeHistory.clear();
            m_historyLoading = false;
            emit tradeHistoryChanged();
        } else if (m_metadataTarget == MetadataWatchlistLookup) {
            const QVariantMap meta = metadataById.value(QString::number(m_watchlistLookupInstrumentId)).toMap();

            for (int i = 0; i < m_instrumentWatchlistMatches.size(); ++i) {
                QVariantMap item = m_instrumentWatchlistMatches.at(i).toMap();

                const QString displayName = meta.value(QStringLiteral("displayName")).toString().trimmed();
                const QString symbol = meta.value(QStringLiteral("symbol")).toString().trimmed();

                if (!displayName.isEmpty())
                    item.insert(QStringLiteral("displayName"), displayName);
                if (!symbol.isEmpty())
                    item.insert(QStringLiteral("symbol"), symbol);

                item.insert(QStringLiteral("instrumentTypeId"), meta.value(QStringLiteral("instrumentTypeId")));
                item.insert(QStringLiteral("exchangeId"), meta.value(QStringLiteral("exchangeId")));
                item.insert(QStringLiteral("priceSource"), meta.value(QStringLiteral("priceSource")));
                item.insert(QStringLiteral("isBuyEnabled"), meta.value(QStringLiteral("isBuyEnabled")));
                item.insert(QStringLiteral("isCurrentlyTradable"), meta.value(QStringLiteral("isCurrentlyTradable")));
                item.insert(QStringLiteral("isExchangeOpen"), meta.value(QStringLiteral("isExchangeOpen")));
                item.insert(QStringLiteral("tradingDisabled"), meta.value(QStringLiteral("tradingDisabled")));

                m_instrumentWatchlistMatches[i] = item;
            }

            emit instrumentWatchlistMatchesChanged();
        }

        m_metadataTarget = MetadataNone;
        setBusy(false);
        setOnline(true);
        setLastError(QString());
    });

    connect(&m_marketService, &EtoroMarketService::requestFailed,
            this, [this](const QString &errorString, int httpStatus, const QByteArray &body) {
        if (m_debugLoggingEnabled)
        {
            qWarning() << "Metadata request failed:" << httpStatus << errorString;
            qWarning() << "Metadata body:" << body;
        }

        if (httpStatus == 429 && m_metadataTarget == MetadataNone) {
            m_quoteRateLimitUntil = QDateTime::currentDateTimeUtc().addSecs(60);
            m_quoteRateLimitMessage = QStringLiteral("Live prices are paused briefly to avoid too many requests.");
            emit quoteRefreshSettingsChanged();
        }

        if (m_metadataTarget == MetadataWatchlistItems) {
            m_currentWatchlistItems = m_pendingWatchlistItems;
            m_pendingWatchlistItems.clear();
            m_watchlistItemsLoading = false;
            emit currentWatchlistItemsChanged();

            refreshCurrentWatchlistQuotes();
            setLastError(QStringLiteral("Watchlist loaded, but some asset names could not be shown."));
        } else if (m_metadataTarget == MetadataTradeHistory) {
            m_tradeHistory = m_pendingTradeHistory;
            m_pendingTradeHistory.clear();
            m_historyLoading = false;
            emit tradeHistoryChanged();
            setLastError(QStringLiteral("Trade history loaded, but some asset names could not be shown."));
        } else {
            setLastError(QStringLiteral("Portfolio loaded, but some asset names could not be shown."));
            emit openPositionsChanged();
            refreshPositionsQuotes();
        }

        m_metadataTarget = MetadataNone;
        setBusy(false);
    });

    connect(&m_marketService, &EtoroMarketService::instrumentRatesReady,
            this, [this](const QVariantMap &ratesById) {
        m_quoteRateLimitUntil = QDateTime();
        m_quoteRateLimitMessage.clear();
        emit quoteRefreshSettingsChanged();

        if (m_ratesTarget == RatesSelectedInstrument) {
            QVariantMap quote;
            if (!ratesById.isEmpty()) {
                const QString firstKey = ratesById.keys().first();
                quote = ratesById.value(firstKey).toMap();
            }

            m_selectedInstrumentQuote = quote;
            m_selectedInstrumentQuoteLoading = false;
            emit selectedInstrumentQuoteChanged();
        } else if (m_ratesTarget == RatesWatchlistItems) {
            m_currentWatchlistQuotes = ratesById;
            m_currentWatchlistQuotesLoading = false;
            emit currentWatchlistQuotesChanged();
        } else if (m_ratesTarget == RatesPositions) {
            m_positionsQuotes = ratesById;
            m_positionsQuotesLoading = false;
            emit positionsQuotesChanged();
        } else if (m_ratesTarget == RatesDiscover) {
            m_discoverQuotes = ratesById;
            m_discoverQuotesLoading = false;
            emit discoverQuotesChanged();
        }

        m_ratesTarget = RatesNone;
    });

    // Discover/Search connects ---
    connect(&m_marketService, &EtoroMarketService::instrumentSearchReady, this, [this](const QVariantList &results) {
        rememberInstrumentRestrictions(results);
        m_discoverResults = results;
        m_discoverLoading = false;
        emit discoverResultsChanged();

        refreshDiscoverQuotes();

        setBusy(false);
        setOnline(true);
        setLastError(QString());
    });

    connect(&m_marketService, &EtoroMarketService::requestFailed, this, [this](const QString &errorString, int httpStatus, const QByteArray &body) {
        if (m_debugLoggingEnabled)
        {
            qWarning() << "Market request failed:" << httpStatus << errorString;
            qWarning() << "Market body:" << body;
        }

        if (m_discoverLoading) {
            m_discoverLoading = false;
            emit discoverResultsChanged();
        }

        setBusy(false);

        if (httpStatus == 401 || httpStatus == 403)
            setLastError(QStringLiteral("Authentication failed. Please check your API key and user key."));
        else
            setLastError(QStringLiteral("Could not load market data. Please try again."));
    });
    // Market connects ---

    // Watchlist connects ---
    connect(&m_watchlistService, &EtoroWatchlistService::watchlistsReady,
            this, [this](const QVariantList &watchlists) {
        m_watchlists = watchlists;
        emit watchlistsChanged();
//        if (m_watchlistLookupInstrumentId > 0 && !m_watchlistLookupActive) {
        if (m_watchlistLookupInstrumentId > 0 && m_watchlistLookupActive && m_watchlistLookupQueue.isEmpty()) {
            m_watchlistLookupQueue = m_watchlists;
//            m_watchlistLookupActive = true;
            emit instrumentWatchlistMatchesChanged();
            loadNextWatchlistForInstrumentLookup();
        }
        setBusy(false);
        setOnline(true);
        setLastError(QString());
    });

    connect(&m_watchlistService, &EtoroWatchlistService::watchlistItemsReady,
            this, [this](const QString &watchlistId, const QString &watchlistName, const QVariantList &items) {
        if (m_watchlistLookupActive) {
            for (const QVariant &itemVar : items) {
                const QVariantMap item = itemVar.toMap();

                const int itemId = item.value(QStringLiteral("instrumentId")).toInt();
                const int rawItemId = item.value(QStringLiteral("itemId")).toInt();

                if (itemId == m_watchlistLookupInstrumentId || rawItemId == m_watchlistLookupInstrumentId) {
                    QVariantMap match = item;
                    match.insert(QStringLiteral("watchlistId"), watchlistId);
                    match.insert(QStringLiteral("watchlistName"), watchlistName);
                    bool alreadyAdded = false;

                    for (const QVariant &existingVar : m_instrumentWatchlistMatches) {
                        const QVariantMap existing = existingVar.toMap();
                        if (existing.value(QStringLiteral("watchlistId")).toString() == watchlistId) {
                            alreadyAdded = true;
                            break;
                        }
                    }

                    if (!alreadyAdded)
                        m_instrumentWatchlistMatches << match;

                    break;
                }
            }

            emit instrumentWatchlistMatchesChanged();
            loadNextWatchlistForInstrumentLookup();
            return;
        }

        m_currentWatchlistName = watchlistName;
        m_pendingWatchlistItems = items;
        m_currentWatchlistItems.clear();
        m_watchlistItemsLoading = true;
        emit currentWatchlistItemsChanged();

        const QList<int> ids = pendingWatchlistInstrumentIds();
        if (!ids.isEmpty()) {
            m_metadataTarget = MetadataWatchlistItems;
            m_marketService.fetchInstrumentMetadata(ids,
                                                    m_cachedApiKey,
                                                    m_cachedUserKey);
        } else {
            m_currentWatchlistItems = m_pendingWatchlistItems;
            m_pendingWatchlistItems.clear();
            m_watchlistItemsLoading = false;
            emit currentWatchlistItemsChanged();
            setBusy(false);
            setOnline(true);
            setLastError(QString());
        }
    });

    connect(&m_watchlistService, &EtoroWatchlistService::requestFailed,
            this, [this](const QString &errorString, int httpStatus, const QByteArray &body) {
        if (m_debugLoggingEnabled)
        {
            qWarning() << "Watchlist request failed:" << httpStatus << errorString;
            qWarning() << "Watchlist body:" << body;
        }
        setBusy(false);

        if (httpStatus == 401 || httpStatus == 403) {
            setLastError(QStringLiteral("Authentication failed. Please check your API key and user key."));
        } else {
            QString friendly = QStringLiteral("Could not update watchlist. Please try again.");
            QJsonParseError pe{};
            const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
            if (pe.error == QJsonParseError::NoError && doc.isObject()) {
                const QVariantMap root = doc.object().toVariantMap();
                const QVariantMap exception = root.value(QStringLiteral("exception")).toMap();
                const QString message = exception.value(QStringLiteral("message")).toString().trimmed();
                if (!message.isEmpty())
                    friendly = message;
            }

            setLastError(friendly);
        }
    });

    connect(&m_watchlistService, &EtoroWatchlistService::watchlistItemAdded,
            this, [this](const QString &watchlistId, const QVariantMap &instrument) {
        Q_UNUSED(instrument)

        setBusy(false);
        setOnline(true);
        setLastError(QStringLiteral("Asset added to watchlist."));
        emit watchlistItemAdded();

        refreshWatchlists();

        if (!watchlistId.isEmpty())
            loadWatchlist(watchlistId);
    });

    connect(&m_watchlistService, &EtoroWatchlistService::watchlistCreated,
            this, [this](const QString &watchlistId, const QString &name) {
        setBusy(false);
        setOnline(true);
        setLastError(QStringLiteral("Watchlist created."));
        emit watchlistCreated(watchlistId, name);
        refreshWatchlists();
    });

    connect(&m_watchlistService, &EtoroWatchlistService::watchlistRenamed,
            this, [this](const QString &watchlistId, const QString &name) {
        setBusy(false);
        setOnline(true);
        setLastError(QStringLiteral("Watchlist renamed."));
        emit watchlistRenamed(watchlistId, name);
        refreshWatchlists();
    });

    connect(&m_watchlistService, &EtoroWatchlistService::watchlistDeleted,
            this, [this](const QString &watchlistId) {
        setBusy(false);
        setOnline(true);
        setLastError(QStringLiteral("Watchlist deleted."));
        emit watchlistDeleted(watchlistId);
        refreshWatchlists();
    });

    connect(&m_watchlistService, &EtoroWatchlistService::watchlistItemRemoved,
            this, [this](const QString &watchlistId, const QVariantMap &instrument) {
        Q_UNUSED(instrument)

        setBusy(false);
        setOnline(true);
        setLastError(QStringLiteral("Asset removed from watchlist."));
        emit watchlistItemRemoved();

        m_instrumentWatchlistMatches.clear();
        m_watchlistLookupQueue.clear();
        m_watchlistLookupInstrumentId = 0;
        m_watchlistLookupActive = false;
        m_pendingLookupWatchlistId.clear();
        m_pendingLookupWatchlistName.clear();
        emit instrumentWatchlistMatchesChanged();

        refreshWatchlists();

        if (!watchlistId.isEmpty())
            loadWatchlist(watchlistId);
    });
    // Watchlist connects ---

    // History connects ---
    connect(&m_historyService, &EtoroHistoryService::tradeHistoryReady,
            this, [this](const QVariantList &trades, int page, int pageSize, bool hasMore) {
        if (page <= 1)
            m_pendingTradeHistory = trades;
        else
            m_pendingTradeHistory += trades;

        std::sort(m_pendingTradeHistory.begin(), m_pendingTradeHistory.end(), [](const QVariant &a, const QVariant &b) {
            return tradeHistoryNewerThan(a.toMap(), b.toMap());
        });

        m_historyCurrentPage = page;
        m_historyPageSize = pageSize;
        m_historyHasMore = hasMore;
        m_historyLoading = true;
        emit tradeHistoryChanged();

        const QList<int> ids = pendingTradeHistoryInstrumentIds();
        if (!ids.isEmpty()) {
            m_metadataTarget = MetadataTradeHistory;
            m_marketService.fetchInstrumentMetadata(ids,
                                                    m_cachedApiKey,
                                                    m_cachedUserKey);
        } else {
            m_tradeHistory = m_pendingTradeHistory;
            m_pendingTradeHistory.clear();
            m_historyLoading = false;
            emit tradeHistoryChanged();
            setBusy(false);
            setOnline(true);
            setLastError(QString());
        }
    });

    connect(&m_historyService, &EtoroHistoryService::requestFailed,
            this, [this](const QString &errorString, int httpStatus, const QByteArray &body) {
        if (m_debugLoggingEnabled)
        {
            qWarning() << "History request failed:" << httpStatus << errorString;
            qWarning() << "History body:" << body;
        }
        setBusy(false);

        if (httpStatus == 401 || httpStatus == 403) {
            setLastError(QStringLiteral("Authentication failed. Please check your API key and user key."));
        } else {
            setLastError(QStringLiteral("Failed to load trade history."));
        }
    });
    // History connects ---


    // Trading connects ---
    // Order - Buy ----
    connect(&m_tradingService, &EtoroTradingService::marketOrderPrepared,
            this, [this](const QVariantMap &payload) {
        if (m_debugLoggingEnabled)
            qWarning() << "Market order prepared:" << payload;
        setBusy(false);
        setOnline(true);
        setLastError(QString());
    });

    connect(&m_tradingService, &EtoroTradingService::marketOrderSubmitted,
            this, [this](const QVariantMap &response) {
        if (m_debugLoggingEnabled)
            qWarning() << "Market order submitted:" << response;
        setBusy(false);
        setOnline(true);
        setLastError(QStringLiteral("Market order submitted."));
        QTimer::singleShot(2500, this, [this]() {
            if (!m_locked && hasCredentials() && !m_busy)
                refreshPortfolio();
        });
    });

    connect(&m_tradingService, &EtoroTradingService::requestFailed,
            this, [this](const QString &errorString, int httpStatus, const QByteArray &body) {
        if (m_debugLoggingEnabled)
        {
            qWarning() << "Market order request failed:" << httpStatus << errorString;
            qWarning() << "Market order body:" << body;
        }

        setBusy(false);

        if (httpStatus == 401 || httpStatus == 403)
            setLastError(QStringLiteral("Trading request authentication failed."));
        else
            setLastError(QStringLiteral("Failed to submit market order."));
    });

    // Close - Sell (full) ----
    connect(&m_tradingService, &EtoroTradingService::closePositionPrepared, this, [this](const QVariantMap &payload) {
        if (m_debugLoggingEnabled)
            qWarning() << "Close position prepared:" << payload;
        setBusy(false);
        setOnline(true);
        setLastError(QString());
    });

    connect(&m_tradingService, &EtoroTradingService::closePositionSubmitted, this, [this](const QVariantMap &response) {
        if (m_debugLoggingEnabled)
            qWarning() << "Close position submitted:" << response;
        setBusy(false);
        setOnline(true);
        setLastError(QStringLiteral("Position close submitted."));
        emit positionCloseSubmitted();

        QTimer::singleShot(2500, this, [this]() {
            if (!m_locked && hasCredentials() && !m_busy)
                refreshPortfolio();
        });
    });

    // Update SL/TP ----
    connect(&m_tradingService, &EtoroTradingService::positionProtectionPrepared, this, [this](const QVariantMap &payload) {
        if (m_debugLoggingEnabled)
            qWarning() << "Position protection prepared:" << payload;
        setBusy(false);
        setOnline(true);
        setLastError(QString());
    });

    // Update SL/TP ----
    connect(&m_tradingService, &EtoroTradingService::positionProtectionUpdated, this, [this](const QVariantMap &response) {
        if (m_debugLoggingEnabled)
            qWarning() << "Position protection updated:" << response;
        setBusy(false);
        setOnline(true);
        setLastError(QStringLiteral("Position protection updated."));

        QTimer::singleShot(1500, this, [this]() {
            if (!m_locked && hasCredentials() && !m_busy)
                refreshPortfolio();
        });
    });
    // Trading connects ---

    resetInactivityTimer();
}

QVariantMap EtoroClient::restrictionsForInstrument(const QVariant &instrumentId) const
{
    const int id = instrumentId.toInt();
    if (id <= 0)
        return QVariantMap();

    return m_instrumentRestrictionsById.value(QString::number(id)).toMap();
}

void EtoroClient::rememberInstrumentRestrictions(const QVariantList &items)
{
    for (const QVariant &v : items) {
        const QVariantMap item = v.toMap();
        const int instrumentId = item.value(QStringLiteral("instrumentId")).toInt();

        if (instrumentId <= 0)
            continue;

        QVariantMap restrictions;

        if (item.contains(QStringLiteral("isBuyEnabled")))
            restrictions.insert(QStringLiteral("isBuyEnabled"), item.value(QStringLiteral("isBuyEnabled")));
        if (item.contains(QStringLiteral("isCurrentlyTradable")))
            restrictions.insert(QStringLiteral("isCurrentlyTradable"), item.value(QStringLiteral("isCurrentlyTradable")));
        if (item.contains(QStringLiteral("isExchangeOpen")))
            restrictions.insert(QStringLiteral("isExchangeOpen"), item.value(QStringLiteral("isExchangeOpen")));
        if (item.contains(QStringLiteral("tradingDisabled")))
            restrictions.insert(QStringLiteral("tradingDisabled"), item.value(QStringLiteral("tradingDisabled")));

        if (!restrictions.isEmpty())
            m_instrumentRestrictionsById.insert(QString::number(instrumentId), restrictions);
    }
}

void EtoroClient::applyInstrumentRestrictions(QVariantMap &item) const
{
    const int instrumentId = item.value(QStringLiteral("instrumentId")).toInt();
    if (instrumentId <= 0)
        return;

    const QVariantMap restrictions =
            m_instrumentRestrictionsById.value(QString::number(instrumentId)).toMap();

    if (restrictions.isEmpty())
        return;

    for (auto it = restrictions.constBegin(); it != restrictions.constEnd(); ++it)
        item.insert(it.key(), it.value());
}

QVariantList EtoroClient::instrumentWatchlistMatches() const
{
    return m_instrumentWatchlistMatches;
}

bool EtoroClient::instrumentWatchlistLookupActive() const
{
    return m_watchlistLookupActive;
}

void EtoroClient::findWatchlistsForInstrument(const QVariant &instrumentId)
{
    const int wantedId = instrumentId.toInt();

    m_instrumentWatchlistMatches.clear();
    m_watchlistLookupQueue.clear();
    m_watchlistLookupInstrumentId = wantedId;
    m_watchlistLookupActive = false;
    emit instrumentWatchlistMatchesChanged();

    if (wantedId <= 0)
        return;

    if (m_watchlists.isEmpty()) {
        m_watchlistLookupActive = true;
        emit instrumentWatchlistMatchesChanged();
        refreshWatchlists();
        return;
    }

    m_watchlistLookupQueue = m_watchlists;
    m_watchlistLookupActive = true;
    emit instrumentWatchlistMatchesChanged();

    loadNextWatchlistForInstrumentLookup();
}

bool EtoroClient::debugLoggingEnabled() const
{
    return m_debugLoggingEnabled;
}

void EtoroClient::setDebugLoggingEnabled(bool enabled)
{
    if (m_debugLoggingEnabled == enabled)
        return;

    m_debugLoggingEnabled = enabled;
    m_settings.setValue(KEY_DEBUG_LOGGING_ENABLED, enabled);
    AppLog::setDebugEnabled(enabled);

    emit debugLoggingChanged();
}

QString EtoroClient::discoverSearchText() const
{
    return m_discoverSearchText;
}

void EtoroClient::setDiscoverSearchText(const QString &text)
{
    if (m_discoverSearchText == text)
        return;

    m_discoverSearchText = text;
    emit discoverSearchTextChanged();
}

QVariantMap EtoroClient::discoverQuotes() const
{
    return m_discoverQuotes;
}

bool EtoroClient::discoverQuotesLoading() const
{
    return m_discoverQuotesLoading;
}

QVariantMap EtoroClient::quoteForDiscoverInstrument(const QVariant &instrumentId) const
{
    return m_discoverQuotes.value(QString::number(instrumentId.toInt())).toMap();
}

void EtoroClient::refreshDiscoverQuotes()
{
    QList<int> ids;

    for (const QVariant &rowVar : m_discoverResults) {
        const QVariantMap row = rowVar.toMap();
        const int id = row.value(QStringLiteral("instrumentId")).toInt();
        if (id > 0 && !ids.contains(id))
            ids << id;
    }

    if (ids.isEmpty()) {
        m_discoverQuotes.clear();
        m_discoverQuotesLoading = false;
        emit discoverQuotesChanged();
        return;
    }

    m_discoverQuotesLoading = true;
    emit discoverQuotesChanged();

    m_ratesTarget = RatesDiscover;
    m_marketService.fetchInstrumentRates(ids, m_cachedApiKey, m_cachedUserKey);
}

QVariantList EtoroClient::discoverResults() const
{
    return m_discoverResults;
}

bool EtoroClient::discoverLoading() const
{
    return m_discoverLoading;
}

QString EtoroClient::apiKey() const
{
    return m_locked ? QString() : m_cachedApiKey;
}

QString EtoroClient::userKey() const
{
    return m_locked ? QString() : m_cachedUserKey;
}

void EtoroClient::searchDiscoverInstruments(const QString &query)
{
    const QString trimmed = query.trimmed();

    setDiscoverSearchText(query);

    if (trimmed.isEmpty()) {
        clearDiscoverResults();
        return;
    }

    if (m_locked) {
        setLastError(tr("Unlock the app first"));
        return;
    }

    if (!hasCredentials()) {
        setLastError(tr("Enter API credentials first"));
        return;
    }

    m_discoverLoading = true;
    m_discoverResults.clear();
    emit discoverResultsChanged();

    setBusy(true);
    m_marketService.searchInstruments(trimmed, m_cachedApiKey, m_cachedUserKey);
}

void EtoroClient::clearDiscoverResults()
{
    m_discoverResults.clear();
    m_discoverLoading = false;
    emit discoverResultsChanged();
    m_discoverQuotes.clear();
    m_discoverQuotesLoading = false;
    emit discoverQuotesChanged();
    setDiscoverSearchText(QString());
}

QString EtoroClient::portfolioColumn1() const
{
    return m_settings.value(KEY_PORTFOLIO_COL1, QStringLiteral("pl_percent")).toString();
}

QString EtoroClient::portfolioColumn2() const
{
    return m_settings.value(KEY_PORTFOLIO_COL2, QStringLiteral("pl")).toString();
}

QString EtoroClient::portfolioColumn3() const
{
    return m_settings.value(KEY_PORTFOLIO_COL3, QStringLiteral("net")).toString();
}

void EtoroClient::setPortfolioColumn1(const QString &value)
{
    if (portfolioColumn1() == value)
        return;

    m_settings.setValue(KEY_PORTFOLIO_COL1, value);
    m_settings.sync();
    emit portfolioColumnsChanged();
}

void EtoroClient::setPortfolioColumn2(const QString &value)
{
    if (portfolioColumn2() == value)
        return;

    m_settings.setValue(KEY_PORTFOLIO_COL2, value);
    m_settings.sync();
    emit portfolioColumnsChanged();
}

void EtoroClient::setPortfolioColumn3(const QString &value)
{
    if (portfolioColumn3() == value)
        return;

    m_settings.setValue(KEY_PORTFOLIO_COL3, value);
    m_settings.sync();
    emit portfolioColumnsChanged();
}

int EtoroClient::quoteRefreshIntervalSeconds() const
{
    return m_settings.value(KEY_QUOTE_REFRESH_INTERVAL_SECONDS, 10).toInt();
}

void EtoroClient::setQuoteRefreshIntervalSeconds(int seconds)
{
    if (quoteRefreshIntervalSeconds() == seconds)
        return;

    m_settings.setValue(KEY_QUOTE_REFRESH_INTERVAL_SECONDS, seconds);
    m_settings.sync();
    emit quoteRefreshSettingsChanged();
}

void EtoroClient::reloadCachedCredentials()
{
    m_cachedApiKey = m_tokenStore.apiKey();
    m_cachedUserKey = m_tokenStore.userKeyForMode(demoMode());
}

void EtoroClient::clearLastError()
{
    if (m_lastError.isEmpty()) {
        emit lastErrorChanged();
        return;
    }

    m_lastError.clear();
    emit lastErrorChanged();
}

void EtoroClient::clearCachedCredentials()
{
    m_cachedApiKey.clear();
    m_cachedUserKey.clear();
}

QString EtoroClient::historyCustomFromDate() const
{
    return m_historyCustomFromDate;
}

bool EtoroClient::historyCustomRangeEnabled() const
{
    return m_historyCustomRangeEnabled;
}

void EtoroClient::setHistoryCustomFromDate(const QString &value)
{
    if (m_historyCustomFromDate == value)
        return;

    m_historyCustomFromDate = value;
    m_settings.setValue(KEY_HISTORY_CUSTOM_FROM_DATE, value);
    emit historyUiChanged();
}

QString EtoroClient::historyCustomToDate() const
{
    return m_historyCustomToDate;
}

void EtoroClient::setHistoryCustomToDate(const QString &value)
{
    if (m_historyCustomToDate == value)
        return;

    m_historyCustomToDate = value;
    m_settings.setValue(KEY_HISTORY_CUSTOM_TO_DATE, value);
    emit historyUiChanged();
}

void EtoroClient::setHistoryCustomRangeEnabled(bool value)
{
    if (m_historyCustomRangeEnabled == value)
        return;

    m_historyCustomRangeEnabled = value;
    m_settings.setValue(KEY_HISTORY_CUSTOM_RANGE_ENABLED, value);
    emit historyUiChanged();
}

void EtoroClient::applyHistoryCustomRange()
{
    if (m_historyCustomFromDate.trimmed().isEmpty()) {
        setLastError(tr("Select a start date"));
        return;
    }

    if (!m_historyCustomToDate.trimmed().isEmpty()
            && m_historyCustomToDate.trimmed() < m_historyCustomFromDate.trimmed()) {
        setLastError(tr("End date must be after start date"));
        return;
    }

    setHistoryCustomRangeEnabled(true);
    refreshTradeHistoryFrom(m_historyCustomFromDate.trimmed());
}

void EtoroClient::clearHistoryCustomRange()
{
    setHistoryCustomRangeEnabled(false);
    setHistoryCustomFromDate(QString());
    setHistoryCustomToDate(QString());
    refreshTradeHistory();
}

QString EtoroClient::historyFilterText() const
{
    return m_settings.value(KEY_HISTORY_FILTER_TEXT, QString()).toString();
}

QString EtoroClient::statisticsSortMode() const
{
    return m_settings.value(KEY_STATISTICS_SORT_MODE, QStringLiteral("asset")).toString();
}

QString EtoroClient::watchlistFilterText() const
{
    return m_settings.value(KEY_WATCHLIST_FILTER_TEXT, QString()).toString();
}

QVariantList EtoroClient::groupedOpenPositions() const
{
    return m_groupedOpenPositions;
}

bool EtoroClient::portfolioShowFilter() const
{
    return m_settings.value(KEY_PORTFOLIO_SHOW_FILTER, false).toBool();
}

bool EtoroClient::portfolioShowSort() const
{
    return m_settings.value(KEY_PORTFOLIO_SHOW_SORT, false).toBool();
}

QString EtoroClient::portfolioSortMode() const
{
    return m_settings.value(KEY_PORTFOLIO_SORT_MODE, QStringLiteral("invested")).toString();
}

QString EtoroClient::portfolioViewMode() const
{
    return m_settings.value(KEY_PORTFOLIO_VIEW_MODE, QStringLiteral("card")).toString();
}

QString EtoroClient::portfolioFilterText() const
{
    return m_settings.value(KEY_PORTFOLIO_FILTER_TEXT, QString()).toString();
}

bool EtoroClient::tradingEnabled() const
{
    return m_settings.value(KEY_TRADING_ENABLED, false).toBool();
}

void EtoroClient::setTradingEnabled(bool enabled)
{
    if (tradingEnabled() == enabled)
        return;

    m_settings.setValue(KEY_TRADING_ENABLED, enabled);
    m_settings.sync();

    emit tradingModeChanged();
}

bool EtoroClient::liveOrderSubmissionEnabled() const
{
    return m_settings.value(KEY_LIVE_ORDER_SUBMISSION_ENABLED, false).toBool();
}

void EtoroClient::setLiveOrderSubmissionEnabled(bool enabled)
{
    if (liveOrderSubmissionEnabled() == enabled)
        return;

    m_settings.setValue(KEY_LIVE_ORDER_SUBMISSION_ENABLED, enabled);
    m_settings.sync();

    emit tradingModeChanged();
}

bool EtoroClient::demoMode() const
{
    return m_settings.value(KEY_DEMO_MODE, false).toBool();
}

void EtoroClient::setDemoMode(bool enabled)
{
    if (demoMode() == enabled)
        return;

    m_settings.setValue(KEY_DEMO_MODE, enabled);
    m_settings.sync();

    reloadCachedCredentials();
    emit credentialsChanged();

    emit accountModeChanged();
    emit credentialsChanged();

    m_portfolioSummary.clear();
    m_openPositions.clear();
    m_groupedOpenPositions.clear();
    m_positionsQuotes.clear();
    m_tradeHistory.clear();

    emit portfolioSummaryChanged();
    emit openPositionsChanged();
    emit groupedOpenPositionsChanged();
    emit positionsQuotesChanged();
    emit tradeHistoryChanged();

    if (hasCredentials() && !m_locked && !m_busy)
        refreshPortfolio();
}

QString EtoroClient::accountModePathSegment() const
{
    return demoMode() ? QStringLiteral("demo") : QStringLiteral("real");
}

void EtoroClient::setHistoryFilterText(const QString &value)
{
    if (historyFilterText() == value)
        return;

    m_settings.setValue(KEY_HISTORY_FILTER_TEXT, value);
    m_settings.sync();
    emit historyUiChanged();
}

void EtoroClient::setStatisticsSortMode(const QString &value)
{
    if (statisticsSortMode() == value)
        return;

    m_settings.setValue(KEY_STATISTICS_SORT_MODE, value);
    m_settings.sync();
    emit statisticsUiChanged();
}

void EtoroClient::setWatchlistFilterText(const QString &value)
{
    if (watchlistFilterText() == value)
        return;

    m_settings.setValue(KEY_WATCHLIST_FILTER_TEXT, value);
    m_settings.sync();
    emit watchlistUiChanged();
}

void EtoroClient::setPortfolioShowFilter(bool value)
{
    if (portfolioShowFilter() == value)
        return;

    m_settings.setValue(KEY_PORTFOLIO_SHOW_FILTER, value);
    m_settings.sync();
    emit portfolioUiChanged();
}

void EtoroClient::setPortfolioShowSort(bool value)
{
    if (portfolioShowSort() == value)
        return;

    m_settings.setValue(KEY_PORTFOLIO_SHOW_SORT, value);
    m_settings.sync();
    emit portfolioUiChanged();
}

void EtoroClient::setPortfolioSortMode(const QString &value)
{
    const QString normalized = (value == QStringLiteral("profit") || value == QStringLiteral("name"))
            ? value
            : QStringLiteral("invested");

    if (portfolioSortMode() == normalized)
        return;

    m_settings.setValue(KEY_PORTFOLIO_SORT_MODE, normalized);
    m_settings.sync();
    emit portfolioUiChanged();
}

void EtoroClient::setPortfolioViewMode(const QString &value)
{
    const QString normalized = (value == QStringLiteral("compact"))
            ? QStringLiteral("compact")
            : QStringLiteral("card");

    if (portfolioViewMode() == normalized)
        return;

    m_settings.setValue(KEY_PORTFOLIO_VIEW_MODE, normalized);
    m_settings.sync();
    emit portfolioUiChanged();
}

void EtoroClient::setPortfolioFilterText(const QString &value)
{
    if (portfolioFilterText() == value)
        return;

    m_settings.setValue(KEY_PORTFOLIO_FILTER_TEXT, value);
    m_settings.sync();
    emit portfolioUiChanged();
}

QVariantMap EtoroClient::positionsQuotes() const
{
    return m_positionsQuotes;
}

bool EtoroClient::positionsQuotesLoading() const
{
    return m_positionsQuotesLoading;
}

QVariantMap EtoroClient::currentWatchlistQuotes() const
{
    return m_currentWatchlistQuotes;
}

bool EtoroClient::currentWatchlistQuotesLoading() const
{
    return m_currentWatchlistQuotesLoading;
}

QVariantMap EtoroClient::selectedInstrumentQuote() const
{
    return m_selectedInstrumentQuote;
}

bool EtoroClient::selectedInstrumentQuoteLoading() const
{
    return m_selectedInstrumentQuoteLoading;
}

bool EtoroClient::historyLoading() const
{
    return m_historyLoading;
}

int EtoroClient::historyCurrentPage() const
{
    return m_historyCurrentPage;
}

int EtoroClient::historyPageSize() const
{
    return m_historyPageSize;
}

bool EtoroClient::historyHasMore() const
{
    return m_historyHasMore;
}

QVariantList EtoroClient::tradeHistory() const
{
    return m_tradeHistory;
}

QString EtoroClient::historyMinDate() const
{
    return m_historyMinDate;
}

bool EtoroClient::watchlistItemsLoading() const
{
    return m_watchlistItemsLoading;
}

QVariantList EtoroClient::watchlists() const
{
    return m_watchlists;
}

QVariantList EtoroClient::currentWatchlistItems() const
{
    return m_currentWatchlistItems;
}

QString EtoroClient::currentWatchlistName() const
{
    return m_currentWatchlistName;
}

QString EtoroClient::pinSettingsError() const
{
    return m_pinSettingsError;
}

bool EtoroClient::hasCredentials() const
{
    if (m_locked)
        return demoMode() ? hasDemoCredentials() : hasRealCredentials();

    return !m_cachedApiKey.isEmpty() && !m_cachedUserKey.isEmpty();
}

bool EtoroClient::busy() const
{
    return m_busy;
}

bool EtoroClient::locked() const
{
    return m_locked;
}

bool EtoroClient::online() const
{
    return m_online;
}

QString EtoroClient::lastError() const
{
    return m_lastError;
}

QVariantMap EtoroClient::portfolioSummary() const
{
    return m_portfolioSummary;
}

QVariantList EtoroClient::openPositions() const
{
    return m_openPositions;
}

static bool isRateLimitedStatus(int httpStatus)
{
    return httpStatus == 429;
}

bool EtoroClient::addInstrumentToWatchlist(const QString &watchlistId, const QVariantMap &instrument)
{
    if (m_locked) {
        setLastError(tr("Unlock the app first"));
        return false;
    }

    if (!hasCredentials()) {
        setLastError(tr("Enter API credentials first"));
        return false;
    }

    if (watchlistId.trimmed().isEmpty()) {
        setLastError(tr("Select a watchlist"));
        return false;
    }

    if (instrument.value(QStringLiteral("instrumentId")).toInt() <= 0) {
        setLastError(tr("Missing asset details."));
        return false;
    }

    setBusy(true);
    m_watchlistService.addInstrumentToWatchlist(watchlistId.trimmed(),
                                                instrument,
                                                m_cachedApiKey,
                                                m_cachedUserKey);
    return true;
}

bool EtoroClient::createWatchlist(const QString &name)
{
    const QString trimmed = name.trimmed();

    if (m_locked) {
        setLastError(tr("Unlock the app first"));
        return false;
    }

    if (!hasCredentials()) {
        setLastError(tr("Enter API credentials first"));
        return false;
    }

    if (trimmed.isEmpty()) {
        setLastError(tr("Enter a watchlist name"));
        return false;
    }

    setBusy(true);
    m_watchlistService.createWatchlist(trimmed, m_cachedApiKey, m_cachedUserKey);
    return true;
}

bool EtoroClient::renameWatchlist(const QString &watchlistId, const QString &name)
{
    const QString trimmedId = watchlistId.trimmed();
    const QString trimmedName = name.trimmed();

    if (m_locked) {
        setLastError(tr("Unlock the app first"));
        return false;
    }

    if (!hasCredentials()) {
        setLastError(tr("Enter API credentials first"));
        return false;
    }

    if (trimmedId.isEmpty()) {
        setLastError(tr("Select a watchlist"));
        return false;
    }

    if (trimmedName.isEmpty()) {
        setLastError(tr("Enter a watchlist name"));
        return false;
    }

    setBusy(true);
    m_watchlistService.renameWatchlist(trimmedId,
                                       trimmedName,
                                       m_cachedApiKey,
                                       m_cachedUserKey);
    return true;
}

bool EtoroClient::deleteWatchlist(const QString &watchlistId)
{
    const QString trimmedId = watchlistId.trimmed();

    if (m_locked) {
        setLastError(tr("Unlock the app first"));
        return false;
    }

    if (!hasCredentials()) {
        setLastError(tr("Enter API credentials first"));
        return false;
    }

    if (trimmedId.isEmpty()) {
        setLastError(tr("Select a watchlist"));
        return false;
    }

    setBusy(true);
    m_watchlistService.deleteWatchlist(trimmedId, m_cachedApiKey, m_cachedUserKey);
    return true;
}

bool EtoroClient::removeInstrumentFromWatchlist(const QString &watchlistId, const QVariantMap &instrument)
{
    if (m_locked) {
        setLastError(tr("Unlock the app first"));
        return false;
    }

    if (!hasCredentials()) {
        setLastError(tr("Enter API credentials first"));
        return false;
    }

    if (watchlistId.trimmed().isEmpty()) {
        setLastError(tr("Missing watchlist ID"));
        return false;
    }

    if (instrument.value(QStringLiteral("instrumentId")).toInt() <= 0) {
        setLastError(tr("Missing instrument ID"));
        return false;
    }

    setBusy(true);
    m_watchlistService.removeInstrumentFromWatchlist(watchlistId.trimmed(),
                                                     instrument,
                                                     m_cachedApiKey,
                                                     m_cachedUserKey);
    return true;
}

void EtoroClient::rebuildGroupedOpenPositions()
{
    QMap<QString, QVariantMap> grouped;

    for (const QVariant &v : m_openPositions) {
        const QVariantMap pos = v.toMap();
        const QString key = groupingKeyForPosition(pos);

        QVariantMap g = grouped.value(key);

        const double invested = pos.value("invested").toDouble();
        const double netProfit = pos.value("netProfit").toDouble();
        const double units = pos.value("units").toDouble();
        const double openRate = pos.value("openRate").toDouble();
        const double exposure = pos.value("exposureInAccountCurrency").toDouble();

        QVariantList children = g.value("positions").toList();
        children.append(pos);
        g["positions"] = children;

        if (!g.contains("groupKey")) {
            g["groupKey"] = key;
            g["instrumentId"] = pos.value("instrumentId");
            g["symbol"] = pos.value("symbol");
            g["displayName"] = pos.value("displayName");
            g["currentRate"] = pos.value("currentRate");

            g["instrumentTypeId"] = pos.value("instrumentTypeId");
            g["exchangeId"] = pos.value("exchangeId");
            g["priceSource"] = pos.value("priceSource");
            g["isBuyEnabled"] = pos.value("isBuyEnabled");
            g["isCurrentlyTradable"] = pos.value("isCurrentlyTradable");
            g["isExchangeOpen"] = pos.value("isExchangeOpen");
            g["tradingDisabled"] = pos.value("tradingDisabled");

            g["positionCount"] = 0;
            g["invested"] = 0.0;
            g["netProfit"] = 0.0;
            g["units"] = 0.0;
            g["exposureInAccountCurrency"] = 0.0;
            g["weightedOpenRateSum"] = 0.0;
        }

        if (pos.contains("isBuyEnabled"))
            g["isBuyEnabled"] = pos.value("isBuyEnabled");
        if (pos.contains("isCurrentlyTradable"))
            g["isCurrentlyTradable"] = pos.value("isCurrentlyTradable");
        if (pos.contains("isExchangeOpen"))
            g["isExchangeOpen"] = pos.value("isExchangeOpen");
        if (pos.contains("tradingDisabled"))
            g["tradingDisabled"] = pos.value("tradingDisabled");

        g["positionCount"] = g.value("positionCount").toInt() + 1;
        g["invested"] = g.value("invested").toDouble() + invested;
        g["netProfit"] = g.value("netProfit").toDouble() + netProfit;
        g["units"] = g.value("units").toDouble() + units;
        g["exposureInAccountCurrency"] = g.value("exposureInAccountCurrency").toDouble() + exposure;
        g["weightedOpenRateSum"] = g.value("weightedOpenRateSum").toDouble() + (openRate * units);

        const QString existingOldest = g.value("oldestOpenDate").toString();
        const QString existingLatest = g.value("latestOpenDate").toString();
        QString opened = pos.value("openDateTime").toString();
        // Fall back to "openDate" if "openDateTime" is not provided
        if (opened.isEmpty())
            opened = pos.value("openDate").toString();

        if (existingOldest.isEmpty() || opened < existingOldest)
            g["oldestOpenDate"] = opened;
        if (existingLatest.isEmpty() || opened > existingLatest)
            g["latestOpenDate"] = opened;

        applyInstrumentRestrictions(g);
        grouped[key] = g;
    }

    QVariantList out;
    for (auto it = grouped.constBegin(); it != grouped.constEnd(); ++it) {
        QVariantMap g = it.value();
        const double units = g.value("units").toDouble();
        const double invested = g.value("invested").toDouble();
        const double netProfit = g.value("netProfit").toDouble();

        g["averageOpenRate"] = units > 0.0
                ? g.value("weightedOpenRateSum").toDouble() / units
                : 0.0;
        g["netValue"] = invested + netProfit;
        g.remove("weightedOpenRateSum");

        out.append(g);
    }

    std::sort(out.begin(), out.end(), [](const QVariant &a, const QVariant &b) {
        return positionLessThan(a.toMap(), b.toMap());
    });

for (const QVariant &v : out) {
    const QVariantMap g = v.toMap();
    if (m_debugLoggingEnabled)
        qWarning() << "GROUPED POSITION DEBUG"
                   << "instrumentId=" << g.value("instrumentId")
                   << "displayName=" << g.value("displayName")
                   << "positionCount=" << g.value("positionCount")
                   << "invested=" << g.value("invested")
                   << "positionsChildren=" << g.value("positions").toList().size();
}

    m_groupedOpenPositions = out;
}

QString EtoroClient::groupingKeyForPosition(const QVariantMap &position)
{
    const QString instrumentId = position.value("instrumentId").toString();
    if (!instrumentId.isEmpty())
        return instrumentId;

    const QString symbol = position.value("symbol").toString();
    if (!symbol.isEmpty())
        return symbol;

    return position.value("displayName").toString();
}

QVariantList EtoroClient::topGroupedPositions() const
{
    QVariantList sorted = m_groupedOpenPositions;

    std::sort(sorted.begin(), sorted.end(), [](const QVariant &a, const QVariant &b) {
        const QVariantMap am = a.toMap();
        const QVariantMap bm = b.toMap();

        const double ap = am.value("netProfit").toDouble();
        const double bp = bm.value("netProfit").toDouble();

        return ap > bp;
    });

    while (sorted.size() > 4)
        sorted.removeLast();

    return sorted;
}

QVariantList EtoroClient::topPositions() const
{
    QVariantList sorted = m_openPositions;

    std::sort(sorted.begin(), sorted.end(), [](const QVariant &a, const QVariant &b) {
        const QVariantMap am = a.toMap();
        const QVariantMap bm = b.toMap();
        const double ap = am.value("netProfit").toDouble();
        const double bp = bm.value("netProfit").toDouble();
        return ap > bp; // highest unrealized P/L first
    });

    while (sorted.size() > 5)
        sorted.removeLast();

    return sorted;
}

void EtoroClient::refreshPositionsQuotes()
{
    if (m_locked || !hasCredentials()) {
        m_positionsQuotes.clear();
        m_positionsQuotesLoading = false;
        emit positionsQuotesChanged();
        return;
    }

    const QList<int> ids = currentInstrumentIds();
    if (ids.isEmpty()) {
        m_positionsQuotes.clear();
        m_positionsQuotesLoading = false;
        emit positionsQuotesChanged();
        return;
    }

    m_positionsQuotesLoading = true;
    emit positionsQuotesChanged();

    m_ratesTarget = RatesPositions;
    m_marketService.fetchInstrumentRates(ids,
                                         m_cachedApiKey,
                                         m_cachedUserKey);
}

bool EtoroClient::pinEnabled() const
{
    return m_tokenStore.pinEnabled();
}

bool EtoroClient::lockOnBackground() const
{
    return m_settings.value(KEY_LOCK_ON_BACKGROUND, true).toBool();
}

int EtoroClient::autoLockMinutes() const
{
    return m_settings.value(KEY_AUTO_LOCK_MINUTES, 2).toInt();
}

QList<int> EtoroClient::currentWatchlistInstrumentIds() const
{
    QList<int> ids;
    QSet<int> seen;

    for (const QVariant &v : m_currentWatchlistItems) {
        const int id = v.toMap().value("instrumentId").toInt();
        if (id > 0 && !seen.contains(id)) {
            seen.insert(id);
            ids.append(id);
        }
    }

    return ids;
}

QVariantMap EtoroClient::quoteForPositionInstrument(const QVariant &instrumentId) const
{
    return m_positionsQuotes.value(instrumentId.toString()).toMap();
}

QVariantMap EtoroClient::quoteForWatchlistInstrument(const QVariant &instrumentId) const
{
    const QString key = instrumentId.toString();
    if (key.isEmpty())
        return QVariantMap();

    return m_currentWatchlistQuotes.value(key).toMap();
}

bool EtoroClient::currentWatchlistContainsInstrument(const QVariant &instrumentId) const
{
    const int wantedId = instrumentId.toInt();
    if (wantedId <= 0)
        return false;

    for (const QVariant &itemVar : m_currentWatchlistItems) {
        const QVariantMap item = itemVar.toMap();

        const int itemId = item.value(QStringLiteral("instrumentId")).toInt();
        if (itemId == wantedId)
            return true;

        const int rawItemId = item.value(QStringLiteral("itemId")).toInt();
        if (rawItemId == wantedId)
            return true;
    }

    return false;
}

QVariantMap EtoroClient::currentWatchlistItemForInstrument(const QVariant &instrumentId) const
{
    const int wantedId = instrumentId.toInt();
    if (wantedId <= 0)
        return QVariantMap();

    for (const QVariant &itemVar : m_currentWatchlistItems) {
        const QVariantMap item = itemVar.toMap();

        const int itemId = item.value(QStringLiteral("instrumentId")).toInt();
        const int rawItemId = item.value(QStringLiteral("itemId")).toInt();

        if (itemId == wantedId || rawItemId == wantedId)
            return item;
    }

    return QVariantMap();
}

void EtoroClient::loadNextWatchlistForInstrumentLookup()
{
    if (!m_watchlistLookupActive)
        return;

    if (m_watchlistLookupQueue.isEmpty()) {
        m_watchlistLookupActive = false;

        if (!m_instrumentWatchlistMatches.isEmpty()) {
            QList<int> ids;
            ids << m_watchlistLookupInstrumentId;

            m_metadataTarget = MetadataWatchlistLookup;
            m_marketService.fetchInstrumentMetadata(ids, m_cachedApiKey, m_cachedUserKey);
            return;
        }

        emit instrumentWatchlistMatchesChanged();
        return;
    }

    const QVariantMap wl = m_watchlistLookupQueue.takeFirst().toMap();

    const QString watchlistId = wl.value(QStringLiteral("watchlistId")).toString();
    const QString watchlistName = wl.value(QStringLiteral("name")).toString();

    if (watchlistId.isEmpty()) {
        loadNextWatchlistForInstrumentLookup();
        return;
    }

    m_pendingLookupWatchlistId = watchlistId;
    m_pendingLookupWatchlistName = watchlistName;

    m_watchlistService.fetchWatchlist(watchlistId,
                                      m_cachedApiKey,
                                      m_cachedUserKey);
}

void EtoroClient::loadInstrumentQuote(const QVariantMap &instrumentData)
{
    registerUserActivity();

    const int instrumentId = instrumentData.value("instrumentId").toInt();
    if (instrumentId <= 0) {
        m_selectedInstrumentQuoteLoading = false;
        emit selectedInstrumentQuoteChanged();
        return;
    }

    if (m_locked) {
        setLastError(QStringLiteral("Unlock the app first."));
        return;
    }

    if (!hasCredentials()) {
        setLastError(QStringLiteral("API credentials are not configured."));
        return;
    }

    m_selectedInstrumentQuoteLoading = true;
    emit selectedInstrumentQuoteChanged();

    m_ratesTarget = RatesSelectedInstrument;
    m_marketService.fetchInstrumentRates(QList<int>() << instrumentId,
                                         m_cachedApiKey,
                                         m_cachedUserKey);
}

QString EtoroClient::quoteRateLimitMessage() const
{
    return m_quoteRateLimitMessage;
}

bool EtoroClient::quoteRefreshCoolingDown() const
{
    return m_quoteRateLimitUntil.isValid()
            && QDateTime::currentDateTimeUtc() < m_quoteRateLimitUntil;
}

int EtoroClient::effectiveQuoteRefreshIntervalSeconds(const QString &pageKind) const
{
    const int user = quoteRefreshIntervalSeconds();
    if (user <= 0)
        return 0;

    if (pageKind == QLatin1String("instrument"))
        return user;

    // Heavy multi-instrument pages
    if (pageKind == QLatin1String("portfolio") || pageKind == QLatin1String("watchlist"))
        return qMax(user, 10);

    return user;
}

void EtoroClient::refreshCurrentWatchlistQuotes()
{
    if (m_locked || !hasCredentials()) {
        m_currentWatchlistQuotes.clear();
        m_currentWatchlistQuotesLoading = false;
        emit currentWatchlistQuotesChanged();
        return;
    }

    const QList<int> ids = currentWatchlistInstrumentIds();
    if (ids.isEmpty()) {
        m_currentWatchlistQuotes.clear();
        m_currentWatchlistQuotesLoading = false;
        emit currentWatchlistQuotesChanged();
        return;
    }

    m_currentWatchlistQuotesLoading = true;
    emit currentWatchlistQuotesChanged();

    m_ratesTarget = RatesWatchlistItems;
    m_marketService.fetchInstrumentRates(ids,
                                         m_cachedApiKey,
                                         m_cachedUserKey);
}

void EtoroClient::clearSelectedInstrumentQuote()
{
    if (m_ratesTarget == RatesSelectedInstrument)
        m_ratesTarget = RatesNone;

    m_selectedInstrumentQuote.clear();
    m_selectedInstrumentQuoteLoading = false;
    emit selectedInstrumentQuoteChanged();
}

void EtoroClient::refreshTradeHistory()
{
    QDateTime nowUtc = QDateTime::currentDateTimeUtc();
    const QString defaultMinDate = nowUtc.addDays(-30).toString(Qt::ISODate);
    refreshTradeHistoryFrom(defaultMinDate);
}

void EtoroClient::refreshTradeHistoryFrom(const QString &minDateIso)
{
    registerUserActivity();

    if (m_locked) {
        setLastError(QStringLiteral("Unlock the app first."));
        return;
    }

    if (!hasCredentials()) {
        setLastError(QStringLiteral("API credentials are not configured."));
        return;
    }

    if (demoMode()) {
        m_tradeHistory.clear();
        m_pendingTradeHistory.clear();
        m_historyMinDate = minDateIso;
        m_historyCurrentPage = 0;
        m_historyPageSize = 100;
        m_historyHasMore = false;
        m_historyLoading = false;

        emit tradeHistoryChanged();
        emit historyUiChanged();

        setBusy(false);
        setOnline(true);
        clearLastError();
        return;
    }

    m_tradeHistory.clear();
    m_pendingTradeHistory.clear();
    m_historyMinDate = minDateIso;
    m_historyCurrentPage = 0;
    m_historyPageSize = 100;
    m_historyHasMore = false;
    m_historyLoading = true;
    emit tradeHistoryChanged();

    setBusy(true);
    setOnline(true);
    setLastError(QString());

    m_historyService.fetchTradeHistory(m_cachedApiKey, m_cachedUserKey, minDateIso, demoMode(), 1, m_historyPageSize);
}

void EtoroClient::loadMoreTradeHistory()
{

    registerUserActivity();

    if (demoMode())
        return;

    if (m_locked || !hasCredentials() || m_busy || !m_historyHasMore || m_historyMinDate.isEmpty())
        return;

    m_historyLoading = true;
    emit tradeHistoryChanged();

    setBusy(true);
    setOnline(true);
    setLastError(QString());

    m_historyService.fetchTradeHistory(m_cachedApiKey, m_cachedUserKey, m_historyMinDate, demoMode(), m_historyCurrentPage + 1, m_historyPageSize);
}

void EtoroClient::refreshWatchlists()
{
    registerUserActivity();

    if (m_locked) {
        setLastError(QStringLiteral("Unlock the app first."));
        return;
    }

    if (!hasCredentials()) {
        setLastError(QStringLiteral("API credentials are not configured."));
        return;
    }

    setBusy(true);
    setOnline(true);
    setLastError(QString());

    m_currentWatchlistItems.clear();
    m_pendingWatchlistItems.clear();
    m_currentWatchlistQuotes.clear();
    m_watchlistItemsLoading = false;

    emit currentWatchlistItemsChanged();
    emit currentWatchlistQuotesChanged();

    m_watchlistService.fetchWatchlists(m_cachedApiKey,
                                       m_cachedUserKey);
}

void EtoroClient::loadWatchlist(const QString &watchlistId, const QString &watchlistName)
{
    registerUserActivity();

    if (m_locked) {
        setLastError(QStringLiteral("Unlock the app first."));
        return;
    }

    if (!hasCredentials()) {
        setLastError(QStringLiteral("API credentials are not configured."));
        return;
    }

    m_currentWatchlistItems.clear();
    m_pendingWatchlistItems.clear();
    m_currentWatchlistName = watchlistName;
    m_watchlistItemsLoading = true;
    m_currentWatchlistQuotes.clear();
    m_currentWatchlistQuotesLoading = false;
    emit currentWatchlistQuotesChanged();
    emit currentWatchlistItemsChanged();

    setBusy(true);
    setOnline(true);
    setLastError(QString());

    m_watchlistService.fetchWatchlist(watchlistId,
                                      m_cachedApiKey,
                                      m_cachedUserKey);
}

void EtoroClient::refreshPortfolio()
{
    registerUserActivity();

    if (m_locked) {
        setLastError(QStringLiteral("Unlock the app first."));
        return;
    }

    if (!hasCredentials()) {
        setLastError(QStringLiteral("API credentials are not configured."));
        return;
    }

    setBusy(true);
    setOnline(true);
    setLastError(QString());

    m_portfolioService.fetchPortfolioSummary(m_cachedApiKey,
                                             m_cachedUserKey,
                                             accountModePathSegment());
}

void EtoroClient::saveCredentials(const QString &apiKey, const QString &userKey)
{
    saveApiKey(apiKey);
    saveUserKeyForMode(demoMode(), userKey);
}

void EtoroClient::clearCredentials()
{
    registerUserActivity();

    if (!m_tokenStore.clearAll()) {
        setLastError(QStringLiteral("Failed to clear stored data: ") + m_tokenStore.lastError());
        return;
    }

    clearCachedCredentials();

    m_portfolioSummary.clear();
    m_openPositions.clear();
    m_watchlists.clear();
    m_currentWatchlistItems.clear();
    m_pendingWatchlistItems.clear();
    m_currentWatchlistName.clear();
    m_watchlistItemsLoading = false;

    m_tradeHistory.clear();
    m_pendingTradeHistory.clear();
    m_historyMinDate.clear();
    m_historyCurrentPage = 0;
    m_historyPageSize = 100;
    m_historyHasMore = false;
    m_historyLoading = false;

    m_selectedInstrumentQuote.clear();
    m_selectedInstrumentQuoteLoading = false;

    m_currentWatchlistQuotes.clear();
    m_currentWatchlistQuotesLoading = false;

    m_positionsQuotes.clear();
    m_positionsQuotesLoading = false;

    emit credentialsChanged();
    emit portfolioSummaryChanged();
    emit openPositionsChanged();
    emit watchlistsChanged();
    emit currentWatchlistItemsChanged();
    emit pinChanged();
    emit tradeHistoryChanged();
    emit currentWatchlistQuotesChanged();
    emit positionsQuotesChanged();

    setLocked(false);
    stopInactivityTimer();
    setLastError(QStringLiteral("Stored credentials cleared."));
}

QString EtoroClient::apiKeyPreview() const
{
    const QString v = m_tokenStore.apiKey();
    if (v.length() <= 8)
        return v;
    return v.left(4) + QStringLiteral("…") + v.right(4);
}

QString EtoroClient::userKeyPreview() const
{
    const QString v = m_tokenStore.userKeyForMode(demoMode());
    if (v.length() <= 8)
        return v;
    return v.left(4) + QStringLiteral("…") + v.right(4);
}

bool EtoroClient::setPin(const QString &pin)
{
    registerUserActivity();

    const QString cleaned = pin.trimmed();
    if (cleaned.isEmpty()) {
        setPinSettingsError(QStringLiteral("PIN cannot be empty."));
        return false;
    }

    // Be defensive: if a PIN is already marked as present, clear it first.
    if (m_tokenStore.pinEnabled()) {
        if (!m_tokenStore.clearPin()) {
            setPinSettingsError(QStringLiteral("Failed to replace existing PIN: ") + m_tokenStore.lastError());
            return false;
        }
    }

    if (!m_tokenStore.setPin(cleaned)) {
        setPinSettingsError(QStringLiteral("Failed to save PIN: ") + m_tokenStore.lastError());
        return false;
    }

    setPinSettingsError(QString());
    emit pinChanged();
    setLocked(true);
    return true;
}

bool EtoroClient::changePin(const QString &currentPin, const QString &newPin)
{
    registerUserActivity();

    if (!m_tokenStore.pinEnabled()) {
        setPinSettingsError(QStringLiteral("No PIN is currently set."));
        return false;
    }

    if (currentPin != m_tokenStore.pin()) {
        setPinSettingsError(QStringLiteral("Current PIN is incorrect."));
        return false;
    }

    const QString cleaned = newPin.trimmed();
    if (cleaned.isEmpty()) {
        setPinSettingsError(QStringLiteral("New PIN cannot be empty."));
        return false;
    }

    if (!m_tokenStore.setPin(cleaned)) {
        setPinSettingsError(QStringLiteral("Failed to change PIN: ") + m_tokenStore.lastError());
        return false;
    }

    setPinSettingsError(QString());
    emit pinChanged();
    setLocked(true);
    return true;
}

bool EtoroClient::removePin(const QString &currentPin)
{
    registerUserActivity();

    if (!m_tokenStore.pinEnabled()) {
        setPinSettingsError(QStringLiteral("No PIN is currently set."));
        return false;
    }

    if (currentPin != m_tokenStore.pin()) {
        setPinSettingsError(QStringLiteral("Current PIN is incorrect."));
        return false;
    }

    if (!m_tokenStore.clearPin()) {
        setPinSettingsError(QStringLiteral("Failed to remove PIN: ") + m_tokenStore.lastError());
        return false;
    }

    setPinSettingsError(QString());
    emit pinChanged();
    setLocked(false);
    stopInactivityTimer();
    return true;
}

bool EtoroClient::verifyPin(const QString &pin) const
{
    if (!m_tokenStore.pinEnabled())
        return true;

    return pin == m_tokenStore.pin();
}

bool EtoroClient::unlockWithPin(const QString &pin)
{
    if (!m_tokenStore.pinEnabled()) {
        setLocked(false);
        reloadCachedCredentials();
        emit credentialsChanged();
        emit accountModeChanged();
        resetInactivityTimer();

        if (hasCredentials() && m_openPositions.isEmpty() && !m_busy)
            refreshPortfolio();

        return true;
    }

    if (verifyPin(pin)) {
        const bool wasLocked = m_locked;

        reloadCachedCredentials();
        emit credentialsChanged();
        emit accountModeChanged();

        setLastError(QString());
        setLocked(false);
        resetInactivityTimer();

        if (wasLocked
                && hasCredentials()
                && !m_busy
                && (m_portfolioSummary.isEmpty() || m_openPositions.isEmpty())) {
            refreshPortfolio();
        }

        return true;
    }

    setLastError(QStringLiteral("Incorrect PIN."));
    return false;
}

void EtoroClient::lockNow()
{
    if (m_tokenStore.pinEnabled()) {
        setLocked(true);
        stopInactivityTimer();
    }
}

void EtoroClient::setLockOnBackground(bool value)
{
    if (lockOnBackground() == value)
        return;

    m_settings.setValue(KEY_LOCK_ON_BACKGROUND, value);
    m_settings.sync();
    emit lockSettingsChanged();
}

void EtoroClient::setAutoLockMinutes(int minutes)
{
    if (minutes < 0)
        minutes = 0;

    if (autoLockMinutes() == minutes)
        return;

    m_settings.setValue(KEY_AUTO_LOCK_MINUTES, minutes);
    m_settings.sync();
    emit lockSettingsChanged();
    resetInactivityTimer();
}

void EtoroClient::registerUserActivity()
{
    if (m_locked)
        return;

    resetInactivityTimer();
}

void EtoroClient::maybeLockForBackground()
{
    if (lockOnBackground())
        lockNow();
}

void EtoroClient::setBusy(bool value)
{
    if (m_busy == value)
        return;
    m_busy = value;
    emit busyChanged();
}

void EtoroClient::setLocked(bool value)
{
    if (m_locked == value)
        return;

    const bool wasLocked = m_locked;
    m_locked = value;

    if (!m_locked)
        reloadCachedCredentials();

    emit lockedChanged();
    emit credentialsChanged();
    emit accountModeChanged();

    if (m_locked) {
        stopInactivityTimer();
    } else {
        resetInactivityTimer();

        if (wasLocked
                && hasCredentials()
                && !m_busy
                && (m_portfolioSummary.isEmpty() || m_openPositions.isEmpty())) {
            refreshPortfolio();
        }
    }
}

void EtoroClient::setOnline(bool value)
{
    if (m_online == value)
        return;
    m_online = value;
    emit onlineChanged();
}

void EtoroClient::setPinSettingsError(const QString &value)
{
    if (m_pinSettingsError == value)
        return;
    m_pinSettingsError = value;
    emit pinSettingsErrorChanged();
}

void EtoroClient::clearPinSettingsError()
{
    setPinSettingsError(QString());
}

void EtoroClient::setLastError(const QString &value)
{
    if (m_lastError == value)
        return;
    m_lastError = value;
    emit lastErrorChanged();
}

void EtoroClient::enrichPendingTradeHistory(const QVariantMap &metadataById)
{
    for (int i = 0; i < m_pendingTradeHistory.size(); ++i) {
        QVariantMap trade = m_pendingTradeHistory.at(i).toMap();
        const QString id = trade.value("instrumentId").toString();
        const QVariantMap meta = metadataById.value(id).toMap();

        const QString displayName = meta.value("displayName").toString().trimmed();
        const QString symbol = meta.value("symbol").toString().trimmed();

        if (!displayName.isEmpty())
            trade.insert("displayName", displayName);
        if (!symbol.isEmpty())
            trade.insert("symbol", symbol);

        trade.insert("instrumentTypeId", meta.value("instrumentTypeId"));
        trade.insert("exchangeId", meta.value("exchangeId"));
        trade.insert("priceSource", meta.value("priceSource"));
        trade.insert("isBuyEnabled", meta.value("isBuyEnabled"));
        trade.insert("isCurrentlyTradable", meta.value("isCurrentlyTradable"));
        trade.insert("isExchangeOpen", meta.value("isExchangeOpen"));
        trade.insert("tradingDisabled", meta.value("tradingDisabled"));
        applyInstrumentRestrictions(trade);

        m_pendingTradeHistory[i] = trade;
    }
}

QList<int> EtoroClient::pendingTradeHistoryInstrumentIds() const
{
    QList<int> ids;
    QSet<int> seen;

    for (const QVariant &v : m_pendingTradeHistory) {
        const int id = v.toMap().value("instrumentId").toInt();
        if (id > 0 && !seen.contains(id)) {
            seen.insert(id);
            ids.append(id);
        }
    }

    return ids;
}

bool EtoroClient::tradeHistoryNewerThan(const QVariantMap &a, const QVariantMap &b)
{
    const QString as = a.value("closeTimestamp").toString();
    const QString bs = b.value("closeTimestamp").toString();
    return as > bs;
}

void EtoroClient::enrichPendingWatchlistItems(const QVariantMap &metadataById)
{
    for (int i = 0; i < m_pendingWatchlistItems.size(); ++i) {
        QVariantMap item = m_pendingWatchlistItems.at(i).toMap();
        const QString id = item.value("instrumentId").toString();
        const QVariantMap meta = metadataById.value(id).toMap();

        const QString displayName = meta.value("displayName").toString().trimmed();
        const QString symbol = meta.value("symbol").toString().trimmed();

        if (!displayName.isEmpty())
            item.insert("displayName", displayName);
        if (!symbol.isEmpty())
            item.insert("symbol", symbol);

        item.insert("instrumentTypeId", meta.value("instrumentTypeId"));
        item.insert("exchangeId", meta.value("exchangeId"));
        item.insert("priceSource", meta.value("priceSource"));
        item.insert("isBuyEnabled", meta.value("isBuyEnabled"));
        item.insert("isCurrentlyTradable", meta.value("isCurrentlyTradable"));
        item.insert("isExchangeOpen", meta.value("isExchangeOpen"));
        item.insert("tradingDisabled", meta.value("tradingDisabled"));
        applyInstrumentRestrictions(item);

        m_pendingWatchlistItems[i] = item;
    }
}

QList<int> EtoroClient::pendingWatchlistInstrumentIds() const
{
    QList<int> ids;
    QSet<int> seen;

    for (const QVariant &v : m_pendingWatchlistItems) {
        const int id = v.toMap().value("instrumentId").toInt();
        if (id > 0 && !seen.contains(id)) {
            seen.insert(id);
            ids.append(id);
        }
    }

    return ids;
}

void EtoroClient::enrichOpenPositions(const QVariantMap &metadataById)
{
    for (int i = 0; i < m_openPositions.size(); ++i) {
        QVariantMap pos = m_openPositions.at(i).toMap();
        const QString id = pos.value("instrumentId").toString();
        const QVariantMap meta = metadataById.value(id).toMap();

        const QString displayName = meta.value("displayName").toString().trimmed();
        const QString symbol = meta.value("symbol").toString().trimmed();

        if (!displayName.isEmpty())
            pos.insert("displayName", displayName);
        if (!symbol.isEmpty())
            pos.insert("symbol", symbol);

        pos.insert("instrumentTypeId", meta.value("instrumentTypeId"));
        pos.insert("exchangeId", meta.value("exchangeId"));
        pos.insert("priceSource", meta.value("priceSource"));
        pos.insert("isBuyEnabled", meta.value("isBuyEnabled"));
        pos.insert("isCurrentlyTradable", meta.value("isCurrentlyTradable"));
        pos.insert("isExchangeOpen", meta.value("isExchangeOpen"));
        pos.insert("tradingDisabled", meta.value("tradingDisabled"));
        applyInstrumentRestrictions(pos);

        m_openPositions[i] = pos;
    }
}

QList<int> EtoroClient::currentInstrumentIds() const
{
    QList<int> ids;
    QSet<int> seen;

    for (const QVariant &v : m_openPositions) {
        const int id = v.toMap().value("instrumentId").toInt();
        if (id > 0 && !seen.contains(id)) {
            seen.insert(id);
            ids.append(id);
        }
    }

    return ids;
}

bool EtoroClient::positionLessThan(const QVariantMap &a, const QVariantMap &b)
{
    return a.value("invested").toDouble() > b.value("invested").toDouble();
}

void EtoroClient::resetInactivityTimer()
{
    if (!m_tokenStore.pinEnabled() || m_locked) {
        m_inactivityTimer.stop();
        return;
    }

    const int minutes = autoLockMinutes();
    if (minutes <= 0) {
        m_inactivityTimer.stop();
        return;
    }

    m_inactivityTimer.start(minutes * 60 * 1000);
}

void EtoroClient::stopInactivityTimer()
{
    m_inactivityTimer.stop();
}

bool EtoroClient::prepareMarketOrder(const QVariantMap &order)
{
    if (!tradingEnabled()) {
        setLastError(tr("Trading mode is disabled"));
        return false;
    }

    if (m_locked) {
        setLastError(tr("Unlock the app first"));
        return false;
    }

    const int instrumentId = order.value("instrumentId").toInt();
    const bool byAmount = order.value("byAmount").toBool();
    const double amount = order.value("amount").toDouble();
    const double units = order.value("units").toDouble();
    const int leverage = order.value("leverage").toInt();

    if (instrumentId <= 0) {
        setLastError(tr("Missing instrument"));
        return false;
    }

    if (leverage < 1) {
        setLastError(tr("Invalid leverage"));
        return false;
    }

    if (byAmount && amount <= 0.0) {
        setLastError(tr("Invalid amount"));
        return false;
    }

    if (!byAmount && units <= 0.0) {
        setLastError(tr("Invalid units"));
        return false;
    }

    qDebug() << "Prepared market order"
             << "instrumentId=" << instrumentId
             << "byAmount=" << byAmount
             << "amount=" << amount
             << "units=" << units
             << "leverage=" << leverage
             << "stopLoss=" << order.value("stopLoss").toString()
             << "takeProfit=" << order.value("takeProfit").toString();

    const bool dryRun = !liveOrderSubmissionEnabled();

    setBusy(true);
    m_tradingService.openMarketOrder(
                order,
                m_cachedApiKey,
                m_cachedUserKey,
                accountModePathSegment(),
                dryRun);

    return true;
}

bool EtoroClient::closePosition(const QVariantMap &position, const QString &unitsToDeduct)
{
    if (!tradingEnabled()) {
        setLastError(tr("Trading mode is disabled"));
        return false;
    }

    if (m_locked) {
        setLastError(tr("Unlock the app first"));
        return false;
    }

    const QString positionId = position.value(QStringLiteral("positionId")).toString();
    const int instrumentId = position.value(QStringLiteral("instrumentId")).toInt();

    if (positionId.isEmpty()) {
        setLastError(tr("Missing position ID"));
        return false;
    }

    if (instrumentId <= 0) {
        setLastError(tr("Missing instrument"));
        return false;
    }

    const QString trimmedUnits = unitsToDeduct.trimmed();

    if (!trimmedUnits.isEmpty()) {
        bool ok = false;
        const double units = trimmedUnits.toDouble(&ok);

        if (!ok || units <= 0.0) {
            setLastError(tr("Enter a valid number of units to close"));
            return false;
        }

        const double currentUnits = position.value(QStringLiteral("units")).toDouble();
        if (currentUnits > 0.0 && units >= currentUnits) {
            setLastError(tr("Partial close units must be less than current position units"));
            return false;
        }
    }

    qDebug() << "Prepared close position"
             << "positionId=" << positionId
             << "instrumentId=" << instrumentId;

    const bool dryRun = !liveOrderSubmissionEnabled();

    setBusy(true);
    m_tradingService.closeMarketPosition(position,
                                         trimmedUnits,
                                         m_cachedApiKey,
                                         m_cachedUserKey,
                                         accountModePathSegment(),
                                         dryRun);
    return true;
}

bool EtoroClient::updatePositionProtection(const QVariantMap &position, const QVariantMap &protection)
{
    if (!tradingEnabled()) {
        setLastError(tr("Trading mode is disabled"));
        return false;
    }

    if (m_locked) {
        setLastError(tr("Unlock the app first"));
        return false;
    }

    const QString positionId = position.value(QStringLiteral("positionId")).toString();
    if (positionId.isEmpty()) {
        setLastError(tr("Missing position ID"));
        return false;
    }

    const QString stopLoss = protection.value(QStringLiteral("stopLoss")).toString().trimmed();
    const QString takeProfit = protection.value(QStringLiteral("takeProfit")).toString().trimmed();

    if (stopLoss.isEmpty() && takeProfit.isEmpty()) {
        setLastError(tr("Enter Stop Loss or Take Profit"));
        return false;
    }

    qDebug() << "Prepared update position protection"
             << "positionId=" << positionId
             << "stopLoss=" << stopLoss
             << "takeProfit=" << takeProfit;

    const bool dryRun = !liveOrderSubmissionEnabled();

    setBusy(true);
    m_tradingService.updatePositionProtection(position,
                                              protection,
                                              m_cachedApiKey,
                                              m_cachedUserKey,
                                              dryRun);
    return true;
}

QString EtoroClient::realUserKey() const
{
    return m_locked ? QString() : m_tokenStore.realUserKey();
}

QString EtoroClient::demoUserKey() const
{
    return m_locked ? QString() : m_tokenStore.demoUserKey();
}

bool EtoroClient::hasRealCredentials() const
{
    return m_tokenStore.hasCredentialsForMode(false);
}

bool EtoroClient::hasDemoCredentials() const
{
    return m_tokenStore.hasCredentialsForMode(true);
}

void EtoroClient::saveApiKey(const QString &apiKey)
{
    registerUserActivity();

    if (!m_tokenStore.saveApiKey(apiKey)) {
        setLastError(QStringLiteral("Failed to save API key: ") + m_tokenStore.lastError());
        return;
    }

    reloadCachedCredentials();
    emit credentialsChanged();
    setLastError(QString());
}

void EtoroClient::saveUserKeyForMode(bool demo, const QString &userKey)
{
    registerUserActivity();

    const bool ok = demo
            ? m_tokenStore.saveDemoUserKey(userKey)
            : m_tokenStore.saveRealUserKey(userKey);

    if (!ok) {
        setLastError(QStringLiteral("Failed to save user key: ") + m_tokenStore.lastError());
        return;
    }

    if (demo == demoMode())
        reloadCachedCredentials();

    emit credentialsChanged();
    setLastError(QString());
}

void EtoroClient::clearUserKeyForMode(bool demo)
{
    registerUserActivity();

    const bool ok = demo
            ? m_tokenStore.clearDemoUserKey()
            : m_tokenStore.clearRealUserKey();

    if (!ok) {
        setLastError(QStringLiteral("Failed to clear user key: ") + m_tokenStore.lastError());
        return;
    }

    if (demo == demoMode()) {
        clearCachedCredentials();

        m_portfolioSummary.clear();
        m_openPositions.clear();
        m_groupedOpenPositions.clear();
        m_positionsQuotes.clear();
        m_tradeHistory.clear();

        emit portfolioSummaryChanged();
        emit openPositionsChanged();
        emit groupedOpenPositionsChanged();
        emit positionsQuotesChanged();
        emit tradeHistoryChanged();

        reloadCachedCredentials();
    }

    emit credentialsChanged();
    setLastError(QString());
}

QString EtoroClient::accountModeLabel() const
{
    return demoMode() ? tr("Virtual") : tr("Real");
}
