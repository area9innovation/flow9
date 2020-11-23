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
			Jwts.parserBuilder().setSigningKey(getSecretKey(key)).build().parseClaimsJws(jwt);
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
			String iss;
			String sub;
			String aud;
			Date exp;
			Date nbf;
			Date iat;
			String jti;
			try {
				Claims jws = Jwts.parserBuilder().setSigningKey(getSecretKey(key)).build().parseClaimsJws(jwt).getBody();
				iss = jws.getIssuer();
				sub = jws.getSubject();
				aud = jws.getAudience();
				exp = jws.getExpiration();
				nbf = jws.getNotBefore();
				iat = jws.getIssuedAt();
				jti = jws.get("id").toString();
			} catch (Exception e) {
				System.out.println(e.getMessage());
				onError.invoke("Hash problems");
				return null;
			}
			callback.invoke(
				(iss == null ? "" : iss),
				(sub == null ? "" : sub),
				(aud == null ? "" : aud),
				(exp == null ? "" : DateFormats.formatIso8601(exp, false)),
				(nbf == null ? "" : DateFormats.formatIso8601(nbf, false)),
				(iat == null ? "" : DateFormats.formatIso8601(iat, false)),
				(jti == null ? "" : jti)
			);
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

			return builder.setHeader(header).signWith(getSecretKey(key), algorithm).compact();

		} catch (NumberFormatException e) {
			System.out.println(e.getMessage());
			return "";
		}
	}


	public String createJwtClaims(String jwtKey, Object[] keys, Object[] values) {
		JwtBuilder builder = Jwts.builder();

		for (int i = 0; i < keys.length; i++) {
			builder.claim((String)keys[i], values[i]);
		}

		Map<String, Object> header = new HashMap<String, Object>();
		header.put(JwsHeader.ALGORITHM, algorithm.getValue());
		header.put(Header.TYPE, "JWT");

		return builder.setHeader(header).signWith(getSecretKey(jwtKey), algorithm).compact();
	}
}
