#include "uimessagecontroller.h"

UiMessageController::UiMessageController(QObject *parent)
    : QObject(parent)
{
}

QString UiMessageController::errorMessage() const
{
    return m_errorMessage;
}

QString UiMessageController::successMessage() const
{
    return m_successMessage;
}

void UiMessageController::setErrorMessage(const QString &message)
{
    if (!message.isEmpty())
        clearSuccessMessage();

    if (m_errorMessage == message)
        return;

    m_errorMessage = message;
    emit errorMessageChanged();
}

void UiMessageController::setSuccessMessage(const QString &message)
{
    if (!message.isEmpty())
        clearErrorMessage();

    if (m_successMessage == message)
        return;

    m_successMessage = message;
    emit successMessageChanged();
}

void UiMessageController::clearErrorMessage()
{
    setErrorMessage(QString());
}

void UiMessageController::clearSuccessMessage()
{
    if (m_successMessage.isEmpty())
        return;

    m_successMessage.clear();
    emit successMessageChanged();
}
