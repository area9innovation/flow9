package com.area9innovation.flow;
import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;

public class Hash extends NativeHost 
{

	private static String bytesToHex(byte[] hash) {
		StringBuilder hexString = new StringBuilder(2 * hash.length);

		for (byte b : hash) {
			String hex = Integer.toHexString(0xff & b);
			if (hex.length() == 1) {
				hexString.append('0');
			}
			hexString.append(hex);
		}
		return hexString.toString();
	}

	public static String sha256(String input) {
		try {
			MessageDigest digest = MessageDigest.getInstance("SHA-256");
			
			byte[] encodedhash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
			
			return bytesToHex(encodedhash);
			
		} catch (Exception e) {
			System.out.println("sha256 exception: " + e.getMessage());
			return "";
		}
	}
}
