#include "NotificationsSupport.h"

#include <QBuffer>

#include "core/RunnerMacros.h"

QtNotificationsSupport::QtNotificationsSupport(ByteCodeRunner *Runner, bool cgi)
    : AbstractNotificationsSupport(Runner), cgi(cgi)
{
#ifdef QT_GUI_LIB
    if (cgi) return;
    lastCreatedNotificationId = -1;
#endif
}

#ifdef QT_GUI_LIB
void QtNotificationsSupport::timerEvent(QTimerEvent *event)
{
    int timerId = event->timerId();
    killTimer(timerId);
    QHash<int, int>::iterator itScheduledTimers = scheduledTimers.find(timerId);
    if (itScheduledTimers != scheduledTimers.end()) {
        QHash<int, NotificationInfo>::iterator itNotificationInfo = notificationInfo.find(itScheduledTimers.value());
        if (itNotificationInfo != notificationInfo.end()) {
            SystemTrayIconSingle::Instance(this).getSystemTray()->showMessage(
                QString::fromUtf8(itNotificationInfo.value().notificationTitle.c_str()),
                QString::fromUtf8(itNotificationInfo.value().notificationText.c_str())
            );
            lastCreatedNotificationId = itScheduledTimers.value();
        }
        scheduledTimers.erase(itScheduledTimers);
    }
}

void QtNotificationsSupport::trayMessageClicked() {
    if (lastCreatedNotificationId != -1) {
        QHash<int, NotificationInfo>::iterator itNotificationInfo = notificationInfo.find(lastCreatedNotificationId);
        if (itNotificationInfo != notificationInfo.end()) {
            executeNotificationCallbacks(lastCreatedNotificationId, itNotificationInfo.value().notificationCallbackArgs);
            notificationInfo.erase(itNotificationInfo);
        }
        lastCreatedNotificationId = -1;
    }
}
#endif

bool QtNotificationsSupport::doHasPermissionLocalNotification() {
#ifdef QT_GUI_LIB
    return !cgi;
#else
    return false;
#endif
}

void QtNotificationsSupport::doRequestPermissionLocalNotification(int cb_root) {
#ifdef QT_GUI_LIB
    executeRequestPermissionLocalNotificationCallback(!cgi, cb_root);
#else
    executeRequestPermissionLocalNotificationCallback(false, cb_root);
#endif

}

void QtNotificationsSupport::doScheduleLocalNotification(double time, int notificationId, std::string notificationCallbackArgs, std::string notificationTitle, std::string notificationText, bool /*withSound*/, bool /*pinned*/) {
#ifdef QT_GUI_LIB
    if (cgi) return;
    doCancelLocalNotification(notificationId);
    int timerId = startTimer(qMax(0.0, time - GetCurrentTime() * 1000.0));
    scheduledTimers.insert(timerId, notificationId);
    notificationInfo.insert(notificationId, NotificationInfo(timerId, notificationCallbackArgs, notificationTitle, notificationText));
#else
	Q_UNUSED(time)
	Q_UNUSED(notificationId)
	Q_UNUSED(notificationCallbackArgs)
	Q_UNUSED(notificationTitle)
	Q_UNUSED(notificationText)
#endif
}

void QtNotificationsSupport::doCancelLocalNotification(int notificationId) {
#ifdef QT_GUI_LIB
    if (cgi) return;
    QHash<int, NotificationInfo>::iterator itNotificationInfo = notificationInfo.find(notificationId);
    if (itNotificationInfo != notificationInfo.end()) {
        QHash<int, int>::iterator itScheduledTimers = scheduledTimers.find(itNotificationInfo.value().timerId);
        if (itScheduledTimers != scheduledTimers.end()) {
            killTimer(itScheduledTimers.key());
            scheduledTimers.erase(itScheduledTimers);
        }
        notificationInfo.erase(itNotificationInfo);
    }
#else
	Q_UNUSED(notificationId)
#endif
}

#ifdef QT_GUI_LIB
SystemTrayIconSingle::SystemTrayIconSingle(QtNotificationsSupport *notificationsSupport) {
    systemTray = new QSystemTrayIcon(QIcon(":/images/app_icon.png"), notificationsSupport);
    // tooltip doesn't work on windows 7. https://bugreports.qt.io/browse/QTBUG-18821
    systemTray->setToolTip("QtByteRunner");
    systemTray->show();
    connect(systemTray, SIGNAL(messageClicked()), notificationsSupport, SLOT(trayMessageClicked()));
}

QSystemTrayIcon * SystemTrayIconSingle::getSystemTray() {
    return systemTray;
}
#endif
