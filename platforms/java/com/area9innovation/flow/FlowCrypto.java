package com.area9innovation.flow;

import javax.crypto.Cipher;
import javax.crypto.Mac;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;

public class FlowCrypto extends NativeHost {
	private static final int GCM_IV_BYTES  = 12;
	private static final int GCM_TAG_BITS  = 128;
	private static final int GCM_TAG_BYTES = GCM_TAG_BITS / 8; // 16

	// Derive a 32-byte AES-256 key from an arbitrary-length string via SHA-256.
	// Must stay in sync with PHP: hash('sha256', $key, true)
	private static byte[] deriveKey(String key) throws Exception {
		return MessageDigest.getInstance("SHA-256").digest(key.getBytes("UTF-8"));
	}

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

	private static byte[] hexToBytes(String hex) {
		int len = hex.length();
		byte[] data = new byte[len / 2];
		for (int i = 0; i < len; i += 2) {
			data[i / 2] = (byte) ((Character.digit(hex.charAt(i), 16) << 4)
				+ Character.digit(hex.charAt(i + 1), 16));
		}
		return data;
	}

	// Encrypt plaintext with AES-256-GCM.
	// Returns "{iv_hex}-{ciphertext_hex}-{tag_hex}" or "" on error.
	// The '-' separator is chosen because it is URL-safe (RFC 3986 unreserved).
	public static String encryptAesGcm(String plaintext, String key) {
		try {
			byte[] keyBytes = deriveKey(key);
			byte[] iv = new byte[GCM_IV_BYTES];
			new SecureRandom().nextBytes(iv);

			Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
			cipher.init(Cipher.ENCRYPT_MODE,
				new SecretKeySpec(keyBytes, "AES"),
				new GCMParameterSpec(GCM_TAG_BITS, iv));

			// Java appends the tag at the end of the ciphertext bytes
			byte[] ciphertextWithTag = cipher.doFinal(plaintext.getBytes("UTF-8"));

			int ciphertextLen = ciphertextWithTag.length - GCM_TAG_BYTES;
			byte[] ciphertext = new byte[ciphertextLen];
			byte[] tag        = new byte[GCM_TAG_BYTES];
			System.arraycopy(ciphertextWithTag, 0,             ciphertext, 0, ciphertextLen);
			System.arraycopy(ciphertextWithTag, ciphertextLen, tag,        0, GCM_TAG_BYTES);

			return bytesToHex(iv) + "-" + bytesToHex(ciphertext) + "-" + bytesToHex(tag);
		} catch (Exception e) {
			return "";
		}
	}

	// Decrypt a token produced by encryptAesGcm (or its PHP counterpart).
	// Returns the plaintext on success, or "Error in decryptAesGcmNative: <reason>" on any failure.
	// The Flow wrapper in crypto_aes.flow converts this to None() via startsWith check.
	public static String decryptAesGcm(String encryptedData, String key) {
		try {
			String[] parts = encryptedData.split("-", 3);
			if (parts.length != 3) return "Error in decryptAesGcmNative: invalid token format";

			byte[] iv         = hexToBytes(parts[0]);
			byte[] ciphertext = hexToBytes(parts[1]);
			byte[] tag        = hexToBytes(parts[2]);

			if (iv.length != GCM_IV_BYTES)  return "Error in decryptAesGcmNative: invalid IV length";
			if (tag.length != GCM_TAG_BYTES) return "Error in decryptAesGcmNative: invalid tag length";

			byte[] keyBytes   = deriveKey(key);

			// Java GCM expects ciphertext || tag concatenated
			byte[] ciphertextWithTag = new byte[ciphertext.length + GCM_TAG_BYTES];
			System.arraycopy(ciphertext, 0, ciphertextWithTag, 0,             ciphertext.length);
			System.arraycopy(tag,        0, ciphertextWithTag, ciphertext.length, GCM_TAG_BYTES);

			Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
			cipher.init(Cipher.DECRYPT_MODE,
				new SecretKeySpec(keyBytes, "AES"),
				new GCMParameterSpec(GCM_TAG_BITS, iv));

			return new String(cipher.doFinal(ciphertextWithTag), "UTF-8");
		} catch (Exception e) {
			return "Error in decryptAesGcmNative: " + e.getMessage();
		}
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

	public static String hmacSha256(String input, String key) {
		String algorithm = "HmacSHA256";
		SecretKeySpec secretKeySpec = new SecretKeySpec(
			key.getBytes(StandardCharsets.UTF_8), 
			algorithm
		);
		try {
			Mac mac = Mac.getInstance(algorithm);
			mac.init(secretKeySpec);
			byte[] hmacBytes = mac.doFinal(input.getBytes(StandardCharsets.UTF_8));
			return bytesToHex(hmacBytes);
		} catch (Exception e) {
			System.out.println("hmacSha256 exception: " + e.getMessage());
			return "";
		}
	}
}
