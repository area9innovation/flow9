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
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.json.simple.*;
import org.json.simple.parser.*;

import com.auth0.jwt.JWTVerifier.*;
import com.auth0.jwt.interfaces.*;
import com.auth0.jwt.exceptions.*;
import com.auth0.jwt.algorithms.*;
import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTCreator;

public class FlowJwt extends NativeHost {
	// value parameter - supposed to be a string representation of ISO date without milliseconds,
	// so we need to multiply the parsed value to 1000
	private static Date getDateFromIsoString(String value) throws NumberFormatException {
		return new Date(Long.parseLong(value) * 1000);
	}

	private static String date2formatIso8601(Date date) {
		return date.toInstant().toString();
	}

	private static JWTVerifier getVerifier(String alg, String key) throws Exception {
		Algorithm algorithm = null;
		// Convert the key string to UTF8 bytes
		if (alg.equals("HS256")) {
			algorithm = Algorithm.HMAC256(key);
		} else if (alg.equals("HS384")) {
			algorithm = Algorithm.HMAC384(key);
		} else if (alg.equals("HS512")) {
			algorithm = Algorithm.HMAC512(key);
		} else if (alg.equals("RS256") || alg.equals("RS384") || alg.equals("RS512")) {
			RSAPublicKey publicKey = null;
			if (key.startsWith("{")) {
				publicKey = getRSAPublicKeyFromJsonString(key);
			} else {
				publicKey = (RSAPublicKey)getPemPublicKeyFromString(key, "RSA");
			}
			if (alg.equals("RS256")) {
				algorithm = Algorithm.RSA256(publicKey, null);
			} else if (alg.equals("RS384")) {
				algorithm = Algorithm.RSA384(publicKey, null);
			} else {
				algorithm = Algorithm.RSA512(publicKey, null);
			}
		} else if (alg.equals("ES256") || alg.equals("ES384") || alg.equals("ES512")) {
			ECPublicKey publicKey = null;
			if (key.startsWith("{")) {
				publicKey = getECPublicKeyFromJsonString(key);
			} else {
				publicKey = (ECPublicKey)getPemPublicKeyFromString(key, "EC");
			}
			if (alg.equals("ES256")) {
				algorithm = Algorithm.ECDSA256(publicKey, null);
			} else if (alg.equals("ES384")) {
				algorithm = Algorithm.ECDSA384(publicKey, null);
			} else {
				algorithm = Algorithm.ECDSA512(publicKey, null);
			}
		}

		return (algorithm == null) ? null : JWT.require(algorithm).acceptLeeway(300).build();
	}

	private static PublicKey getPemPublicKeyFromString(String publicKeyPEM, String keyType) throws Exception {
		publicKeyPEM = publicKeyPEM.replace("-----BEGIN PUBLIC KEY-----", "");
		publicKeyPEM = publicKeyPEM.replace("-----END PUBLIC KEY-----", "");
		publicKeyPEM = publicKeyPEM.replaceAll("\\s", "");
		byte[] decodedPublicKey = Base64.getDecoder().decode(publicKeyPEM);

		KeyFactory kf = KeyFactory.getInstance(keyType);
		return kf.generatePublic(new java.security.spec.X509EncodedKeySpec(decodedPublicKey));
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
			JWTVerifier verifier = getVerifier(alg, key);
			if (verifier != null) {
				DecodedJWT jwtObj = verifier.verify(jwt);

				payload = new String(Base64.getDecoder().decode(jwtObj.getPayload()), StandardCharsets.UTF_8);
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
			Algorithm alg = null;
			Map<String, Object> headerClaims = new HashMap<>();
			if (algorithm.equals("HS256")) {
				alg = Algorithm.HMAC256(key);
				if (!kid.isEmpty()) {
					return "Error: kid is not supported";
				}
			} else if (algorithm.equals("HS384")) {
				alg = Algorithm.HMAC384(key);
				if (!kid.isEmpty()) {
					return "Error: kid is not supported";
				}
			} else if (algorithm.equals("HS512")) {
				alg = Algorithm.HMAC512(key);
				if (!kid.isEmpty()) {
					return "Error: kid is not supported";
				}
			} else if (algorithm.equals("RS256")) {
				alg = Algorithm.RSA256(null, (RSAPrivateKey)getPemRsaPkcs8PrivateKeyFromString(key));
				if (!kid.isEmpty()) {
					headerClaims = new HashMap<>();
					headerClaims.put("kid", kid);
				}
			} else if (algorithm.equals("RS384")) {
				alg = Algorithm.RSA384(null, (RSAPrivateKey)getPemRsaPkcs8PrivateKeyFromString(key));
				if (!kid.isEmpty()) {
					headerClaims = new HashMap<>();
					headerClaims.put("kid", kid);
				}
			} else if (algorithm.equals("RS512")) {
				alg = Algorithm.RSA512(null, (RSAPrivateKey)getPemRsaPkcs8PrivateKeyFromString(key));
				if (!kid.isEmpty()) {
					headerClaims = new HashMap<>();
					headerClaims.put("kid", kid);
				}
			} else {
				return "Error: Algorithm not supported";
			}
			JWTCreator.Builder builder = (headerClaims == null ? JWT.create() : JWT.create()).withHeader(headerClaims).withPayload(jsonClaims);
			return builder.sign(alg);
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
			JWTVerifier verifier = getVerifier(algorithmStr, keyStr);

			if (verifier == null) {
				return "Algorithm not supported";
			} else {
				verifier.verify(jwtStr);
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
