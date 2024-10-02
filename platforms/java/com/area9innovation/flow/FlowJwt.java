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

public class FlowJwt extends NativeHost {
	// value parameter - supposed to be a string representation of ISO date without milliseconds,
	// so we need to multiply the parsed value to 1000
	private static Date getDateFromIsoString(String value) throws NumberFormatException {
		return new Date(Long.parseLong(value) * 1000);
	}

	private static String date2formatIso8601(Date date) {
		TimeZone tz = TimeZone.getTimeZone("UTC");
		DateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm'Z'");
		df.setTimeZone(tz);
		return df.format(date);
	}

	public static String verifyJwt(String jwt, JWTVerifier verifier) {
		try {
			DecodedJWT jwtObj = verifier.verify(jwt);
			return "OK";
		} catch (JWTVerificationException e){
			System.out.println(jwt + "/" + e.getMessage());
			return "Wrong signature or expired";
		} catch (Exception e) {
			System.out.println(jwt + "/" + e.getMessage());
			return "Other exception";
		}
	}

	public static String verifyJwt(String jwt, String key) {
		JWTVerifier verifier = getVerifier(key);
		return verifyJwt(jwt, verifier);
	}

	private static JWTVerifier getVerifier(String key) {
		Algorithm algorithm = Algorithm.HMAC256(key);
		return JWT.require(algorithm).build();
	}

	public static Object decodeJwt(String jwt, String key, Func8<Object, String, String, String, String, String, String, String, String> callback, Func1<Object, String> onError) {
		JWTVerifier verifier = getVerifier(key);
		String verify = verifyJwt(jwt, verifier);
		if (verify == "OK") {
			String iss;
			String sub;
			List<String> aud;
			Date exp;
			Date nbf;
			Date iat;
			String jti;
			String impersonatedByUserId;
			try {
				DecodedJWT jwtObj = verifier.verify(jwt);

				iss = jwtObj.getIssuer();
				sub = jwtObj.getSubject();
				aud = jwtObj.getAudience();
				exp = jwtObj.getExpiresAt();
				nbf = jwtObj.getNotBefore();
				iat = jwtObj.getIssuedAt();
				//jti = jwtObj.getId();
				jti = jwtObj.getClaim("id").asString();
				impersonatedByUserId = jwtObj.getClaim("iid").asString();
			} catch (Exception e) {
				System.out.println(e.getMessage());
				onError.invoke("Hash problems");
				return null;
			}
			callback.invoke(
				(iss == null ? "" : iss),
				(sub == null ? "" : sub),
				(aud == null ? "" : aud.toString()),
				(exp == null ? "" : date2formatIso8601(exp)),
				(nbf == null ? "" : date2formatIso8601(nbf)),
				(iat == null ? "" : date2formatIso8601(iat)),
				jti == null ? "" : jti,
				impersonatedByUserId == null ? "" : impersonatedByUserId
			);
		} else {
			onError.invoke(verify);
		}
		return null;
	}

	public static String createJwt(String key, String issuer, String subject, String audience, String expiration, String notBefore, String issuedAt, String id) {
		try {
			Algorithm algorithm = Algorithm.HMAC256(key);
			JWTCreator.Builder builder = JWT.create();
			if (!issuer.isEmpty()) {
				builder = builder.withIssuer(issuer);
			}
			if (!subject.isEmpty()) {
				builder = builder.withSubject(subject);
			}
			if (!audience.isEmpty()) {
				builder = builder.withAudience(audience);
			}
			if (!issuedAt.isEmpty()) {
				builder = builder.withIssuedAt(getDateFromIsoString(issuedAt));
			} else {
				builder = builder.withIssuedAt(new Date());
			}
			if (!id.isEmpty()) {
				//builder = builder.withJWTId(id);
				builder = builder.withClaim("id", id);
			}
			if (!expiration.isEmpty()) {
				builder = builder.withExpiresAt(getDateFromIsoString(expiration));
			}
			if (!notBefore.isEmpty()) {
				builder = builder.withNotBefore(getDateFromIsoString(notBefore));
			}
			return builder.sign(algorithm);
		} catch (NumberFormatException e) {
			System.out.println(e.getMessage());
			return "";
		}
	}

