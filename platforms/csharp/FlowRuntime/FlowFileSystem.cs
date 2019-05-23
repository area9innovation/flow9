using System;

namespace Area9Innovation.Flow
{
	public class FlowFileSystem : NativeHost
	{
		public virtual string createDirectory(string path) {
			return "Not implemented";
		}
		public virtual string deleteDirectory(string path) {
			return "Not implemented";
		}
		public virtual string deleteFile(string path) {
			return "Not implemented";
		}
		public virtual string renameFile(string old, string newname) {
			return "Not implemented";
		}
		public virtual bool fileExists(string path) {
			return false;
		}
		public virtual bool isDirectory(string path) {
			return false;
		}
		public virtual Object[] readDirectory(string path) {
			return new string[0];
		}
		public virtual double fileSize(string path) {
			return 0.0;
		}
		public virtual double fileModified(string path) {
			return 0.0;
		}
		public virtual string resolveRelativePath(string path) {
			return path;
		}
		public virtual Object getFileByPath(string path) {
			return "Not implemented";
		}
		public virtual void openFileDialog(int max, string[] fileTypes, Func1 callback) {
			// No implemented
		}
		private static Func0 no_op = delegate() { return null; };
		public virtual void uploadNativeFile(Object file, string url, string[][] ps, Func0 onOpenFn, Func1 onDataFn, Func1 onErrorFn, Func2 onProgressFn, Func0 onCancelFn) {
			// Not implemented
		}
		public virtual string fileName(Object file) {
			return "Not implemented";
		}
		public virtual string fileType(Object file) {
			return "Not implemented";
		}
		public virtual double fileSizeNative(Object file) {
			return 0.0;
		}
		public virtual double fileModifiedNative(Object file) {
			return 0.0;
		}
		public virtual Object fileSlice(Object file, int offset, int end) {
			return file;
		}
		public virtual void readFile(Object file, string readAs, Func1 onData, Func1 onError) {
			// Not implemented
		}
	}
}
