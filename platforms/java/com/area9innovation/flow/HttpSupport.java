package com.area9innovation.flow;

import java.util.*;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.net.*;
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
import java.io.Reader;
import java.lang.reflect.InvocationTargetException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

@SuppressWarnings("unchecked")
public class HttpSupport extends NativeHost {
	public static String defaultResponseEncoding = "auto";

	public static Object httpRequest(String url, boolean post,Object[] headers,
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
	 			urlParameters = urlParameters + encodeUrlParameter(key, value);
			}

			HttpURLConnection con = null;

			if (post) {
				// POST
				byte[] postData = urlParameters.getBytes(StandardCharsets.UTF_8);
				int postDataLength = postData.length;
				URL obj = new URI(url).toURL();

				con = (HttpURLConnection) obj.openConnection();
				addHeaders(con, headers);
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
				URL obj = new URI(urlWithParams).toURL();
				// GET
				con = (HttpURLConnection) obj.openConnection();
				addHeaders(con, headers);
				con.setRequestMethod("GET");
			}

			int responseCode = con.getResponseCode();
			onStatus.invoke(responseCode);

			// TODO: Make this asynchronous
			ResultStreamPair p = getResultStreamPair(con);
			if (Objects.nonNull(p.stream)) {
				String response = stream2string(p.stream, defaultResponseEncoding);
				if (p.isData) {
					onData.invoke(response);
				} else {
					onError.invoke(response);
				}
			} else {
				onError.invoke("");
			}
		} catch (MalformedURLException|URISyntaxException e) {
			onError.invoke("Malformed url " + url + " " + e.getMessage());
		} catch (IOException e) {
			onError.invoke("IO exception " + url + " " + e.getMessage());
		} catch (Exception e) {
			onError.invoke("Other exception " + url + " " + e.getMessage());
		}
		return null;
	}

	private static class ResultStreamPair {
		public InputStream stream;
		public Boolean isData; // otherwise it's an error

		private ResultStreamPair(InputStream stream, Boolean isData) {
			this.stream = stream;
			this.isData = isData;
		}
	}

	private static final ResultStreamPair getResultStreamPair(HttpURLConnection con) {
		// getInputStream returns exception when status is not 200 and some other cases
		// If status is 400/500 -> we should call getErrorStream
		// Both of this streams can be empty, even can be NULL
		try {
			return new ResultStreamPair(con.getInputStream(), true);
		} catch (IOException e) {
			return new ResultStreamPair(con.getErrorStream(), false);
		}
	}

	private static final String stream2string(InputStream inputStream, String responseEncoding) throws java.io.IOException {
		if (Native.getUrlParameter("use_utf8_js_style").equals("1")) {
			responseEncoding = "utf8_js";
		} else if (Native.getUrlParameter("utf8_no_surrogates").equals("1")) {
			responseEncoding = "utf8";
		} else if (responseEncoding.equals("auto")) {
			responseEncoding = defaultResponseEncoding;
		}

		StringBuilder response = new StringBuilder();
		// inputStream might be null, if body is empty
		if (Objects.nonNull(inputStream)) {
			final int bufferSize = 1024;

			if (responseEncoding.equals("utf8")) {
				// How much last chars from the previous chain we moved to the beginning of the new one (0 or 1).
				int additionalChars = 0;
				// +1 additinal char from the prevoius chain
				final char[] buffer = new char[bufferSize + 1];

				int readSize = 0;
				int countSize = 0;

				Reader in = new InputStreamReader(inputStream, Charset.forName("UTF-8"));
				while (true) {
					// How much chars we used to decode symbol into utf8 (1 or 2)
					int codesUsed = 0;

					readSize = in.read(buffer, additionalChars, bufferSize);

					// We stop, if nothing read
					if (readSize < 0) break;

					// On one less of real to use it as index + 1 in `for`
					countSize = readSize + additionalChars - 1;
					// Now, how much unprocessed chars we have
					additionalChars = (char)readSize;

					int counter = 0;
					while (counter < countSize) {
						codesUsed = unpackSurrogatePair(response, buffer[counter], buffer[counter + 1]);
						counter += codesUsed;

						additionalChars -= codesUsed;
					}

					if (additionalChars > 0) {
						buffer[0] = buffer[counter];
						additionalChars = 1;
					}
				}

				if (additionalChars > 0) {
					unpackSurrogatePair(response, buffer[0], buffer[0]);
				}
			} else if (responseEncoding.equals("utf8_js")) {
				final char[] buffer = new char[bufferSize];
				Reader in = new InputStreamReader(inputStream, Charset.forName("UTF-8"));
				while (true) {
					int rsz = in.read(buffer, 0, buffer.length);
					// We stop, if nothing read
					if (rsz < 0) break;
					response.append(buffer, 0, rsz);
				}
			} else if (responseEncoding.equals("byte")) {
				char c;
				int length;
				final byte[] buffer = new byte[bufferSize];

				while ((length = inputStream.read(buffer)) != -1) {
					for (int i=0; i< length; i++) {
						response.append((char) (buffer[i]&0x00FF));
					}
				}
			} else { // auto or other
				BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream));
				for (String line; (line = reader.readLine()) != null; ) {
					response.append(line);
					response.append("\n");
				}
				reader.close();
			}
		}
		return response.toString();
	}

	private static final java.lang.reflect.Method string2utf8Bytes;
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

	public static  final Object httpCustomRequestNative(String url, String method, Object[] headers,
		Object[] params, String data, String responseEncoding, Func3<Object,Integer,String,Object[]> onResponse, Boolean async) {
		return httpCustomRequestWithTimeoutNativeBase(url, method, headers, params, data, responseEncoding, onResponse, async, 0);
	}

	public static final Object httpCustomRequestWithTimeoutNative(String url, String method, Object[] headers,
		Object[] params, String data, Func3<Object,Integer,String,Object[]> onResponse, Boolean async, Integer timeout
		) {
		return httpCustomRequestWithTimeoutNativeBase(url, method, headers, params, data, "auto", onResponse, async, timeout);
	}

	private static final Object httpCustomRequestWithTimeoutNativeBase(String url, String method, Object[] headers,
		Object[] params, String data, String responseEncoding, Func3<Object,Integer,String,Object[]> onResponse, Boolean async, Integer timeout
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
	 			urlParameters = urlParameters + encodeUrlParameter(key, value);
			}
			HttpURLConnection con = null;
			byte[] postData = null;
			if (method == "POST") {
				URL obj = new URI(url).toURL();
				con = (HttpURLConnection) obj.openConnection();
				if (data != null & data != "") {
					postData = data.getBytes(StandardCharsets.UTF_8);
					con.setRequestProperty("Content-Type", "application/raw");
				} else {
					postData = urlParameters.getBytes(StandardCharsets.UTF_8);
					con.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
				};
				int postDataLength = postData.length;
				addHeaders(con, headers);
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
				URL obj = new URI(urlWithParams).toURL();
				con = (HttpURLConnection) obj.openConnection();
				addHeaders(con, headers);
				// Workaround for the `PATCH` method which does not supported in the `HttpURLConnection`.
				// https://trello.com/c/OPRchLv4/4399-cron-fails-with-invalid-http-method-patch
				if (method == "PATCH") {
					con.setRequestProperty("X-HTTP-Method-Override", "PATCH");
					method = method == "PATCH" ? "POST" : method;
				}
				con.setRequestMethod(method);
				con.setDoOutput(true);
			}
			con.setConnectTimeout(timeout.intValue());
			con.setReadTimeout(timeout.intValue());

	 		// Add data
			if (data != null & data != "") {
				try {
					byte[] converted = (byte[])string2utf8Bytes.invoke(FlowRuntime.getNativeHost(Native.class), data);
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

			String response = stream2string(getResultStreamPair(con).stream, responseEncoding);
			onResponse.invoke(responseCode, response, responseHeaders.toArray());

		} catch (MalformedURLException|URISyntaxException e) {
			onResponse.invoke(400, "Malformed url " + url + " " + e.getMessage(), new Object[0]);
		} catch (IOException e) {
			onResponse.invoke(500, "IO exception " + url + " " + e.getMessage(), new Object[0]);
		}
		return null;
	}

	private static final Integer unpackSurrogatePair(StringBuilder response, Character codeHi, Character codeLow) {
		char codeError = 0xFFFD;
		int codeResult = codeError;

		// `code` is the highest part of the surrogate pair
		if (0xD800 <= codeHi && codeHi <= 0xDBFF) {
			codeResult = ((codeHi & 0x3FF) << 10) + (codeLow & 0x3FF) + 0x10000;
			// Now we can't store 3 bytes (or more) symbols in java string, let's crop it to 2 bytes (like in cpp and js targets)
			response.append((char) codeResult);
			return 2;
		} else if (0xDC00 <= codeHi && codeHi <= 0xDFFF) {
		// `code` is the lowest part of the surrogate pair
		// If we meet it - something went wrong.
			response.append((char) codeError);
			return 1;
		}
		// Otherwise we do nothing - we have utf8 code.
		// Will process it below.

		response.append((char) codeHi);
		return 1;
	}

	private static final String encodeUrlParameter(String key, String value) {
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

	private static final void addHeaders(HttpURLConnection connection, Object[] headers) {
		for (Object header : headers) {
			Object [] heads = (Object []) header;
			String key = (String) heads[0];
			String value = (String) heads[1];
			connection.setRequestProperty(key, value);
		}

		String userInfo = connection.getURL().getUserInfo();
		if (userInfo != null) {
			String authorization = new String(Base64.getEncoder().encode(userInfo.getBytes()));
			connection.setRequestProperty("Authorization", "Basic " + authorization);
		}
	}

	public static final Object sendHttpRequestWithAttachments(String url, Object[] headers, Object[] params,
			Object [] attachments, Func1<Object,String> onDataFn, Func1<Object,String> onErrorFn) {
		// NOP
		System.out.println("sendHttpRequestWithAttachments not implemented");
		return null;
	}

	public static final Object downloadFile(String url, Func1<Object, String> onData, Func1<Object, String> onError, Func2<Object, Double, Double> onProgress) {
		// TODO
		System.out.println("downloadFile not implemented");
		return null;
	}

	public static final Func0<Object> uploadFile(String url,
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

	public static final Func0<Object> uploadNativeFile(
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
			urlObj = new URI(url).toURL();
		} catch (MalformedURLException|URISyntaxException e) {
			onError.invoke("Malformed url " + url + " " + e.getMessage());
		}

		String boundary = Long.toHexString(System.currentTimeMillis()); // Just generate some unique random value.
		String CRLF = "\r\n"; // Line separator required by multipart/form-data.

		try {
			con = (HttpURLConnection) urlObj.openConnection();
			onOpen.invoke();

			addHeaders(con, headers);
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
				onError.invoke("IO exception while reading response " + url + " " + e.getMessage());
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

	private static Func0<Object> no_op = new Func0<Object>() {
		public Object invoke() { return null; }
	};

	public static final Object doPreloadMediaUrl(String url, Func0<Object> onSuccess, Func1<Object, String> onError) {
		// NOP
		System.out.println("doPreloadMediaUrl not implemented");
		return null;
	}

	public static final Object removeUrlFromCache(String url) {
		// NOP
		System.out.println("removeUrlFromCache not implemented");
		return null;
	}

	public static final Object clearUrlCache() {
		// NOP
		System.out.println("clearUrlCache not implemented");
		return null;
	}

	public static final Object setDefaultResponseEncoding (String responseEncoding) {
		defaultResponseEncoding = responseEncoding;

		String encodingName = "";
		if (responseEncoding.equals("auto")) {
			encodingName = "auto";
		} else if (responseEncoding.equals("utf8_js")) {
			encodingName = "utf8 with surrogate pairs";
		} else if (responseEncoding.equals("utf8")) {
			encodingName = "utf8 without surrogate pairs";
		} else if (responseEncoding.equals("byte")) {
			encodingName = "raw byte";
		} else {
			encodingName = "auto";
		}

		System.out.println("Default response encoding switched to '" + encodingName + "'");

		return null;
	}
}
