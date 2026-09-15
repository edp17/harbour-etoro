#include <sailfishapp.h>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QLocale>
#include <QTranslator>

#include "etoroclient.h"

int main(int argc, char *argv[])
{
    QGuiApplication *app = SailfishApp::application(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("harbour-etoro"));
    QCoreApplication::setApplicationName(QStringLiteral("harbour-etoro"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.7.1"));

    QTranslator translator;
    const QString translationDirectory =
            SailfishApp::pathTo(QStringLiteral("translations")).toLocalFile();
    const QString localeName = QLocale::system().name();
    if (translator.load(QStringLiteral("harbour-etoro_") + localeName,
                        translationDirectory)
            || translator.load(QStringLiteral("harbour-etoro_")
                               + localeName.section(QLatin1Char('_'), 0, 0),
                               translationDirectory)) {
        app->installTranslator(&translator);
    }

    QQuickView *view = SailfishApp::createView();

    EtoroClient client;
    view->rootContext()->setContextProperty("etoroClient", &client);

    view->setSource(SailfishApp::pathTo("qml/harbour-etoro.qml"));
    view->show();

    return app->exec();
}
