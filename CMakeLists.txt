cmake_minimum_required(VERSION 3.6)

project(harbour-etoro LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
find_package(Qt5 COMPONENTS Core Network Qml Quick REQUIRED)

pkg_check_modules(SAILFISHAPP REQUIRED sailfishapp)
pkg_check_modules(SAILFISHSECRETS REQUIRED sailfishsecrets)

include_directories(
    ${Qt5Core_INCLUDE_DIRS}
    ${Qt5Network_INCLUDE_DIRS}
    ${Qt5Qml_INCLUDE_DIRS}
    ${Qt5Quick_INCLUDE_DIRS}
    ${SAILFISHAPP_INCLUDE_DIRS}
    ${SAILFISHSECRETS_INCLUDE_DIRS}
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/services
)

link_directories(
    ${SAILFISHAPP_LIBRARY_DIRS}
    ${SAILFISHSECRETS_LIBRARY_DIRS}
)

set(SOURCES
    src/main.cpp
    src/etoroclient.cpp
    src/tokenstore.cpp
    src/networkutils.cpp
    src/applog.cpp
    src/services/etoroportfolioservice.cpp
    src/services/etoromarketservice.cpp
    src/services/etorotradingservice.cpp
    src/services/etorowatchlistservice.cpp
    src/services/etorohistoryservice.cpp
)

set(HEADERS
    src/etoroclient.h
    src/tokenstore.h
    src/networkutils.h
    src/applog.h
    src/services/etoroportfolioservice.h
    src/services/etoromarketservice.h
    src/services/etorotradingservice.h
    src/services/etorowatchlistservice.h
    src/services/etorohistoryservice.h
)

set(QML_SOURCES
    qml/harbour-etoro.qml
    qml/pages/MainPage.qml
    qml/pages/SettingsPage.qml
    qml/pages/AboutPage.qml
    qml/components/UnlockOverlay.qml
    qml/components/PinUnlockDialog.qml
    qml/cover/CoverPage.qml
)

set(DESKTOP_FILE harbour-etoro.desktop)
set(APP_ICON icons/172x172/harbour-etoro.png)

add_executable(harbour-etoro
    ${SOURCES}
    ${HEADERS}
)

target_compile_options(harbour-etoro PRIVATE
    ${SAILFISHAPP_CFLAGS_OTHER}
    ${SAILFISHSECRETS_CFLAGS_OTHER}
)

target_link_libraries(harbour-etoro
    Qt5::Core
    Qt5::Network
    Qt5::Qml
    Qt5::Quick
    ${SAILFISHAPP_LIBRARIES}
    ${SAILFISHSECRETS_LIBRARIES}
)

install(TARGETS harbour-etoro
    RUNTIME DESTINATION /usr/bin
)

install(FILES ${DESKTOP_FILE}
    DESTINATION /usr/share/applications
)

install(FILES ${APP_ICON}
    DESTINATION /usr/share/icons/hicolor/172x172/apps
)

#install(FILES ${QML_SOURCES}
#    DESTINATION /usr/share/harbour-etoro/qml
#)
install(FILES
    qml/harbour-etoro.qml
    DESTINATION /usr/share/harbour-etoro/qml
)

install(FILES
    qml/pages/MainPage.qml
    qml/pages/SettingsPage.qml
    qml/pages/AboutPage.qml
    qml/pages/PortfolioPage.qml
    qml/pages/PositionDetailPage.qml
    qml/pages/OpenPositionPage.qml
    qml/pages/WatchlistDetailPage.qml
    qml/pages/WatchlistsPage.qml
    qml/pages/HistoryPage.qml
    qml/pages/TradeDetailPage.qml
    qml/pages/StatisticsPage.qml
    qml/pages/DiscoverPage.qml
    DESTINATION /usr/share/harbour-etoro/qml/pages
)

install(FILES
    qml/components/UnlockOverlay.qml
    qml/components/PriceFlashValue.qml
    qml/components/OpenPositionOverlay.qml
    qml/components/PurchaseSubmittedOverlay.qml
    qml/components/TradePriceActionRow.qml
    qml/components/ClosePositionOverlay.qml
    qml/components/RenameWatchlistOverlay.qml
    qml/components/DeleteWatchlistOverlay.qml
    qml/components/RemoveFromWatchlistOverlay.qml
    qml/components/AddToWatchlistOverlay.qml
    qml/components/HistoryCustomRangeOverlay.qml
    DESTINATION /usr/share/harbour-etoro/qml/components
)

install(FILES
    qml/cover/CoverPage.qml
    DESTINATION /usr/share/harbour-etoro/qml/cover
)
