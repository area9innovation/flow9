package com.area9innovation.flow;

import java.io.File;
import java.net.URL;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;

public class FlowSelfTimestamp extends NativeHost {

	/**
	 * Returns the UTC timestamp of the Jar file as an ISO 8601 string.
	 * Assumes the class is running from a JAR file.
	 *
	 * @return ISO timestamp string (e.g., "2025-06-20T10:44:06Z")
	 */
	public static String selfTimestamp() {
		try {
			URL resource = FlowSelfTimestamp.class.getResource(
				FlowSelfTimestamp.class.getSimpleName() + ".class"
			);

			String jarPath = resource.getPath();
			String jarFilePath = jarPath.substring(5, jarPath.indexOf("!"));
			File jarFile = new File(jarFilePath);

			long millis = jarFile.lastModified();
			long seconds = millis / 1000; // Truncate to seconds
			LocalDateTime dateTime = LocalDateTime.ofEpochSecond(seconds, 0, ZoneOffset.UTC);
			return dateTime.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME) + "Z";

		} catch (Exception e) {
			System.out.println("selfTimestamp exception: " + e.getMessage());
			return ""; 
		}
	}
}
