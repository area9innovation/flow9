package com.area9innovation.flow;

import java.util.*;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.FileNotFoundException;
import java.net.URL;
import java.net.MalformedURLException;
import java.nio.charset.Charset;
import java.nio.channels.Channels;
import java.nio.channels.FileChannel;
import java.nio.channels.ReadableByteChannel;
import java.lang.reflect.InvocationTargetException;

public class FlowFileSystem extends NativeHost {
	public String createDirectory(String path) {
		try {
			File file = new File(path);
			if (file.mkdirs()) {
				return "";
			} else {
				return "Could not make " + path;
			}
		} catch (SecurityException se) {
			return "Security exception when making " + path;
		}
	}
	public String deleteDirectory(String path) {
		File file = new File(path);
		if (file.delete()) {
			return "";
		} else {
			return "Could not delete " + path;
		}
	}
	public String deleteFile(String path) {
		File file = new File(path);
		if (file.delete()) {
			return "";
		} else {
			return "Could not delete " + path;
		}
	}
	public String renameFile(String old, String newname) {
		File file = new File(old);
		File newfile = new File(newname);
		if (file.renameTo(newfile)) {
			return "";
		} else {
			return "Could not rename " + old + " to " + newname;
		}
	}
	public boolean fileExists(String path) {
		File file = new File(path);
		return file.exists();
	}
	public boolean isDirectory(String path) {
		File file = new File(path);
		return file.isDirectory();
	}
	public Object[] readDirectory(String path) {
		File file = new File(path);
		String[] fileNames = file.list();
		if (fileNames == null) {
			return new Object[0];
		} else {
			return fileNames;
		}
	}
	public double fileSize(String path) {
		File file = new File(path);
		return file.length();
	}
	public double fileModified(String path) {
		File file = new File(path);
		double d = file.lastModified() / 1000;
		return Math.round(d) * 1000;
	}
	public double fileModifiedPrecise(String path) {
		File file = new File(path);
		return file.lastModified();
	}

	public String resolveRelativePath(String path) {
		File file = new File(path);
		try {
			return file.getCanonicalPath();
		} catch (Exception e) {
			return "";
		}
	}

    public Object openFileDialog(Integer maxFiles, Object[] fileTypes, Func1<Object, Object[]> callback) {
		return null;
    }

    public String fileName(Object file) {
		File _file = (File)file;
		return _file.getAbsolutePath();
    }

    public Object readFile(Object file, String as, Func1<Object,String> onData, Func1<Object, String> onError) {
		return null;
    }

    public Object readFileEnc(Object file, String as, String enc, Func1<Object,String> onData, Func1<Object, String> onError) {
		return null;
    }

    public Object saveFileClient(String filename, String data, String type) {
		return null;
	}

	public Object getFileByPath(String path) {
		return null;
	}

	public double fileSizeNative(Object file) {
		File _file = (File)file;
		return (double)_file.length();
	}
	public double fileModifiedNative(Object file) {
		File _file = (File)file;
		double d = _file.lastModified() / 1000;
		return Math.round(d) * 1000;
	}
	public Object makeFileByBlobUrl(String url, String fileName, Func1<Object,File> onFile, Func1<Object,String> onError) {
		try (
			ReadableByteChannel readableByteChannel = Channels.newChannel(new URL(url).openStream());
			FileOutputStream fileOutputStream = new FileOutputStream(fileName);
		) {
			fileOutputStream.getChannel().transferFrom(readableByteChannel, 0, Long.MAX_VALUE);
			onFile.invoke(new File(fileName));
		} catch (MalformedURLException e) {
			onError.invoke("Malformed url " + url + " " + e.getMessage());
		} catch (FileNotFoundException e) {
			onError.invoke("File not found " + fileName + " " + e.getMessage());
		} catch (IOException e) {
			onError.invoke("IO Exception while downloading " + url + " to " + fileName + " " + e.getMessage());
		}

		return null;
	}

	public File createTempFile(String name, String content) {
		File tmpdir = new File(System.getProperty("java.io.tmpdir"));
		File newFile = new File(tmpdir, name);
		try {
			newFile.createNewFile();
		} catch (IOException e) {
			System.out.println("IO Exception: " + e.getMessage());
		}
		if (content != null & content != "") {
			try {
				byte[] converted = (byte[])string2utf8Bytes.invoke(runtime.getNativeHost(Native.class), content);
				try (
					FileOutputStream fileOutputStream = new FileOutputStream(newFile);
				) {
					fileOutputStream.write(converted);
				} catch (IOException e) {
					System.out.println("IO Exception: " + e.getMessage());
				}
			} catch (IllegalAccessException e) {
				System.out.println("At data string conversion: " + e.getMessage());
			} catch (InvocationTargetException e) {
				System.out.println("At data string conversion: " + e.getMessage());
			}
		}
		return newFile;
	}

	private final static java.lang.reflect.Method string2utf8Bytes;
	static {
		java.lang.reflect.Method method = null;
		try {
			method = Native.class.getMethod("string2utf8Bytes", String.class);
		} catch (ReflectiveOperationException e) {
			System.out.println("string2utf8 method is not initialized: " + e.getMessage());
			throw new ExceptionInInitializerError(e);
		} finally {
			string2utf8Bytes = method;
		}
	}

	public Object extractZipFile(String zipFileName, String outputDir, Func0<Object> onDone, Func1<Object,String> onError) {
		File destDir = new File(outputDir);
		try (
			ZipFile zipFile = new ZipFile(zipFileName)
		) {
			Enumeration<? extends ZipEntry> zipEntries = zipFile.entries();

			while (zipEntries.hasMoreElements()) {
				ZipEntry zipEntry = zipEntries.nextElement();
				File destFile = getFileForExtraction(destDir, zipEntry);
				if (zipEntry.isDirectory()) {
					if (!destFile.isDirectory() && !destFile.mkdirs()) {
						throw new IOException("Failed to create directory " + destFile);
					}
				} else {
					File parent = destFile.getParentFile();
					if (!parent.isDirectory() && !parent.mkdirs()) {
						throw new IOException("Failed to create directory " + parent);
					}

					try (
						ReadableByteChannel readableByteChannel = Channels.newChannel(zipFile.getInputStream(zipEntry));
						FileOutputStream fileOutputStream = new FileOutputStream(destFile);
					) {
						fileOutputStream.getChannel().transferFrom(readableByteChannel, 0, Long.MAX_VALUE);
					}
				}
			}
		} catch (IOException e) {
			onError.invoke("IOException while extracting " + zipFileName + " to " + outputDir + ": " + e.getMessage());
		}

		onDone.invoke();
		return null;
	}

	private final static File getFileForExtraction(File destinationDir, ZipEntry zipEntry) throws IOException {
		File destFile = new File(destinationDir, zipEntry.getName());

		String destDirPath = destinationDir.getCanonicalPath();
		String destFilePath = destFile.getCanonicalPath();

		if (!destFilePath.startsWith(destDirPath + File.separator)) {
			throw new IOException("Entry is outside of the target dir: " + zipEntry.getName());
		}

		return destFile;
	}
}
