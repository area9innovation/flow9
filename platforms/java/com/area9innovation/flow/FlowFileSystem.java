package com.area9innovation.flow;

import java.util.*;
import java.nio.charset.Charset;
import java.io.File;

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
	private List<String> deleteRecursively(File path) {
		List<String> ret = new ArrayList<String>();
		if (path.isDirectory()) {
			for (File file : path.listFiles()) {
				ret.addAll(deleteRecursively(file));
			}
		}
		if (!path.delete()) {
			ret.add("Could not delete " + path);
		}
		return ret;
	}
	public String deleteDirectory(String dir) {
		List<String> errors = deleteRecursively(new File(dir));
		return String.join("\n", errors);
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
	public String resolveRelativePath(String path) {
		File file = new File(path);
		try {
			return file.getCanonicalPath();
		} catch (Exception e) {
			return "";
		}
	}
	public Func0<Object> uploadNativeFile(Object a, String b, Object[] c, Func0<Object> d, Func1<Object, String> e, Func1<Object, String> f, 
					Func2<Object, Double, Double> g, Func0<Object> h) {
		System.out.println("Not implemented: uploadNativeFile");
		return null;
	}

    public Object openFileDialog(Integer maxFiles, Object[] fileTypes, Func1<Object, Object[]> callback) {
	return null;
    }

    public String fileName(Object file) {
	return "";
    }

    public Object readFile(Object file, String as, Func1<Object,String> onData, Func1<Object, String> onError) {
	return null;
    }
}
