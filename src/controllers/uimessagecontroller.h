#ifndef UIMESSAGECONTROLLER_H
#define UIMESSAGECONTROLLER_H

#include <QObject>
#include <QString>

class UiMessageController : public QObject
{
    Q_OBJECT
public:
    explicit UiMessageController(QObject *parent = nullptr);

    QString errorMessage() const;
    QString successMessage() const;

    void setErrorMessage(const QString &message);
    void setSuccessMessage(const QString &message);
    void clearErrorMessage();
    void clearSuccessMessage();

signals:
    void errorMessageChanged();
    void successMessageChanged();

private:
    QString m_errorMessage;
    QString m_successMessage;
};

#endif // UIMESSAGECONTROLLER_H
