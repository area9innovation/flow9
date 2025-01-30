package com.area9innovation.flow;

import com.sun.net.httpserver.*;
import java.net.InetSocketAddress;
import java.util.*;
import java.util.stream.Collectors;
import java.io.*;
import java.security.KeyStore;
import javax.net.ssl.*;
import java.util.concurrent.*;

public class HttpServerSupport extends NativeHost {

	public static Object createHttpServerNative(
		int port,
		boolean isHttps,
		String pfxPath,
		String pfxPassword,
		Func0<Object> onOpen,
		Func1<Object, String> onOpenError,
		Func7<
			Object,
			String,
			String,
			String,
			Object[],
			Func1<Object,String>,
			Func2<Object,String,Object[]>,
			Func1<Object,Integer>
		> onMessage
	) {
		try {
			if (isHttps) {
				HttpsServer server = HttpsServer.create();
				server.setExecutor(Executors.newCachedThreadPool());
				SSLContext sslContext = setupSSLContext(pfxPath, pfxPassword);
				configureHttpsServer(server, sslContext);

				server.bind(new InetSocketAddress(port), 0);
				server.createContext("/", new EchoHandler(onMessage));

				server.start();
				onOpen.invoke();

				return server;
			} else {
				HttpServer server = HttpServer.create();
				server.bind(new InetSocketAddress(port), 0);
				server.setExecutor(Executors.newCachedThreadPool());
				server.createContext("/", new EchoHandler(onMessage));

				server.start();
				onOpen.invoke();

				return server;
			}
		} catch (Exception e) {
			onOpenError.invoke("Failed to create HTTPS server: " + e.getMessage());
			return null;
		}
	}

	public static Object createHttpChunkedServerNative(
		int port,
		boolean isHttps,
		String pfxPath,
		String pfxPassword,
		Func0<Object> onOpen,
		Func1<Object, String> onOpenError,
		Func8<
			Object,
			String,
			String,
			String,
			Object[],
			Func0<Object>,
			Func1<String, String>,
			Func2<String, Integer, Boolean>,
			Func2<Object, String, Object[]>
		> onMessage
	) {
		try {
			if (isHttps) {
				HttpsServer server = HttpsServer.create();
				server.setExecutor(Executors.newCachedThreadPool());
				SSLContext sslContext = setupSSLContext(pfxPath, pfxPassword);
				configureHttpsServer(server, sslContext);

				server.bind(new InetSocketAddress(port), 0);

				server.createContext("/", new ChunkedHandler(onMessage));

				server.start();
				onOpen.invoke();

				return server;
			} else {
				HttpServer server = HttpServer.create();
				server.bind(new InetSocketAddress(port), 0);
				server.setExecutor(Executors.newCachedThreadPool());

				server.createContext("/", new ChunkedHandler(onMessage));

				server.start();
				onOpen.invoke();

				return server;
			}
		} catch (Exception e) {
			onOpenError.invoke("Failed to create HTTPS server: " + e.getMessage());
			return null;
		}
	}

	public static Object closeHttpServerNative(Object server) {
		((HttpServer)server).stop(0);
		return null;
	}

	public static SSLContext setupSSLContext(
		String pfxPath,
		String pfxPassword) throws Exception
	{
		SSLContext sslContext = SSLContext.getInstance("TLS");

		char[] passwordArray = pfxPassword.toCharArray();

		KeyStore keyStore = KeyStore.getInstance("JKS");
		java.io.FileInputStream keyInputStream =
			new java.io.FileInputStream(pfxPath);
		keyStore.load(keyInputStream, passwordArray);

		KeyManagerFactory keyManagerFactory =
			KeyManagerFactory.getInstance("SunX509");
		keyManagerFactory.init(keyStore, passwordArray);

		TrustManagerFactory trustManagerFactory =
			TrustManagerFactory.getInstance("SunX509");
		trustManagerFactory.init(keyStore);

		sslContext.init(
			keyManagerFactory.getKeyManagers(),
			trustManagerFactory.getTrustManagers(),
			null
		);

		return sslContext;
	}

