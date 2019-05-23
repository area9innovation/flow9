using System;
using System.Diagnostics;
using System.Threading.Tasks;

namespace Area9Innovation.Flow
{
	public class HttpSupport : NativeHost
	{
		public virtual async Task<Object> httpRequest(String url,bool post,Object[] headers,Object[] param,Func1 onData,Func1 onError,Func1 onStatus) {
			// TODO
			Debug.WriteLine("httpRequest not implemented");
			return null;
		}

		public virtual async Task<Object> sendHttpRequestWithAttachments(String url, Object[] headers, Object[] param, Object[] files, Func1 onData, Func1 onError)
		{
			// TODO
			Debug.WriteLine("sendHttpRequestWithAttachments not implemented");
			return null;
		}

		public virtual Object downloadFile(String url, Func1 onData, Func1 onError, Func2 onProgress) {
			// TODO
			Debug.WriteLine("downloadFile not implemented");
			return null;
		}

		public virtual Func0 uploadFile(String url,
				Object[] param,
				Object[] headers,
				Object[] fileTypes,
				Func0 onOpen,
				Func2 onSelect,
				Func1 onData,
				Func1 onError,
				Func2 onProgress,
				Func0 onCancel) {
			// TODO
			Debug.WriteLine("uploadFile not implemented");

			return no_op;
		}

		private static Func0 no_op = delegate() { return null; };

		public virtual Object preloadMediaUrl(String url, Func0 onSuccess, Func1 onError) {
			// NOP
			return null;
		}

		public virtual Object removeUrlFromCache(String url) {
			// NOP
			return null;
		}

		public virtual Object clearUrlCache() {
			// NOP
			return null;
		}
	}
}

