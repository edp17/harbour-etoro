#ifndef APPLOG_H
#define APPLOG_H

class AppLog
{
public:
    static bool debugEnabled();
    static void setDebugEnabled(bool enabled);
};

#endif