	private static void configureHttpsServer(HttpsServer server, SSLContext sslContext)
	{
		server.setHttpsConfigurator(new HttpsConfigurator(sslContext)
		{
			public void configure (HttpsParameters params)
			{
				try
				{
					SSLContext sslContext = SSLContext.getDefault();
					SSLEngine engine = sslContext.createSSLEngine();
					params.setNeedClientAuth (false);
					params.setCipherSuites(engine.getEnabledCipherSuites());
					params.setProtocols(engine.getEnabledProtocols());
					params.setSSLParameters(sslContext.getDefaultSSLParameters());
				}
				catch (Exception ex)
				{
					System.out.println(ex);
					System.out.println("Failed to configure HTTPS server");
				}
			}
		});
	}

	static class EchoHandler extends HttpHandlerBase implements HttpHandler {
		private Func7<
			Object,
			String,
			String,
			String,
			Object[],
			Func1<Object, String>,
			Func2<Object, String, Object[]>,
			Func1<Object, Integer>
		> onMessage;

		public EchoHandler(Func7<
			Object,
			String,
			String,
			String,
			Object[],
			Func1<Object,String>,
			Func2<Object,String, Object[]>,
			Func1<Object,Integer>
		> _onMessage)
		{
			onMessage = _onMessage;
		}

		@Override
		public void handle(HttpExchange exchange) throws IOException
		{
			ResponseHandler handler = new ResponseHandler(exchange);
			onMessage.invoke(
				exchange.getRequestURI().toString(),
				readInputStream(exchange.getRequestBody()),
				exchange.getRequestMethod(),
				readHeaders(exchange.getRequestHeaders().entrySet()),
				handler.makeSendResponse(),
				handler.makeSetHeaders(),
				handler.makeResponseStatus()
			);
			FlowRuntime.eventLoop(false);
		}
	}

	static class ChunkedHandler extends HttpHandlerBase implements HttpHandler {
		private Func8<
			Object,
			String,
			String,
			String,
			Object[],
			Func0<Object>,
			Func1<String, String>,
			Func2<String, Integer, Boolean>,
			Func2<Object, String, Object[]>
		> onMessage;

		public ChunkedHandler(Func8<
			Object,
			String,
			String,
			String,
			Object[],
			Func0<Object>,
			Func1<String, String>,
			Func2<String, Integer, Boolean>,
			Func2<Object, String, Object[]>
		> _onMessage)
		{
			onMessage = _onMessage;
		}

		@Override
		public void handle(HttpExchange exchange) throws IOException
		{
			ResponseHandler handler = new ResponseHandler(exchange);
			onMessage.invoke(
				exchange.getRequestURI().toString(),
				readInputStream(exchange.getRequestBody()),
				exchange.getRequestMethod(),
				readHeaders(exchange.getRequestHeaders().entrySet()),
				handler.makeEndResponse(),
				handler.makeSendChunk(),
				handler.makeSendHeaders(),
				handler.makeSetHeaders()
			);
			FlowRuntime.eventLoop(false);
		}
	}

	abstract static class HttpHandlerBase implements HttpHandler {
		public String readInputStream(InputStream stream)
		{
			// https://stackoverflow.com/questions/309424/how-do-i-read-convert-an-inputstream-into-a-string-in-java
			try {
				ByteArrayOutputStream result = new ByteArrayOutputStream();
				byte[] buffer = new byte[1024];
				int length;
				while ((length = stream.read(buffer)) != -1) {
					result.write(buffer, 0, length);
				}
				return result.toString("UTF-8");
			} catch (IOException e) {
				throw new UncheckedIOException(e);
			}
		}

