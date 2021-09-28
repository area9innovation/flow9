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
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.lang.reflect.InvocationTargetException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

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
			byte[] postData = null;
			if (method == "POST") {
				URL obj = new URL(url);
				con = (HttpURLConnection) obj.openConnection();
				if (data != null & data != "") {
					postData = data.getBytes(StandardCharsets.UTF_8);
					con.setRequestProperty("Content-Type", "application/raw");
				} else {
					postData = urlParameters.getBytes(StandardCharsets.UTF_8);
					con.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
				};
				int postDataLength = postData.length;
				this.addHeaders(con, headers);
				con.setRequestProperty("charset", "utf-8");
				con.setRequestMethod(method);
				con.setDoOutput(true);
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
				con.setRequestMethod(method);
				con.setDoOutput(true);
			}
			con.setConnectTimeout(timeout.intValue());
			con.setReadTimeout(timeout.intValue());

	 		// Add data
			if (data != null & data != "") {
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

			ArrayList<Object[]> responseHeaders = new ArrayList();
			Map<String, List<String>> respHeaders = con.getHeaderFields();
					for (Map.Entry<String, List<String>> entry : respHeaders.entrySet()) {
				String key = entry.getKey();
				if (key == null) key = "";

				List<String> values = entry.getValue();
				String value = "";
				if (!values.isEmpty()) {
					value = values.get(0);
				}

				String[] kv = {key, value};
				responseHeaders.add(kv);
			}

			InputStream inputStream = null;
			/* getInputStream returns exception when status is not 200 and some other cases
			If status is 400/500 -> we should call getErrorStream*/
			try {
				inputStream = con.getInputStream();
			} catch (IOException e) {
			}
			if (Objects.isNull(inputStream)) {
				inputStream = con.getErrorStream();
			}
			StringBuilder response = new StringBuilder();
			// inputStream might be null, if body is empty
			if (Objects.nonNull(inputStream)) {
				BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream));
				for (String line; (line = reader.readLine()) != null; ) {
						response.append(line);
						response.append("\n");
				}
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

		File _file = (File)file;
		String contentType = null;
		try {
			contentType = Files.probeContentType(_file.toPath());
		} catch (FileNotFoundException e) {
			onError.invoke("File not found " + _file.toPath() + " " + e.getMessage());
		} catch (IOException e) {
			onError.invoke("IO exception while getting file info " + _file.toPath() + " " + e.getMessage());
		}

		HttpURLConnection con = null;
		URL urlObj = null;
		try {
			urlObj = new URL(url);
		} catch (MalformedURLException e) {
			onError.invoke("Malformed url " + url + " " + e.getMessage());
		}

		String boundary = Long.toHexString(System.currentTimeMillis()); // Just generate some unique random value.
		String CRLF = "\r\n"; // Line separator required by multipart/form-data.

		try {
			con = (HttpURLConnection) urlObj.openConnection();
			onOpen.invoke();

			this.addHeaders(con, headers);
			con.setDoOutput(true);
			con.setRequestMethod("POST");

			con.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);
			con.setUseCaches(false);

			try (
				OutputStream output = con.getOutputStream();
				PrintWriter writer = new PrintWriter(new OutputStreamWriter(output, StandardCharsets.UTF_8), true);
			) {

				// Send normal param.
				for (Object param : params) {
					Object [] keyvalue = (Object []) param;
					String key = (String) keyvalue[0];
					String value = (String) keyvalue[1];
					writer.append("--" + boundary).append(CRLF);
					writer.append("Content-Disposition: form-data; name=\"" + URLEncoder.encode(key, StandardCharsets.UTF_8.name()) + "\"").append(CRLF);
					writer.append("Content-Type: text/plain; charset=" + StandardCharsets.UTF_8.name()).append(CRLF);
					writer.append(CRLF).append(URLEncoder.encode(value, StandardCharsets.UTF_8.name())).append(CRLF).flush();
				}

				// Send binary file.
				writer.append("--" + boundary).append(CRLF);
				writer.append("Content-Disposition: form-data; name=\"binaryFile\"; filename=\"" + _file.getName() + "\"").append(CRLF);
				writer.append("Content-Type: " + contentType).append(CRLF);
				writer.append("Content-Transfer-Encoding: binary").append(CRLF);
				writer.append(CRLF).flush();
				Files.copy(_file.toPath(), output);
				output.flush(); // Important before continuing with writer!
				writer.append(CRLF).flush(); // CRLF is important! It indicates end of boundary.

				// // End of multipart/form-data.
				writer.append("--" + boundary + "--").append(CRLF).flush();
			} catch (IOException e) {
				onError.invoke("IO exception while sending data to " + url + " " + e.getMessage());
			}

			int responseCode = con.getResponseCode();

			// TODO: Make this asynchronous
			StringBuffer response = new StringBuffer();

			try (
				BufferedReader in = new BufferedReader(new InputStreamReader(con.getInputStream()));
			) {
				String inputLine;
				while ((inputLine = in.readLine()) != null) {
					response.append(inputLine);
					response.append('\n');
				}
				in.close();
			} catch (IOException e) {
				onError.invoke("IO exception while reading reponse " + url + " " + e.getMessage());
			}

			if (responseCode != 200) {
				onError.invoke("Response code: " + Integer.toString(responseCode) + ", data: " + response.toString());
			} else {
				onData.invoke(response.toString());
			}
		} catch (IOException e) {
			onError.invoke("IO exception " + url + " " + e.getMessage());
		} finally {
			if (con != null) {
				con.disconnect();
			}
		}
		return null;
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
