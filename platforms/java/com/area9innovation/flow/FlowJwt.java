package com.area9innovation.flow;

import java.util.*;
import io.jsonwebtoken.*;
import io.jsonwebtoken.lang.*;
import io.jsonwebtoken.security.Keys;
import io.jsonwebtoken.security.SecurityException;
import java.text.ParseException;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import static io.jsonwebtoken.Claims.*;

public class FlowJwt extends NativeHost {
	private static SignatureAlgorithm algorithm = SignatureAlgorithm.HS256;

	// value parameter - supposed to be a string representation of ISO date without milliseconds,
	// so we need to multiply the parsed value to 1000
	private Date getDateFromIsoString(String value) throws NumberFormatException {
		return new Date(Long.parseLong(value) * 1000);
	}

	private SecretKeySpec getSecretKey(String key) {
		return new SecretKeySpec(key.getBytes(), algorithm.getJcaName());
	}

	public String verifyJwt(String jwt, String key) {
		try {
			Jwts.parser().setSigningKey(getSecretKey(key)).parseClaimsJws(jwt);
			return "OK";
		} catch (MalformedJwtException e) {
			System.out.println(e.getMessage());
			return "Wrong token format";
		} catch (ExpiredJwtException e) {
			System.out.println(e.getMessage());
			return "Token has expired";
		} catch (PrematureJwtException e) {
			System.out.println(e.getMessage());
			return "Token was accepted before it is allowed";
		} catch (SecurityException e) {
			System.out.println(e.getMessage());
			return "Wrong signature";
		} catch (Exception e) {
			System.out.println(jwt + "/" + e.getMessage());
			return "Other exception";
		}
	}

	public Object decodeJwt(String jwt, String key, Func7<Object, String, String, String, String, String, String, String> callback, Func1<Object, String> onError) {
		String verify = verifyJwt(jwt, key);
		if (verify == "OK") {
			try {
				Claims jws = Jwts.parser().setSigningKey(getSecretKey(key)).parseClaimsJws(jwt).getBody();
				String iss = jws.getIssuer();
				String sub = jws.getSubject();
				String aud = jws.getAudience();
				Date exp = jws.getExpiration();
				Date nbf = jws.getNotBefore();
				Date iat = jws.getIssuedAt();
				String jti = jws.get("id").toString();

				callback.invoke(
					(iss == null ? "" : iss),
					(sub == null ? "" : sub),
					(aud == null ? "" : aud),
					(exp == null ? "" : DateFormats.formatIso8601(exp, false)),
					(nbf == null ? "" : DateFormats.formatIso8601(nbf, false)),
					(iat == null ? "" : DateFormats.formatIso8601(iat, false)),
					(jti == null ? "" : jti)
				);
			} catch (Exception e) {
				System.out.println(e.getMessage());
				onError.invoke("Hash problems");
			}
		} else {
			onError.invoke(verify);
		}
		return null;
	}

	public String createJwt(String key, String issuer, String subject, String audience, String expiration, String notBefore, String issuedAt, String id) {
		JwtBuilder builder = Jwts.builder();
		try {
			if (!issuer.isEmpty()) {
				builder = builder.setIssuer(issuer);
			}
			if (!subject.isEmpty()) {
				builder = builder.setSubject(subject);
			}
			if (!audience.isEmpty()) {
				builder = builder.setAudience(audience);
			}
			if (!issuedAt.isEmpty()) {
				builder = builder.setIssuedAt(getDateFromIsoString(issuedAt));
			} else {
				builder = builder.setIssuedAt(new Date());
			}
			if (!id.isEmpty()) {
				builder = builder.setId(id);
			}
			if (!expiration.isEmpty()) {
				builder = builder.setExpiration(getDateFromIsoString(expiration));
			}
			if (!notBefore.isEmpty()) {
				builder = builder.setNotBefore(getDateFromIsoString(notBefore));
			}

			Map<String, Object> header = new HashMap<String, Object>();
			header.put(JwsHeader.ALGORITHM, algorithm.getValue());
			header.put(Header.TYPE, "JWT");

			return builder.setHeader(header).signWith(algorithm, getSecretKey(key)).compact();

		} catch (NumberFormatException e) {
			System.out.println(e.getMessage());
			return "";
		}
	}

	public Object createJwtHs256(String jwtKey, Object[] keys, Object[] values, Func1<Object, String> onOk, Func1<Object, String> onError) {
		if (keys.length != 0 && keys.length == values.length) {
			JwtBuilder builder = Jwts.builder();

			// we cannot pass string[] arrays using flow native machinery, so we need to
			// make these transofmations to avoid unsafe conversions and calm the compiler!!
			String[] sKeys = java.util.Arrays.copyOf(keys, keys.length, String[].class);
			String[] sValues = java.util.Arrays.copyOf(values, values.length, String[].class);

			try {
				for (int i = 0; i < sKeys.length; i++) {
					String key = sKeys[i];
					String value = sValues[i];

					if (key.equals(ID)) {
						builder = builder.setIssuer(value);
					} else if (key.equals(ISSUER)) {
						builder = builder.setIssuer(value);
					} else if (key.equals(ISSUED_AT)) {
						builder = builder.setIssuedAt(getDateFromIsoString(value));
					} else if (key.equals(SUBJECT)) {
						builder = builder.setSubject(value);
					} else if (key.equals(AUDIENCE)) {
						builder = builder.setAudience(value);
					} else if (key.equals((EXPIRATION))) {
						builder = builder.setExpiration(getDateFromIsoString(value));
					} else if (key.equals((NOT_BEFORE))) {
						builder = builder.setNotBefore(getDateFromIsoString(value));
					} else {
						builder = builder.claim(key, value);
					}
				}

				Map<String, Object> header = new HashMap<String, Object>();
				header.put(JwsHeader.ALGORITHM, algorithm.getValue());
				header.put(Header.TYPE, "JWT");

				onOk.invoke(builder.setHeader(header).signWith(algorithm, getSecretKey(jwtKey)).compact());

			} catch (NumberFormatException e) {
				onError.invoke(e.getMessage());
			}
		} else {
			onError.invoke("No claims provided!");
		}
		return null;
	}
}