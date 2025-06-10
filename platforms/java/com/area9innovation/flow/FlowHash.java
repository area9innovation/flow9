package com.area9innovation.flow;

import java.io.*;
import java.util.*;
import java.text.*;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigInteger;
import java.security.*;
import java.security.interfaces.*;
import java.security.spec.*;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.json.simple.*;
import org.json.simple.parser.*;

import com.auth0.jwt.JWTVerifier.*;
import com.auth0.jwt.interfaces.*;
import com.auth0.jwt.exceptions.*;
import com.auth0.jwt.algorithms.*;
import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTCreator;

public class FlowHash extends NativeHost 
{

	private static byte[] getLower8Bits(String input) {
		byte[] result = new byte[input.length()];
		for (int i = 0; i < input.length(); i++) {
			int c = input.charAt(i);
			byte b = (byte)c; // Truncates to lower 8 bits

			if (c == b) {
				result[i] = b;
			} else {
				return null;
			}
		}
		return result;
	}

	// Calculate the hash function, for an 8 bit binary string. 
	// Only the lower 8 bit of the string is used. 
	// If it is not 8 bit an empty string is returned.
	// If it is not a known algorithm an empty string is returned. 
	public static String hashAlgorithm(String binarySourceStr, String algorithmStr) {
		try {
			MessageDigest digest;

			// Check supported algorithms
			switch (algorithmStr) {
				case "sha1":
					digest = MessageDigest.getInstance("SHA-1");
					break;
				case "sha256":
					digest = MessageDigest.getInstance("SHA-256");
					break;
				case "md5":
					digest = MessageDigest.getInstance("MD5");
					break;
				default:
					return "";
			}

			// byte[] sourceBytes = binarySourceStr.getBytes("ISO-8859-1");
			byte[] sourceBytes = getLower8Bits(binarySourceStr);
			if (sourceBytes == null) {
				// Not 8 bit string
				return "";
			} else {
				// System.out.println("sourceBytes: " + Arrays.toString(sourceBytes));

				// Calculate hash
				byte[] hashBytes = digest.digest(sourceBytes);

				// Return binary hash value directly as string. ISO-8859-1 will preserve the lower 8 bits. 
				return new String(hashBytes, "ISO-8859-1");
			}
		} catch (Exception e) {
			System.out.println("hashAlgorithm exception: " + e.getMessage());
			return "";
		}
	}
}
