using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using Windows.Storage;
using Windows.Storage.Streams;

namespace Area9Innovation.Flow
{
	public class HttpSupportNet : HttpSupport
	{
		private Uri base_url;
		private MediaCache media;
		private HttpClient client;

		public HttpSupportNet(Uri base_url, MediaCache media)
		{
			this.base_url = base_url;
			this.media = media;
			client = new HttpClient();
			client.BaseAddress = base_url;
		}

		// If "files" is not empty forces POST, regardless of the "post" parameter 
		private async Task<HttpRequestMessage> composeHttpRequest(String url, bool post, Object[] headers, Object[] param, Object[] files)
		{
			post = post || (files != null && files.Length > 0);

			// TODO: We are trimming leading slashes since some apps provide absolute paths and are expecting them
			// to act as relative urls. Remove this when the confusion is settled.
			UriBuilder uri = new UriBuilder(new Uri(base_url, url.TrimStart('/')));

			HttpRequestMessage message = new HttpRequestMessage(post ? HttpMethod.Post : HttpMethod.Get, uri.Uri);

			for (int i = 0; i < headers.Length; i++)
			{
				object[] data = (object[])headers[i];
				message.Headers.Add((string)data[0], (string)data[1]);
			}

			MultipartFormDataContent multiPartContent = (post ? new MultipartFormDataContent() : null);

			// Parameters are appended to the url in GET mode and to the content in POST mode
			if (param.Length != 0)
			{
				if (!post)
				{
					for (int i = 0; i < param.Length; i++)
					{
						object[] data = (object[])param[i];
						string item = Uri.EscapeDataString((string)data[0]) + "=" + Uri.EscapeDataString((string)data[1]);

						string qry = uri.Query;
						uri.Query = (qry != null && qry.Length > 1) ? qry.Substring(1) + "&" + item : item;
					}
				}
				else
				{
					for (int i = 0; i < param.Length; i++)
					{
						object[] data = (object[])param[i];
						string key = (string)data[0];
						string value = (string)data[1];

						multiPartContent.Add(new StringContent(value), key);
					}
				}
			}

			// Attach the files, if any
			if (files != null && files.Length != 0)
			{
				foreach (Object[] attachment in files)
				{
					string name = (string)attachment[0];
					string path = (string)attachment[1];

					StorageFile file = await StorageFile.GetFileFromPathAsync(path);
					HttpContent content = new StringContent(name);
					multiPartContent.Add(content, name);

					var stream = await file.OpenStreamForReadAsync();
					content = new StreamContent(stream);
					content.Headers.ContentDisposition = new ContentDispositionHeaderValue("form-data")
					{
						Name = name,
						FileName = file.Name
					};
					multiPartContent.Add(content);
				}
			}

			if (post)
				message.Content = multiPartContent;

			return message;
		}

		public override async Task<Object> httpRequest(String url,bool post,Object[] headers,Object[] param,Func1 onData,Func1 onError,Func1 onStatus)
		{
			HttpRequestMessage message = await composeHttpRequest(url, post, headers, param, null);
			submitRequest(message, onData, onError, onStatus);
			return null;
		}

		public override async Task<Object> sendHttpRequestWithAttachments(String url, Object[] headers, Object[] param, Object[] files, Func1 onData, Func1 onError)
		{
			HttpRequestMessage message = await composeHttpRequest(url, false, headers, param, files);
			Func1 onStatus = (object a) => { return null; };
			submitRequest(message, onData, onError, onStatus);
			return null;
		}

		private async void submitRequest(HttpRequestMessage message, Func1 onData, Func1 onError, Func1 onStatus)
		{
			try
			{
				string data = null;
				bool success = false;
				HttpResponseMessage response;

				try
				{
					response = await client.SendAsync(message, HttpCompletionOption.ResponseHeadersRead);

					try
					{
						if (!runtime.IsRunning)
							return;

						using (var ctx = new FlowRuntime.DeferredContext(runtime))
						{
							onStatus((int)response.StatusCode);
						}

						if (!response.IsSuccessStatusCode)
						{
							data = "HTTP status " + response.StatusCode + " " + response.ReasonPhrase;
						}
						else
						{
							var charset = response.Content.Headers.ContentType.CharSet;
							var enc = (charset != null) ? charset.ToLowerInvariant() : "";

							if (enc == "utf-16") // binary
							{
								var bytes = await response.Content.ReadAsByteArrayAsync();
								int bias = (bytes.Length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) ? 1 : 0;
								var chars = new char[bytes.Length / 2 - bias];

								for (int i = 0, j = 2*bias; i < chars.Length; i++, j += 2)
									chars[i] = (char)((int)bytes[j] | ((int)bytes[j + 1]) << 8);

								data = new String(chars);
							}
							else
							{
								data = await response.Content.ReadAsStringAsync();
							}

							success = true;
						}
					}
					finally
					{
						response.Dispose();
					}
				}
				catch (Exception e)
				{
					success = false;
					data = e.ToString();
				}

				if (!runtime.IsRunning)
					return;

				using (var ctx = new FlowRuntime.DeferredContext(runtime))
				{
					if (success)
						onData(data);
					else
						onError(data);
				}
			}
			finally
			{
				message.Dispose();
			}
		}

		public override Object downloadFile(String url, Func1 onData, Func1 onError, Func2 onProgress) {
			Func1 onStatus = (object v) => { return null; };
			return httpRequest(url, false, new object[0], new object[0], onData, onError, onStatus);
		}

		public override Func0 uploadFile(String url,
				Object[] param,
				Object[] header,
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

		public override Object preloadMediaUrl(String url, Func0 onSuccess, Func1 onError) {
			doPreload(url, onSuccess, onError);
			return null;
		}

		private async void doPreload(String url, Func0 onSuccess, Func1 onError)
		{
			try
			{
				await media.getCachedObjectAsync(new Uri(base_url, url.TrimStart('/')));

				if (!runtime.IsRunning)
					return;

				using (var ctx = new FlowRuntime.DeferredContext(runtime))
				{
					onSuccess();
				}
			}
			catch(Exception e)
			{
				if (!runtime.IsRunning)
					return;

				using (var ctx = new FlowRuntime.DeferredContext(runtime))
				{
					onError(e.ToString());
				}
			}
		}

		public override Object removeUrlFromCache(String url) {
			// NOP
			return null;
		}

		public override Object clearUrlCache() {
			// NOP
			return null;
		}
	}
}

