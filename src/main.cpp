#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>

#include "etoroclient.h"

int main(int argc, char *argv[])
{
    QGuiApplication *app = SailfishApp::application(argc, argv);
    QQuickView *view = SailfishApp::createView();

    EtoroClient client;
    view->rootContext()->setContextProperty("etoroClient", &client);

    view->setSource(SailfishApp::pathTo("qml/harbour-etoro.qml"));
    view->show();

    return app->exec();
}
