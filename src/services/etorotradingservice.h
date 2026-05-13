#ifndef ETOROTRADINGSERVICE_H
#define ETOROTRADINGSERVICE_H

#include <QObject>

class EtoroTradingService : public QObject
{
    Q_OBJECT
public:
    explicit EtoroTradingService(QObject *parent = nullptr);
};

#endif // ETOROTRADINGSERVICE_H
