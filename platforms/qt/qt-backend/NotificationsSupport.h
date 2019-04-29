#ifndef NOTIFICATIONSSUPPORT_H
#define NOTIFICATIONSSUPPORT_H

#include <QObject>

#ifdef QT_GUI_LIB
#include <QSystemTrayIcon>
#include <QTimerEvent>
#include <QHash>
#endif

#include "core/ByteCodeRunner.h"
#include "utils/AbstractNotificationsSupport.h"

class QtNotificationsSupport : public QObject, public AbstractNotificationsSupport
{
    Q_OBJECT

#ifdef QT_GUI_LIB
    struct NotificationInfo
    {
        int timerId;
        std::string notificationCallbackArgs;
        std::string notificationTitle;
        std::string notificationText;

        NotificationInfo(int timerId, std::string notificationCallbackArgs, std::string notificationTitle, std::string notificationText)
            : timerId(timerId), notificationCallbackArgs(notificationCallbackArgs),
              notificationTitle(notificationTitle), notificationText(notificationText) {
        }
    };

    QHash<int, int> scheduledTimers; // timerId -> notificationId mapping
    QHash<int, NotificationInfo> notificationInfo;
    int lastCreatedNotificationId;
    bool cgi;

    void timerEvent(QTimerEvent*);
#endif

public:
    QtNotificationsSupport(ByteCodeRunner* runner, bool cgi);

protected:
    virtual bool doHasPermissionLocalNotification();
    virtual void doRequestPermissionLocalNotification(int cb_root);
    virtual void doScheduleLocalNotification(double time, int notificationId, std::string notificationCallbackArgs, std::string notificationTitle, std::string notificationText, bool withSound, bool pinned);
    virtual void doCancelLocalNotification(int notificationId);

#ifdef QT_GUI_LIB
private slots:
    void trayMessageClicked();
#endif
};

#ifdef QT_GUI_LIB
class SystemTrayIconSingle : public QObject
{
     Q_OBJECT

public:
    static SystemTrayIconSingle& Instance(QtNotificationsSupport *notificationsSupport)
    {
        static SystemTrayIconSingle s(notificationsSupport);
        return s;
    }

    QSystemTrayIcon *const getSystemTray();

private:
    SystemTrayIconSingle() { }
    SystemTrayIconSingle(QtNotificationsSupport *notificationsSupport);
    ~SystemTrayIconSingle() { }

    SystemTrayIconSingle(SystemTrayIconSingle const&);
    SystemTrayIconSingle& operator= (SystemTrayIconSingle const&);

    QSystemTrayIcon *systemTray;
};
#endif

#endif // NOTIFICATIONSSUPPORT_H