	public static String createJwtClaims(String jwtKey, Object[] keys, Object[] values) {
		Algorithm algorithm = Algorithm.HMAC256(jwtKey);
		JWTCreator.Builder builder = JWT.create();
		for (int i = 0; i < keys.length; i++) {
			if (values[i] instanceof Double) {
				builder = builder.withClaim((String)keys[i], (Double)values[i]);
			} else if (values[i] instanceof Boolean) {
				builder = builder.withClaim((String)keys[i], (Boolean)values[i]);
			} else {
				// Assume string
				builder = builder.withClaim((String)keys[i], (String)values[i]);
			}
		}
		return builder.sign(algorithm);
	}

	public static PublicKey getPemPublicKeyFromString(String publicKeyPEM, String keyType) throws Exception {
		publicKeyPEM = publicKeyPEM.replace("-----BEGIN PUBLIC KEY-----", "");
		publicKeyPEM = publicKeyPEM.replace("-----END PUBLIC KEY-----", "");
		publicKeyPEM = publicKeyPEM.replaceAll("\\s", "");
		byte[] decodedPublicKey = Base64.getDecoder().decode(publicKeyPEM);

		KeyFactory kf = KeyFactory.getInstance(keyType);
		return kf.generatePublic(new java.security.spec.X509EncodedKeySpec(decodedPublicKey));
	}

	public static RSAPublicKey getRSAPublicKeyFromJsonString(String jsonStr) throws Exception {
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

	public static ECPublicKey getECPublicKeyFromJsonString(String jsonStr) throws Exception {
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

	public static String getJwtAlgHeader(String jwtStr) {
		try {
			DecodedJWT jwt = JWT.decode(jwtStr);
			String header = new String(Base64.getDecoder().decode(jwt.getHeader()), "UTF-8");
			JSONObject json = (JSONObject) new JSONParser().parse(header);
			return (String)json.get("alg");
		} catch (Exception e) {
			return "";
		}
	}

	public static String verifyJwtWithPublicKey(String jwtStr, String keyStr, String algorithmStr) {
		try {
			if (algorithmStr.equals("")) {
				algorithmStr = getJwtAlgHeader(jwtStr);
				if (algorithmStr.equals("")) {
					return "Algorithm is not specified";
				}
			}
			Algorithm algorithm = null;
			if (algorithmStr.equals("RS256") || algorithmStr.equals("RS384") || algorithmStr.equals("RS512")) {
				RSAPublicKey publicKey = null;
				if (keyStr.startsWith("{")) {
					publicKey = getRSAPublicKeyFromJsonString(keyStr);
				} else {
					publicKey = (RSAPublicKey)getPemPublicKeyFromString(keyStr, "RSA");
				}
				if (algorithmStr.equals("RS256")) {
					algorithm = Algorithm.RSA256(publicKey, null);
				} else if (algorithmStr.equals("RS384")) {
					algorithm = Algorithm.RSA384(publicKey, null);
				} else {
					algorithm = Algorithm.RSA512(publicKey, null);
				}
			} else if (algorithmStr.equals("ES256") || algorithmStr.equals("ES384") || algorithmStr.equals("ES512")) {
				ECPublicKey publicKey = null;
				if (keyStr.startsWith("{")) {
					publicKey = getECPublicKeyFromJsonString(keyStr);
				} else {
					publicKey = (ECPublicKey)getPemPublicKeyFromString(keyStr, "EC");
				}
				if (algorithmStr.equals("ES256")) {
					algorithm = Algorithm.ECDSA256(publicKey, null);
				} else if (algorithmStr.equals("ES384")) {
					algorithm = Algorithm.ECDSA384(publicKey, null);
				} else {
					algorithm = Algorithm.ECDSA512(publicKey, null);
				}
			} else {
				return "Algorithm not supported";
			}
			JWTVerifier verifier = JWT.require(algorithm).build();
			verifier.verify(jwtStr);
			return "OK";
		} catch (Exception e) {
			return e.getMessage();
		}
	}
}
