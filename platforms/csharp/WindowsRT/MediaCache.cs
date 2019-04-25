using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using Windows.Networking.BackgroundTransfer;
using Windows.Storage;
using System.Net.Http;

namespace Area9Innovation.Flow
{
	public class MediaCache
	{
		private StorageFolder cache_directory;
		private String token;
		private BackgroundTransferGroup group;

		private BackgroundDownloader client;
		private Dictionary<Uri, Task<StorageFile>> pending_downloads;
		private Dictionary<Uri, StorageFile> finished_downloads;

		private Dictionary<string, Task<string>> pending_metadata;
		private Dictionary<string, string> finished_metadata;

		public MediaCache(StorageFolder cache_directory, String token)
		{
			this.cache_directory = cache_directory;
			this.token = token;

			group = BackgroundTransferGroup.CreateGroup(token);

			client = new BackgroundDownloader();
			client.TransferGroup = group;

			pending_downloads = new Dictionary<Uri, Task<StorageFile>>();
			finished_downloads = new Dictionary<Uri, StorageFile>();

			pending_metadata = new Dictionary<string, Task<string>>();
			finished_metadata = new Dictionary<string, string>();

			IReadOnlyList<DownloadOperation> downloads = Task.Run(async () => {
				try
				{
					return await BackgroundDownloader.GetCurrentDownloadsForTransferGroupAsync(group);
				}
				catch (Exception)
				{
					return new List<DownloadOperation>();
				}
			}).Result;

			foreach (var op in downloads)
			{
				try
				{
					var pending = fetchObjectToCache(op.RequestedUri, op);

					if (!pending.IsCompleted)
						pending_downloads.Add(op.RequestedUri, pending);
				}
				catch (Exception e)
				{
					Debug.WriteLine("Could not resume download to cache: "+e.ToString());
				}
			}
		}

		public Task<StorageFile> getCachedObjectAsync(Uri target)
		{
			Task<StorageFile> pending;

			target = adustLink(target);

			if (!pending_downloads.TryGetValue(target, out pending))
			{
				pending = fetchObjectToCache(target, null);

				if (!pending.IsCompleted)
					pending_downloads.Add(target, pending);
			}

			return pending;
		}

		private static string getExtension(string path)
		{
			int start = path.LastIndexOfAny(new char[] { '/', '\\' });
			if (start < 0)
				start = 0;

			int iext = path.IndexOf('.', start);
			return (iext >= 0) ? path.Substring(iext) : "";
		}

		private async Task deleteAuxFiles(string basename)
		{
			var all_files = await cache_directory.GetFilesAsync();
			var template = basename + ".";

			foreach (var file in all_files)
				if (file.Name.StartsWith(template))
					await file.DeleteAsync();
		}

		private async Task<StorageFile> fetchObjectToCache(Uri target, DownloadOperation op)
		{
			try
			{
				StorageFile result;
				if (finished_downloads.TryGetValue(target, out result))
					return result;

				var filename = NativeXAML.getHashedFilename(target.ToString()) + getExtension(target.AbsolutePath);
				IStorageFile outfile;

				if (op == null)
				{
					try
					{
						return finished_downloads[target] = await cache_directory.GetFileAsync(filename);
					}
					catch (FileNotFoundException) { }

					StorageFile tmp = await cache_directory.CreateFileAsync(filename + ".tmp", CreationCollisionOption.ReplaceExisting);

					// If target is a data uri, simply decode it instead of downloading
					if (target.Scheme == "data")
					{
						string dataUri = target.AbsoluteUri;
						var data = Convert.FromBase64String(dataUri.Substring(dataUri.IndexOf(",") + 1));
						await FileIO.WriteBytesAsync(tmp, data);
						outfile = tmp;
					}
					else
					{
						op = client.CreateDownload(target, tmp);
						op = await op.StartAsync();
						outfile = op.ResultFile;
					}
				}
				else
				{
					if (!op.ResultFile.Path.StartsWith(cache_directory.Path))
						throw new Exception("Unexpected cache file location: " + op.ResultFile.Path);

					op = await op.AttachAsync();
					outfile = op.ResultFile;
				}

				await outfile.RenameAsync(filename, NameCollisionOption.ReplaceExisting);
				await deleteAuxFiles(filename);

				return finished_downloads[target] = await cache_directory.GetFileAsync(filename);
			}
			finally
			{
				pending_downloads.Remove(target);
			}
		}

		public static Uri fileToLink(IStorageFile file)
		{
			return new Uri("file://" + file.Path.Replace('\\', '/'));
		}

		private static Uri adustLink(Uri target)
		{
			var adj = new UriBuilder(target);
			string path = adj.Path;

			if (path.EndsWith(".swf"))
				adj.Path = path.Substring(0, path.Length-4) + ".png";
			else if (path.EndsWith(".flv"))
				adj.Path = path.Substring(0, path.Length - 4) + ".mp4";

			return adj.Uri;
		}

		public delegate Task<string> CalcMetadataCallback(StorageFile data);

		public async Task<string> getCachedMetadataAsync(Uri target, string id, CalcMetadataCallback computer)
		{
			// ensure the object is up to date
			var data = await getCachedObjectAsync(target);
			var metafn = data.Name + ".meta." + id;

			string result;
			if (finished_metadata.TryGetValue(metafn, out result))
				return result;

			Task<string> pending;

			if (!pending_metadata.TryGetValue(metafn, out pending))
			{
				pending = getMetadataToMemory(data, metafn, computer);

				if (!pending.IsCompleted)
					pending_metadata.Add(metafn, pending);
			}

			return await pending;
		}

		private async Task<string> getMetadataToMemory(StorageFile data, string metafn, CalcMetadataCallback computer)
		{
			try
			{
				string result;

				try
				{
					var file = await cache_directory.GetFileAsync(metafn);
					result = await FileIO.ReadTextAsync(file, Windows.Storage.Streams.UnicodeEncoding.Utf8);

					return finished_metadata[metafn] = result;
				}
				catch (FileNotFoundException) { }

				result = finished_metadata[metafn] = await computer(data);

				StorageFile newfile = await cache_directory.CreateFileAsync(metafn, CreationCollisionOption.ReplaceExisting);
				await FileIO.WriteTextAsync(newfile, result, Windows.Storage.Streams.UnicodeEncoding.Utf8);
				return result;
			}
			finally
			{
				pending_metadata.Remove(metafn);
			}
		}
	}
}

