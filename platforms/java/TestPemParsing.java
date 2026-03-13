import java.security.*;
import java.security.interfaces.*;
import java.security.spec.*;
import java.util.Base64;

/**
 * Standalone test for getPemRsaPkcs8PrivateKeyFromString fix.
 *
 * Run from flow9/platforms/java/:
 *   javac -cp "lib/*:com" -d /tmp/pemtest com/area9innovation/flow/FlowJwt.java TestPemParsing.java && \
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
        // Extract PKCS#1 bytes from PKCS#8 by stripping the AlgorithmIdentifier wrapper
        byte[] pkcs1Bytes = extractPkcs1FromPkcs8(kp.getPrivate().getEncoded());
        String pkcs1Pem = "-----BEGIN RSA PRIVATE KEY-----\n"
            + Base64.getMimeEncoder(64, "\n".getBytes()).encodeToString(pkcs1Bytes)
            + "\n-----END RSA PRIVATE KEY-----";

        // Test 1: PKCS#8 format (should work before and after fix)
        System.out.println("Test 1: PKCS#8 format (-----BEGIN PRIVATE KEY-----)");
        try {
            PrivateKey key = com.area9innovation.flow.FlowJwt.getPemRsaPkcs8PrivateKeyFromString(pkcs8Pem);
            System.out.println("  PASS: parsed " + key.getAlgorithm() + " key, format=" + key.getFormat());
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
        }

        // Test 2: PKCS#1 format (would fail before fix with "Illegal base64 character 2d")
        System.out.println("\nTest 2: PKCS#1 format (-----BEGIN RSA PRIVATE KEY-----)");
        try {
            PrivateKey key = com.area9innovation.flow.FlowJwt.getPemRsaPkcs8PrivateKeyFromString(pkcs1Pem);
            System.out.println("  PASS: parsed " + key.getAlgorithm() + " key, format=" + key.getFormat());
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
        }

        // Test 3: Full round-trip with createJwtAlgorithm using RS256 + PKCS#1 key
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
            } else {
                System.out.println("  PASS: JWT created (" + jwt.length() + " chars)");
                System.out.println("  JWT parts: " + jwt.split("\\.").length + " (expected 3)");
            }
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
        }

        // Test 4: Full round-trip with createJwtAlgorithm using RS256 + PKCS#8 key
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
            } else {
                System.out.println("  PASS: JWT created (" + jwt.length() + " chars)");
            }
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
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
            } else {
                System.out.println("  PASS: JWT created (" + jwt.length() + " chars)");
            }
        } catch (Exception e) {
            System.out.println("  FAIL: " + e.getMessage());
        }

        System.out.println("\n=== Done ===");
    }

    /**
     * Extract PKCS#1 RSA private key bytes from a PKCS#8 encoded key.
     * PKCS#8 wraps PKCS#1 inside: SEQUENCE { version, AlgorithmIdentifier, OCTET STRING { pkcs1 } }
     */
    private static byte[] extractPkcs1FromPkcs8(byte[] pkcs8Bytes) throws Exception {
        // Parse the PKCS#8 DER to find the OCTET STRING containing the PKCS#1 key
        // Structure: SEQUENCE { INTEGER version, SEQUENCE algId, OCTET STRING privateKey }
        int offset = 0;
        // Skip outer SEQUENCE tag + length
        offset++; // tag 0x30
        offset += derLengthSize(pkcs8Bytes, offset);
        // Skip version INTEGER
        offset++; // tag 0x02
        int vLen = derReadLength(pkcs8Bytes, offset);
        offset += derLengthSize(pkcs8Bytes, offset) + vLen;
        // Skip AlgorithmIdentifier SEQUENCE
        offset++; // tag 0x30
        int aLen = derReadLength(pkcs8Bytes, offset);
        offset += derLengthSize(pkcs8Bytes, offset) + aLen;
        // Now at OCTET STRING
        offset++; // tag 0x04
        int pLen = derReadLength(pkcs8Bytes, offset);
        offset += derLengthSize(pkcs8Bytes, offset);
        byte[] pkcs1 = new byte[pLen];
        System.arraycopy(pkcs8Bytes, offset, pkcs1, 0, pLen);
        return pkcs1;
    }

    private static int derReadLength(byte[] data, int offset) {
        int first = data[offset] & 0xFF;
        if (first < 128) return first;
        int numBytes = first & 0x7F;
        int length = 0;
        for (int i = 0; i < numBytes; i++) {
            length = (length << 8) | (data[offset + 1 + i] & 0xFF);
        }
        return length;
    }

    private static int derLengthSize(byte[] data, int offset) {
        int first = data[offset] & 0xFF;
        if (first < 128) return 1;
        return 1 + (first & 0x7F);
    }
}
