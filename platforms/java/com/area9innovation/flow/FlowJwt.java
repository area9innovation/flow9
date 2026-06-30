package com.area9innovation.flow;

import java.io.*;
import java.util.*;
import java.text.*;
import java.nio.charset.StandardCharsets;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigInteger;
import java.security.*;
import java.security.interfaces.*;
import java.security.spec.*;
import org.bouncycastle.asn1.ASN1ObjectIdentifier;
import org.bouncycastle.asn1.x9.ECNamedCurveTable;
import org.bouncycastle.asn1.x9.X9ECParameters;
import org.bouncycastle.jce.spec.ECNamedCurveSpec;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.json.simple.*;
import org.json.simple.parser.*;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.JwtBuilder;
import io.jsonwebtoken.JwtParser;
import io.jsonwebtoken.JwtParserBuilder;

// JWT handling was migrated from com.auth0:java-jwt (which pulled in FasterXML/Jackson) to
// io.jsonwebtoken:jjwt with the Gson backend, so Jackson is no longer a dependency.
// Behavioural note: JJWT enforces the RFC 7518 minimum HMAC key sizes (>= 256/384/512 bits for
// HS256/HS384/HS512); auth0 accepted any length. Shorter HMAC secrets now fail with a
// WeakKeyException instead of silently signing/verifying.
public class FlowJwt extends NativeHost {
	// value parameter - supposed to be a string representation of ISO date without milliseconds,
	// so we need to multiply the parsed value to 1000
	private static Date getDateFromIsoString(String value) throws NumberFormatException {
		return new Date(Long.parseLong(value) * 1000);
	}

	private static String date2formatIso8601(Date date) {
		return date.toInstant().toString();
	}

	// auth0's Algorithm.HMACxxx used the raw UTF-8 bytes of the key string directly with no
	// length restriction. We reject too-short secrets explicitly (RFC 7518, Section 3.2 requires
	// an HMAC key of at least the hash output size) so the failure is the same and is clearly
	// reported on both the signing and verification paths, rather than relying on JJWT's
	// internal check firing later. See also the migration note in the class header.
	private static SecretKey getHmacKey(String alg, String key) {
		byte[] keyBytes = key.getBytes(StandardCharsets.UTF_8);
		int requiredBits = Integer.parseInt(alg.substring(2)); // HS256 -> 256, HS384 -> 384, HS512 -> 512
		if (keyBytes.length * 8 < requiredBits) {
			throw new io.jsonwebtoken.security.WeakKeyException(
				"The HMAC key for " + alg + " must be at least " + requiredBits + " bits ("
				+ (requiredBits / 8) + " bytes), but the provided key is only " + (keyBytes.length * 8)
				+ " bits (" + keyBytes.length + " bytes). See RFC 7518, Section 3.2.");
		}
		return new SecretKeySpec(keyBytes, "HmacSHA" + alg.substring(2));
	}

	// Resolves the key used to verify a token for the given algorithm.
	// Returns null if the algorithm is not supported.
	private static Key getVerificationKey(String alg, String key) throws Exception {
		if (alg.equals("HS256") || alg.equals("HS384") || alg.equals("HS512")) {
			return getHmacKey(alg, key);
		} else if (alg.equals("RS256") || alg.equals("RS384") || alg.equals("RS512")) {
			return key.startsWith("{")
				? getRSAPublicKeyFromJsonString(key)
				: (RSAPublicKey)getPemPublicKeyFromString(key, "RSA");
		} else if (alg.equals("ES256") || alg.equals("ES384") || alg.equals("ES512")) {
			return key.startsWith("{")
				? getECPublicKeyFromJsonString(key)
				: (ECPublicKey)getPemPublicKeyFromString(key, "EC");
		}
		return null;
	}

	// Builds a parser that verifies the signature and the temporal claims (exp/nbf/iat).
	// The 300s clock skew matches the previous auth0 acceptLeeway(300) behaviour.
	private static JwtParser buildParser(Key verificationKey) {
		JwtParserBuilder builder = Jwts.parser().clockSkewSeconds(300);
		if (verificationKey instanceof SecretKey) {
			builder = builder.verifyWith((SecretKey)verificationKey);
		} else {
			builder = builder.verifyWith((PublicKey)verificationKey);
		}
		return builder.build();
	}

	private static PublicKey getPemPublicKeyFromString(String publicKeyPEM, String keyType) throws Exception {
		publicKeyPEM = publicKeyPEM.replace("-----BEGIN PUBLIC KEY-----", "");
		publicKeyPEM = publicKeyPEM.replace("-----END PUBLIC KEY-----", "");
		publicKeyPEM = publicKeyPEM.replaceAll("\\s", "");
		byte[] decodedPublicKey = Base64.getDecoder().decode(publicKeyPEM);

		KeyFactory kf = KeyFactory.getInstance(keyType);
		return kf.generatePublic(new java.security.spec.X509EncodedKeySpec(decodedPublicKey));
	}

