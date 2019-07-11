package com.area9innovation.flow;

import com.sun.net.httpserver.*;
import java.net.InetSocketAddress;
import java.util.*;
import java.util.stream.Collectors;
import java.io.*;
import java.security.*;
import javax.net.ssl.*;

public class HttpServerSupport extends NativeHost
{

	public Object createHttpServerNative(
		int port,
		boolean isHttps,
		String pfxPath,
		String pfxPassword,
		Func0<Object> onOpen,
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
	)
	{
		try
		{
			if (isHttps)
			{
				HttpsServer server = HttpsServer.create();
				SSLContext sslContext = setupSSLContext(pfxPath, pfxPassword);
				configureHttpsServer(server, sslContext);

				server.bind(new InetSocketAddress(port), 0);

				HttpContext context =
					server.createContext("/", new EchoHandler(onMessage));

				server.start();

				return server;
			}
			else
			{
				HttpServer server = HttpServer.create();
				server.bind(new InetSocketAddress(port), 0);

				HttpContext context =
					server.createContext("/", new EchoHandler(onMessage));

				server.start();
				onOpen.invoke();

				return server;
			}
		}
		catch (Exception e)
		{
			System.out.println(e);
			System.out.println("Failed to create HTTPS server");
			return null;
		}
	}

	public Object closeHttpServerNative(Object server)
	{
		( (HttpServer)server ).stop(0);
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

	static class EchoHandler implements HttpHandler {
		private Func7<
			Object,
			String,
			String,
			String,
			Object[],
			Func1<Object,String>,
			Func2<Object,String,Object[]>,
			Func1<Object,Integer>
		> onMessage;

		public EchoHandler(Func7<
			Object,
			String,
			String,
			String,
			Object[],
			Func1<Object,String>,
			Func2<Object,String,Object[]>,
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
		}

		private static String readInputStream(InputStream stream)
		{
			return
				new BufferedReader(new InputStreamReader(stream))
					.lines()
					.collect(Collectors.joining("\n"));
		}

		private static String[][] readHeaders(Set<Map.Entry<String,List<String>>> entries)
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

		private static class ResponseHandler {
			private Integer responseStatusCode = 200;
			private HttpExchange exchange;

			public ResponseHandler(HttpExchange _exchange)
			{
				exchange = _exchange;
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
						try
						{
							byte[] responseBytes = responseBody.getBytes();
							exchange.sendResponseHeaders(
								responseStatusCode, 
								responseBytes.length
							);
							OutputStream os = exchange.getResponseBody();
							os.write(responseBytes);
							os.close();
						}
						catch (IOException e)
						{
							System.out.println(e);
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
		}
	}
}