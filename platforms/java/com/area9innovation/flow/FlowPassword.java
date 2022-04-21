// WARNING: if this file is changed keep in mind that 
// innovation/components/oauth/www/oauth/utils/security.php should be 
// adjusted as well and vice versa

package com.area9innovation.flow;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.spec.KeySpec;
import java.security.SecureRandom;
import java.security.NoSuchAlgorithmException;
import java.security.spec.InvalidKeySpecException;
import java.util.Base64;
import java.util.Arrays;
import java.util.Random;

public class FlowPassword extends NativeHost {
	public static final String PBKDF2_HASH_ALGORITHM = "sha256";
	public static final int PBKDF2_ITERATIONS = 310000;
	public static final int PBKDF2_SALT_BYTE_SIZE = 24;
	public static final int PBKDF2_HASH_BYTE_SIZE = 24;

	public static final int HASH_SECTIONS = 4;
	public static final int HASH_ALGORITHM_INDEX = 0;
	public static final int HASH_ITERATION_INDEX = 1;
	public static final int HASH_SALT_INDEX = 2;
	public static final int HASH_PBKDF2_INDEX = 3;

	public static String createSalt() {
		byte[] bytes = new byte[PBKDF2_SALT_BYTE_SIZE];
		new SecureRandom().nextBytes(bytes);
		return Base64.getEncoder().encodeToString(bytes);
	}

	public static String createHash(String password) {
		String salt = createSalt();

		return PBKDF2_HASH_ALGORITHM + ":" + 
			PBKDF2_ITERATIONS + ":" + 
			salt + ":" +
			Base64.getEncoder().encodeToString(
				pbkdf2(
					PBKDF2_HASH_ALGORITHM,
					password,
					salt,
					PBKDF2_ITERATIONS,
					PBKDF2_HASH_BYTE_SIZE
				)
			);
	}

	public static byte[] pbkdf2(String algorithm, String password, String salt, int iterations, int keyLength) {
		byte[] ret = null;

		try {
			KeySpec spec = new PBEKeySpec(
				password.toCharArray(),
				salt.getBytes(),
				iterations,
				keyLength * 8
			);

			String alg = null;

			switch (algorithm) {
				case "sha256":
					alg = "PBKDF2WithHmacSHA256";
					break;
				default: 
					throw new NoSuchAlgorithmException("Algorithm doesn't supported");
			}

			SecretKeyFactory f = SecretKeyFactory.getInstance(alg);

			ret = f.generateSecret(spec).getEncoded();
		} catch (NoSuchAlgorithmException | InvalidKeySpecException ex) {
			System.out.println(ex.getMessage());
			ex.printStackTrace();
		}

		return ret;
	}

	public static Boolean validateHash(String password, String hash) {
		String[] params = hash.split(":");

		if (params.length < HASH_SECTIONS) 
			return false;

		byte[] correctpbkdf2 = Base64.getDecoder().decode(params[HASH_PBKDF2_INDEX]);
		byte[] requestedpbkdf2 = pbkdf2(
			params[HASH_ALGORITHM_INDEX],
			password,
			params[HASH_SALT_INDEX],
			Integer.parseInt(params[HASH_ITERATION_INDEX]),
			correctpbkdf2.length
		);
			
		return Arrays.equals(correctpbkdf2, requestedpbkdf2);
	}
}
