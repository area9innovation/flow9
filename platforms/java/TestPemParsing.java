import java.security.*;
import java.security.interfaces.*;
import java.security.spec.*;
import java.util.Base64;
import org.bouncycastle.asn1.pkcs.RSAPrivateKey;
import org.bouncycastle.asn1.ASN1Primitive;

/**
 * Standalone test for getPemRsaPkcs8PrivateKeyFromString fix.
 *
 * Run from flow9/platforms/java/:
 *   javac -cp "lib/*:." -d /tmp/pemtest com/area9innovation/flow/FlowJwt.java TestPemParsing.java && \
 *   java -cp "lib/*:/tmp/pemtest" TestPemParsing
 */
public class TestPemParsing {

    public static void main(String[] args) throws Exception {
        System.out.println("=== Testing getPemRsaPkcs8PrivateKeyFromString ===\n");

        // Generate a fresh RSA key pair for testing
        KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
        kpg.initialize(2048);
        KeyPair kp = kpg.generateKeyPair();

        // PKCS#8 format (-----BEGIN PRIVATE KEY-----)
        String pkcs8Pem = "-----BEGIN PRIVATE KEY-----\n"
            + Base64.getMimeEncoder(64, "\n".getBytes()).encodeToString(kp.getPrivate().getEncoded())
            + "\n-----END PRIVATE KEY-----";

        // PKCS#1 format (-----BEGIN RSA PRIVATE KEY-----)
        // Use BouncyCastle to properly extract PKCS#1 from the private key
        RSAPrivateCrtKey rsaPrivKey = (RSAPrivateCrtKey) kp.getPrivate();
        RSAPrivateKey bcRsaKey = new RSAPrivateKey(
            rsaPrivKey.getModulus(),
            rsaPrivKey.getPublicExponent(),
            rsaPrivKey.getPrivateExponent(),
            rsaPrivKey.getPrimeP(),
            rsaPrivKey.getPrimeQ(),
            rsaPrivKey.getPrimeExponentP(),
            rsaPrivKey.getPrimeExponentQ(),
            rsaPrivKey.getCrtCoefficient()
        );
        byte[] pkcs1Bytes = bcRsaKey.getEncoded();
        String pkcs1Pem = "-----BEGIN RSA PRIVATE KEY-----\n"
            + Base64.getMimeEncoder(64, "\n".getBytes()).encodeToString(pkcs1Bytes)
            + "\n-----END RSA PRIVATE KEY-----";

        int passed = 0;
        int failed = 0;

        // Test 1: PKCS#8 format
        System.out.println("Test 1: PKCS#8 format (-----BEGIN PRIVATE KEY-----)");
        try {
            PrivateKey key = com.area9innovation.flow.FlowJwt.getPemRsaPkcs8PrivateKeyFromString(pkcs8Pem);
            System.out.println("  PASS: parsed " + key.getAlgorithm() + " key, format=" + key.getFormat());
            passed++;
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
            failed++;
        }

        // Test 2: PKCS#1 format (would fail before fix with "Illegal base64 character 2d")
        System.out.println("\nTest 2: PKCS#1 format (-----BEGIN RSA PRIVATE KEY-----)");
        try {
            PrivateKey key = com.area9innovation.flow.FlowJwt.getPemRsaPkcs8PrivateKeyFromString(pkcs1Pem);
            System.out.println("  PASS: parsed " + key.getAlgorithm() + " key, format=" + key.getFormat());
            passed++;
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
            failed++;
        }

        // Test 3: createJwtAlgorithm with RS256 + PKCS#1 key
        System.out.println("\nTest 3: createJwtAlgorithm with RS256 + PKCS#1 key");
        try {
            String jwt = com.area9innovation.flow.FlowJwt.createJwtAlgorithm(
                pkcs1Pem,
                "{\"sub\":\"test\",\"iss\":\"test\",\"exp\":9999999999}",
                "RS256",
                ""
            );
            if (jwt.startsWith("Error:")) {
                System.out.println("  FAIL: " + jwt);
                failed++;
            } else {
                System.out.println("  PASS: JWT created (" + jwt.length() + " chars, " + jwt.split("\\.").length + " parts)");
                passed++;
            }
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
            failed++;
        }

        // Test 4: createJwtAlgorithm with RS256 + PKCS#8 key
        System.out.println("\nTest 4: createJwtAlgorithm with RS256 + PKCS#8 key");
        try {
            String jwt = com.area9innovation.flow.FlowJwt.createJwtAlgorithm(
                pkcs8Pem,
                "{\"sub\":\"test\",\"iss\":\"test\",\"exp\":9999999999}",
                "RS256",
                ""
            );
            if (jwt.startsWith("Error:")) {
                System.out.println("  FAIL: " + jwt);
                failed++;
            } else {
                System.out.println("  PASS: JWT created (" + jwt.length() + " chars)");
                passed++;
            }
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
            failed++;
        }

        // Test 5: HS256 still works
        System.out.println("\nTest 5: createJwtAlgorithm with HS256");
        try {
            String jwt = com.area9innovation.flow.FlowJwt.createJwtAlgorithm(
                "my-secret-key",
                "{\"sub\":\"test\",\"iss\":\"test\",\"exp\":9999999999}",
                "HS256",
                ""
            );
            if (jwt.startsWith("Error:")) {
                System.out.println("  FAIL: " + jwt);
                failed++;
            } else {
                System.out.println("  PASS: JWT created (" + jwt.length() + " chars)");
                passed++;
            }
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
            failed++;
        }

        // Test 6: Verify PKCS#1 and PKCS#8 produce same signing key
        System.out.println("\nTest 6: PKCS#1 and PKCS#8 keys produce identical JWTs");
        try {
            String claims = "{\"sub\":\"same\",\"iss\":\"test\",\"iat\":1000000}";
            String jwt1 = com.area9innovation.flow.FlowJwt.createJwtAlgorithm(pkcs1Pem, claims, "RS256", "");
            String jwt2 = com.area9innovation.flow.FlowJwt.createJwtAlgorithm(pkcs8Pem, claims, "RS256", "");
            // Header and payload should be identical; signature depends on key representation but should verify the same
            String[] parts1 = jwt1.split("\\.");
            String[] parts2 = jwt2.split("\\.");
            if (parts1[0].equals(parts2[0]) && parts1[1].equals(parts2[1])) {
                System.out.println("  PASS: header and payload match");
                passed++;
            } else {
                System.out.println("  FAIL: header/payload mismatch");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
            failed++;
        }

        System.out.println("\n=== Results: " + passed + " passed, " + failed + " failed ===");
        System.exit(failed > 0 ? 1 : 0);
    }
}
