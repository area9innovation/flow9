package com.area9innovation.flow;

import java.util.*;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.net.URL;
import java.net.URLConnection;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

@SuppressWarnings("unchecked")
public class HttpSupport extends NativeHost {
	public Object httpRequest(String url, boolean post,Object[] headers,
				Object[] params,Func1<Object,String> onData,Func1<Object,String> onError,Func1<Object,Integer> onStatus) {
		// TODO
		try {
			// Add parameters
			String urlParameters = "";
			for (Object param : params) {
	 			Object [] keyvalue = (Object []) param;
	 			String key = (String) keyvalue[0];
				String value = (String) keyvalue[1];
				if (!urlParameters.isEmpty()) {
					urlParameters += "&";
				}
	 			urlParameters = urlParameters + this.encodeUrlParameter(key, value);
			}

			HttpURLConnection con = null;

			if (post) {
				// POST
				byte[] postData = urlParameters.getBytes(StandardCharsets.UTF_8);
				int postDataLength = postData.length;
				URL obj = new URL(url);

				con = (HttpURLConnection) obj.openConnection();
				this.addHeaders(con, headers);
				con.setDoOutput(true); // Triggers POST.
				con.setRequestMethod("POST");

				con.setRequestProperty("Content-Type", "application/x-www-form-urlencoded"); 
				con.setRequestProperty("charset", "utf-8");
				con.setRequestProperty("Content-Length", Integer.toString(postDataLength));
				con.setUseCaches(false);
				try(DataOutputStream wr = new DataOutputStream(con.getOutputStream())) {
					wr.write(postData);
				}
			} else {
				String urlWithParams = url;
				if (!urlParameters.isEmpty()) {
					if (url.contains("?")) {
						urlWithParams += "&" + urlParameters;
					} else {
						urlWithParams += "?" + urlParameters;
					}
				}
				URL obj = new URL(urlWithParams);				
				// GET
				con = (HttpURLConnection) obj.openConnection();
				this.addHeaders(con, headers);
				con.setRequestMethod("GET");
			}

			int responseCode = con.getResponseCode();
			onStatus.invoke(responseCode);
	
			// TODO: Make this asynchronous
			BufferedReader in = new BufferedReader(new InputStreamReader(con.getInputStream()));
			String inputLine;
			StringBuffer response = new StringBuffer();
	 
			while ((inputLine = in.readLine()) != null) {
				response.append(inputLine);
				response.append('\n');
			}
			in.close();
	
			onData.invoke(response.toString());
        } catch (MalformedURLException e) {
        	onError.invoke("Malformed url " + url + " " + e.getMessage());
        } catch (IOException e) {
        	onError.invoke("IO exception " + url + " " + e.getMessage());
        }
		return null;
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

	public final Object httpCustomRequestNative(String url, String method, Object[] headers,
		Object[] params, String data, Func3<Object,Integer,String,Object[]> onResponse, Boolean async) {
		return httpCustomRequestWithTimeoutNative(url, method, headers, params, data, onResponse, async, 0);
	}

	public final Object httpCustomRequestWithTimeoutNative(String url, String method, Object[] headers,
		Object[] params, String data, Func3<Object,Integer,String,Object[]> onResponse, Boolean async, Integer timeout
		) {
		try {
			// Add parameters
			String urlParameters = "";
			for (Object param : params) {
	 			Object [] keyvalue = (Object []) param;
	 			String key = (String) keyvalue[0];
				String value = (String) keyvalue[1];

				if (!urlParameters.isEmpty()) {
					urlParameters += "&";
				}
	 			urlParameters = urlParameters + this.encodeUrlParameter(key, value);
			}
			HttpURLConnection con = null;
			if (method == "POST") {
				byte[] postData = urlParameters.getBytes(StandardCharsets.UTF_8);
				int postDataLength = postData.length;				
				URL obj = new URL(url);
				con = (HttpURLConnection) obj.openConnection();
				this.addHeaders(con, headers);
				con.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
				con.setRequestProperty("charset", "utf-8");
				con.setRequestProperty("Content-Length", Integer.toString(postDataLength));
				con.setUseCaches(false);
				try(DataOutputStream wr = new DataOutputStream(con.getOutputStream())) {
					wr.write(postData);
				}
			} else {
				String urlWithParams = url;
				if (!urlParameters.isEmpty()) {
					if (url.contains("?")) {
						urlWithParams += "&" + urlParameters;
					} else {
						urlWithParams += "?" + urlParameters;
					}
				}
				URL obj = new URL(urlWithParams);
				con = (HttpURLConnection) obj.openConnection();
				addHeaders(con, headers);
			}
			con.setDoOutput(true);
			con.setRequestMethod(method);
			con.setConnectTimeout(timeout.intValue());
			con.setReadTimeout(timeout.intValue());

	 		// Add data
			if (data != null) {
				try {
					byte[] converted = (byte[])string2utf8Bytes.invoke(runtime.getNativeHost(Native.class), data);
					con.getOutputStream().write(converted/*data.getBytes("UTF8")*/);
				} catch (IllegalAccessException e) {
					System.out.println("At data string conversion: " + e.getMessage());
				} catch (InvocationTargetException e) {
					System.out.println("At data string conversion: " + e.getMessage());
				}
			}

			int responseCode = con.getResponseCode();

			// TODO: Make this asynchronous
			BufferedReader in = new BufferedReader(new InputStreamReader(con.getInputStream()));
			String inputLine;
			StringBuffer response = new StringBuffer();

			while ((inputLine = in.readLine()) != null) {
				response.append(inputLine);
				response.append('\n');
			}
			in.close();

			ArrayList<Object[]> responseHeaders = new ArrayList();
			Map<String, List<String>> respHeaders = con.getHeaderFields();
	        for (Map.Entry<String, List<String>> entry : respHeaders.entrySet()) {
				List<String> values = entry.getValue();
				String value = "";
				if (!values.isEmpty()) {
					value = values.get(0);
				}
				String[] kv = {entry.getKey(), value};
				responseHeaders.add(kv);
			}

			onResponse.invoke(responseCode, response.toString(), responseHeaders.toArray());
        } catch (MalformedURLException e) {
        	onResponse.invoke(400, "Malformed url " + url + " " + e.getMessage(), new Object[0]);
        } catch (IOException e) {
        	onResponse.invoke(500, "IO exception " + url + " " + e.getMessage(), new Object[0]);
        }
		return null;
	}

	private final String encodeUrlParameter(String key, String value) {
		try {
			String encodedKey = URLEncoder.encode(key, StandardCharsets.UTF_8.toString()).replace("+", "%20");
			String encodedValue = URLEncoder.encode(value, StandardCharsets.UTF_8.toString()).replace("+", "%20");
			String parameter = encodedKey + "=" + encodedValue;
			return parameter;
		} catch (IOException e) {
			System.out.println("Error during encoing parameters: " + e);
			return "";
		}
	}

	private final void addHeaders(HttpURLConnection connection, Object[] headers) {
		for (Object header : headers) {
			Object [] heads = (Object []) header;
			String key = (String) heads[0];
			String value = (String) heads[1];
			connection.setRequestProperty(key, value);
		}
	}

	public final Object sendHttpRequestWithAttachments(String url, Object[] headers, Object[] params,
			Object [] attachments, Func1<Object,String> onDataFn, Func1<Object,String> onErrorFn) {
		// NOP
		System.out.println("sendHttpRequestWithAttachments not implemented");
		return null;
	}

	public final Object downloadFile(String url, Func1<Object, String> onData, Func1<Object, String> onError, Func2<Object, Double, Double> onProgress) {
		// TODO
		System.out.println("downloadFile not implemented");
		return null;
	}

	public final Func0<Object> uploadFile(String url, 
			Object[] params, 
			Object[] headers, 
			Object[] fileTypes,
			Func0<Object> onOpen,
			Func2<Boolean, String, Integer> onSelect,
			Func1<Object, String> onData,
			Func1<Object, String> onError, 
			Func2<Object, Double, Double> onProgress,
			Func0<Object> onCancel) {
		// TODO
		System.out.println("uploadFile not implemented");

		return no_op;
	}

	public final Func0<Object> uploadNativeFile(
			Object file,
			String url, 
			Object[] params, 
			Object[] headers, 
			Func0<Object> onOpen,
			Func1<Object, String> onData,
			Func1<Object, String> onError, 
			Func2<Object, Double, Double> onProgress) {
		// TODO
		System.out.println("uploadNativeFile not implemented");

		return no_op;
	}

	private Func0<Object> no_op = new Func0<Object>() {
		public Object invoke() { return null; }
	};

	public final Object doPreloadMediaUrl(String url, Func0<Object> onSuccess, Func1<Object, String> onError) {
		// NOP
		System.out.println("doPreloadMediaUrl not implemented");
		return null;
	}

	public final Object removeUrlFromCache(String url) {
		// NOP
		System.out.println("removeUrlFromCache not implemented");
		return null;
	}

	public final Object clearUrlCache() {
		// NOP
		System.out.println("clearUrlCache not implemented");
		return null;
	}
}