	private static PrivateKey getPemEcPkcs8PrivateKeyFromString(String privateKeyPEM) throws Exception {
		boolean isPkcs1 = privateKeyPEM.contains("BEGIN EC PRIVATE KEY");
		// Strip any PEM header/footer lines (handles both PKCS#8 and PKCS#1 formats)
		String key = privateKeyPEM.replaceAll("-----[A-Z ]+-----", "").replaceAll("\\s", "");
		// Decode the Base64 string
		byte[] keyBytes = Base64.getDecoder().decode(key);

		KeyFactory keyFactory = KeyFactory.getInstance("EC");
		if (isPkcs1) {
			// PKCS#1 (EC PRIVATE KEY) format: parse ASN.1 and build ECPrivateKeySpec
			org.bouncycastle.asn1.sec.ECPrivateKey ecKey =
				org.bouncycastle.asn1.sec.ECPrivateKey.getInstance(keyBytes);
			ASN1ObjectIdentifier curveOid = ASN1ObjectIdentifier.getInstance(ecKey.getParametersObject());
			X9ECParameters ecParams = ECNamedCurveTable.getByOID(curveOid);
			ECParameterSpec parameterSpec = new ECNamedCurveSpec(ECNamedCurveTable.getName(curveOid), ecParams.getCurve(), ecParams.getG(), ecParams.getN(), ecParams.getH(), ecParams.getSeed());
			ECPrivateKeySpec keySpec = new ECPrivateKeySpec(ecKey.getKey(), parameterSpec);
			return keyFactory.generatePrivate(keySpec);
		} else {
			// PKCS#8 (PRIVATE KEY) format: use directly
			PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(keyBytes);
			return keyFactory.generatePrivate(keySpec);
		}
	}

	// NOTE: If bcpkix-jdk18on is added to lib/, this entire method can be replaced with:
	//   PEMParser parser = new PEMParser(new StringReader(privateKeyPEM));
	//   JcaPEMKeyConverter converter = new JcaPEMKeyConverter();
	//   return converter.getPrivateKey((PrivateKeyInfo) parser.readObject());
	// This handles all PEM formats (PKCS#1, PKCS#8, encrypted keys) automatically.
	private static PrivateKey getPemRsaPkcs8PrivateKeyFromString(String privateKeyPEM) throws Exception {
		boolean isPkcs1 = privateKeyPEM.contains("BEGIN RSA PRIVATE KEY");
		// Strip any PEM header/footer lines (handles both PKCS#8 and PKCS#1 formats)
		String key = privateKeyPEM.replaceAll("-----[A-Z ]+-----", "").replaceAll("\\s", "");
        // Decode the Base64 string
        byte[] keyBytes = Base64.getDecoder().decode(key);

        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        if (isPkcs1) {
            // PKCS#1 (RSA PRIVATE KEY) format: parse ASN.1 and build RSAPrivateCrtKeySpec
            org.bouncycastle.asn1.pkcs.RSAPrivateKey rsaKey =
                org.bouncycastle.asn1.pkcs.RSAPrivateKey.getInstance(keyBytes);
            RSAPrivateCrtKeySpec keySpec = new RSAPrivateCrtKeySpec(
                rsaKey.getModulus(),
                rsaKey.getPublicExponent(),
                rsaKey.getPrivateExponent(),
                rsaKey.getPrime1(),
                rsaKey.getPrime2(),
                rsaKey.getExponent1(),
                rsaKey.getExponent2(),
                rsaKey.getCoefficient()
            );
            return keyFactory.generatePrivate(keySpec);
        } else {
            // PKCS#8 (PRIVATE KEY) format: use directly
            PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(keyBytes);
            return keyFactory.generatePrivate(keySpec);
        }
	}

	private static RSAPublicKey getRSAPublicKeyFromJsonString(String jsonStr) throws Exception {
		JSONObject json = (JSONObject) new JSONParser().parse(jsonStr);
		String n = (String)json.get("n");
		String e = (String)json.get("e");
		BigInteger n2 = new BigInteger(1, Base64.getUrlDecoder().decode(n));
		BigInteger e2 = new BigInteger(1, Base64.getUrlDecoder().decode(e));
		RSAPublicKeySpec spec = new RSAPublicKeySpec(n2, e2);

		KeyFactory kf = KeyFactory.getInstance("RSA");
		RSAPublicKey pubKey = (RSAPublicKey) kf.generatePublic(spec);
		return pubKey;
	}

	private static ECPublicKey getECPublicKeyFromJsonString(String jsonStr) throws Exception {
		JSONObject json = (JSONObject) new JSONParser().parse(jsonStr);
		String x = (String)json.get("x");
		String y = (String)json.get("y");
		BigInteger x2 = new BigInteger(1, Base64.getUrlDecoder().decode(x));
		BigInteger y2 = new BigInteger(1, Base64.getUrlDecoder().decode(y));

		AlgorithmParameters algoParameters = AlgorithmParameters.getInstance("EC", new BouncyCastleProvider());
		algoParameters.init(new ECGenParameterSpec((String)json.get("crv")));
		ECParameterSpec parameterSpec = algoParameters.getParameterSpec(ECParameterSpec.class);
		ECPublicKeySpec spec = new ECPublicKeySpec(new ECPoint(x2, y2), parameterSpec);

		KeyFactory kf = KeyFactory.getInstance("EC");
		ECPublicKey pubKey = (ECPublicKey) kf.generatePublic(spec);
		return pubKey;
	}

