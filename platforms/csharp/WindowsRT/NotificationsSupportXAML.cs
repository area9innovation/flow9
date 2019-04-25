using System;
using System.Diagnostics;

using Windows.System;
using Windows.UI.Notifications;
using Windows.Data.Xml.Dom;

namespace Area9Innovation.Flow
{
	public class NotificationsSupportXAML : NotificationsSupport
	{
		static object no_op() { return null; }

		// No need to ask permission for local notifications on the Windows Phone
		public override bool hasPermissionLocalNotification()
		{
			return true;
		}

		public override object requestPermissionLocalNotification(Func1 cb)
		{
			cb(true);
			return null;
		}

		public override Func0 addOnClickListenerLocalNotification(Func2 cb)
		{
			Debug.WriteLine("addOnClickListenerLocalNotification NOT IMPLEMENTED YET");
			return no_op;
		}

		public override object cancelLocalNotification(int id)
		{
			var notifier = ToastNotificationManager.CreateToastNotifier();
			var scheduled = notifier.GetScheduledToastNotifications();

			foreach (ScheduledToastNotification notification in scheduled)
			{
				// The id value is the unique ScheduledTileNotification.Id assigned to the 
				// notification when it was created.
				if (notification.Id == id.ToString())
				{
					notifier.RemoveFromSchedule(notification);
				}
			}

			return null;
		}

		public override object scheduleLocalNotification(double timestampUTC, int notificationId, string callbackArgs, string title, string text, bool playsound, bool pinNotification)
		{
			// Load the content into an XML document
			// ToastText02 is a built-in template with a single line header (id=1)
			// and a chunck of text that can wrap onto a second line (id=2).
			// Colors and small icon are picked up from the package manifest.
			var xmlString = $@"
				<toast launch='{notificationId}'>
					<visual>
						<binding template='ToastText02'>
							<text id='1'>{title}</text>
							<text id='2'>{text}</text>
						</binding>
					</visual>
					{(playsound? "<audio src='ms-winsoundevent:Notification.Default' />": "")}
				</toast>";
			XmlDocument document = new XmlDocument();
			document.LoadXml(xmlString);

			// Create a toast notification and send it
			DateTime dueTime = new DateTime(1970, 1, 1, 0, 0, 0, 0, System.DateTimeKind.Utc);
			dueTime = dueTime.AddMilliseconds(timestampUTC).ToLocalTime();

			ScheduledToastNotification scheduledToast = new ScheduledToastNotification(document, dueTime);
			scheduledToast.Id = notificationId.ToString();
			ToastNotificationManager.CreateToastNotifier().AddToSchedule(scheduledToast);

			return null;
		}
	}
}