		public static String[][] readHeaders(Set<Map.Entry<String,List<String>>> entries)
		{
			String[][] result = new String[entries.size()][];
			int i = 0;
			for (Map.Entry<String,List<String>> entry : entries)
			{
				result[i] = entryToArray(entry);
				i++;
			}
			return result;
		}

		private static String[] entryToArray(Map.Entry<String,List<String>> entry)
		{
			String key = entry.getKey();
			List<String> values = entry.getValue();
			String[] result = new String[values.size() + 1];
			result[0] = key;
			for (int i = 0; i < values.size(); i++)
				result[i+1] = values.get(i);
			return result;
		}

		public static class ResponseHandler {
			private Integer responseStatusCode = 200;
			private HttpExchange exchange;
			private boolean hasBody;	// if the response has a body; HEAD request requires no body in the response.
			private OutputStream os;

			public ResponseHandler(HttpExchange _exchange)
			{
				exchange = _exchange;
				hasBody = !exchange.getRequestMethod().equals("HEAD");
			}

			public Func1<String, String> makeSendChunk() {
				return new Func1<String, String>() {
					public String invoke(String chunk) {
						if (chunk.equals("")) {
							return "";
						}
						try {
							if (hasBody) {
								os.write(chunk.getBytes("UTF-8"));
								os.flush();
								return "";
							} else {
								return "Do not include a body in the response for HEAD request";
							}
						} catch (IOException e) {
							return "Sending chunk error: " + e.getMessage();
						}
					}
				};
			}

			public Func0<Object> makeEndResponse() {
				return new Func0<Object>() {
					public Object invoke() {
						if (hasBody) {
							try {
								os.close();
							} catch (IOException e) {
								System.out.println("Ending response error: " + e.getMessage());
								e.printStackTrace(System.out);
							}
						}
						return null;
					}
				};
			}


			public Func1<Object,Integer> makeResponseStatus()
			{
				return new Func1<Object,Integer>()
				{
					public Object invoke(Integer code)
					{
						responseStatusCode = code;
						return null;
					}
				};
			}

			public Func1<Object,String> makeSendResponse()
			{
				return new Func1<Object,String>()
				{
					public Object invoke(String responseBody)
					{
						try {
							if (hasBody) {
								byte[] responseBytes = responseBody.getBytes("UTF-8");
								exchange.sendResponseHeaders(
									responseStatusCode,
									responseBytes.length
								);
								if (os == null) os = exchange.getResponseBody();
								os.write(responseBytes);
								os.close();
							} else {
								if (responseBody.length() > 0) {
									System.out.println("Sending response error: Do not include a body in the response for HEAD request");
								}
								exchange.sendResponseHeaders(
									responseStatusCode,
									-1
								);
							}
						} catch (IOException e) {
							System.out.println("Sending response error: " + e.getMessage());
							e.printStackTrace(System.out);
						}
						return null;
					}
				};
			}

			public Func2<Object,String,Object[]> makeSetHeaders()
			{
				return new Func2<Object,String,Object[]>()
				{
					public Object invoke(String key, Object[] value)
					{
						exchange
							.getResponseHeaders()
							.put(
								key,
								Arrays.stream(value)
									.map(Object::toString)
									.collect(Collectors.toList())
							);
						return null;
					}
				};
			}

			public Func2<String, Integer, Boolean> makeSendHeaders() {
				return new Func2<String, Integer, Boolean>() {
					public String invoke(Integer status, Boolean compressBody) {
						try {
							if (compressBody) {
								exchange.getResponseHeaders().put(
									"Content-Encoding",
									Collections.singletonList("gzip")
								);
							}
							if (hasBody) {
								exchange.sendResponseHeaders(status, 0);
								os = exchange.getResponseBody();
								if (compressBody) {
									os = new java.util.zip.GZIPOutputStream(os, true);
								}
							} else {
								exchange.sendResponseHeaders(status, -1);
							}
							return "";
						} catch (IOException e) {
							return "Sending headers error: " + e.getMessage();
						}
					}
				};
			}
		}
	}
}