	public static Object decodeJwt(String jwt, String alg, String key, Func1<Object, String> callback, Func1<Object, String> onError) {
		boolean isError = true;
		String errorMessage = "decodeJwt internal error"; // If it happens, it means that the error handling code is broken.

		String payload = null;
		try {
			Key verificationKey = getVerificationKey(alg, key);
			if (verificationKey != null) {
				// Verifies the signature and the temporal claims (exp/nbf/iat) with leeway.
				buildParser(verificationKey).parseSignedClaims(jwt);

				// The signature is verified, so return the raw payload exactly as in the token.
				String[] parts = jwt.split("\\.");
				payload = new String(Base64.getUrlDecoder().decode(parts[1]), StandardCharsets.UTF_8);
				isError = false;
			} else {
				errorMessage = "Algorithm not supported";
			}
		} catch (Exception e) {
			errorMessage = e.getMessage();
		}

		if (isError) {
			onError.invoke(errorMessage);
		} else {
			callback.invoke(payload);
		}
		return null;
	}

	public static String createJwtAlgorithm(String key, String jsonClaims, String algorithm, String kid) {
		try {
			boolean isHmac = algorithm.equals("HS256") || algorithm.equals("HS384") || algorithm.equals("HS512");
			if (isHmac && !kid.isEmpty()) {
				return "Error: kid is not supported";
			}

			// Parse the claims JSON into a map. json-simple keeps integers as Long and decimals
			// as Double, so numeric claims (exp, iat, ...) keep their original JSON number type.
			Object parsedClaims = new JSONParser().parse(jsonClaims);
			if (!(parsedClaims instanceof Map)) {
				return "Error: Claims must be a JSON object";
			}
			@SuppressWarnings("unchecked")
			Map<String, Object> claims = (Map<String, Object>)parsedClaims;

			JwtBuilder builder = Jwts.builder();
			if (!kid.isEmpty()) {
				builder.header().keyId(kid).and();
			}
			builder.claims(claims);

			switch (algorithm) {
				case "HS256": builder.signWith(getHmacKey(algorithm, key), Jwts.SIG.HS256); break;
				case "HS384": builder.signWith(getHmacKey(algorithm, key), Jwts.SIG.HS384); break;
				case "HS512": builder.signWith(getHmacKey(algorithm, key), Jwts.SIG.HS512); break;
				case "RS256": builder.signWith((RSAPrivateKey)getPemRsaPkcs8PrivateKeyFromString(key), Jwts.SIG.RS256); break;
				case "RS384": builder.signWith((RSAPrivateKey)getPemRsaPkcs8PrivateKeyFromString(key), Jwts.SIG.RS384); break;
				case "RS512": builder.signWith((RSAPrivateKey)getPemRsaPkcs8PrivateKeyFromString(key), Jwts.SIG.RS512); break;
				case "ES256": builder.signWith((ECPrivateKey)getPemEcPkcs8PrivateKeyFromString(key), Jwts.SIG.ES256); break;
				case "ES384": builder.signWith((ECPrivateKey)getPemEcPkcs8PrivateKeyFromString(key), Jwts.SIG.ES384); break;
				case "ES512": builder.signWith((ECPrivateKey)getPemEcPkcs8PrivateKeyFromString(key), Jwts.SIG.ES512); break;
				default: return "Error: Algorithm not supported";
			}
			return builder.compact();
		} catch (Exception e) {
			// Some exceptions have a null getMessage value
			String message = e.getMessage();
			if (message == null || message.isEmpty()) {
				String simpleName = e.getClass().getSimpleName();
				if (simpleName == null || simpleName.isEmpty()) {
					return "Error: Exception";
				} else {
					return "Error: " + simpleName;
				}
			} else {
				return "Error: " + message;
			}
		}
	}


	public static String verifyJwtAlgorithm(String jwtStr, String keyStr, String algorithmStr) {
		try {
			Key verificationKey = getVerificationKey(algorithmStr, keyStr);

			if (verificationKey == null) {
				return "Algorithm not supported";
			} else {
				buildParser(verificationKey).parseSignedClaims(jwtStr);
				return "OK";
			}
		} catch (Exception e) {
			// Some exceptions have a null getMessage value
			String message = e.getMessage();
			if (message == null || message.isEmpty()) {
				String simpleName = e.getClass().getSimpleName();
				if (simpleName == null || simpleName.isEmpty()) {
					return "Exception";
				} else {
					return simpleName;
				}
			} else {
				return message;
			}
		}
	}
}
