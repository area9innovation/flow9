using System;

namespace Area9Innovation.Flow
{
	public class NotificationsSupport : NativeHost
	{
		static object no_op() { return null; }

		public virtual bool hasPermissionLocalNotification()
		{
			return false;
		}

		public virtual object requestPermissionLocalNotification(Func1 cb)
		{
			cb(false);
			return null;
		}

		public virtual Func0 addOnClickListenerLocalNotification(Func2 cb)
		{
			return no_op;
		}

		public virtual object cancelLocalNotification(int id)
		{
			return null;
		}

		public virtual object scheduleLocalNotification(double a, int b, string c, string d, string e, bool f, bool g)
		{
			return null;
		}
		public virtual Func0 addFBNotificationListener(Func6 cb)
		{
			return no_op;
		}
		public virtual Func0 onRefreshFBToken(Func1 cb)
		{
			return no_op;
		}
		public virtual int getBadgerCount()
		{
			return 0;
		}
		public virtual object setBadgerCount(int value)
		{
			return null;
		}
		public virtual object subscribeToFBTopic(string a)
		{
			return null;
		}
	}
}
