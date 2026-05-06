<?php
/**
 * AES-256-GCM PHP ↔ Java/JAR cross-platform test.
 *
 * Tests that tokens produced by PHP can be decrypted by the Java JAR and
 * vice-versa.  Must be run from the flow9 root directory AFTER building
 * the JAR:
 *
 *   flowc1 tests/test_crypto_aes.flow jar=test_crypto_aes.jar
 *   php tests/test_crypto_aes_php_cross.php
 *
 * Requires:
 *   - PHP with openssl extension
 *   - Java on PATH
 *   - test_crypto_aes.jar in the current directory (flow9 root)
 */

// ── helpers identical to report_unsubscribe.php ──────────────────────────────

function encryptAES256GCM(string $data, string $key) : string {
    $derivedKey = hash('sha256', $key, true);
    $iv         = random_bytes(12);
    $tag        = '';
    $ciphertext = openssl_encrypt($data, 'aes-256-gcm', $derivedKey, OPENSSL_RAW_DATA, $iv, $tag, '', 16);

    if ($ciphertext === false) return '';

    return bin2hex($iv) . '-' . bin2hex($ciphertext) . '-' . bin2hex($tag);
}

function decryptAES256GCM(string $encryptedData, string $key) : ?string {
    $parts = explode('-', $encryptedData, 3);
    if (count($parts) !== 3) return null;

    $iv         = hex2bin($parts[0]);
    $ciphertext = hex2bin($parts[1]);
    $tag        = hex2bin($parts[2]);

    if ($iv === false || $ciphertext === false || $tag === false) return null;
    if (strlen($iv) !== 12 || strlen($tag) !== 16)               return null;

    $derivedKey = hash('sha256', $key, true);
    $plaintext  = openssl_decrypt($ciphertext, 'aes-256-gcm', $derivedKey, OPENSSL_RAW_DATA, $iv, $tag);

    return $plaintext !== false ? $plaintext : null;
}

// ── test runner ───────────────────────────────────────────────────────────────

$passed = 0;
$failed = 0;

function check(string $name, bool $ok) : void {
    global $passed, $failed;
    if ($ok) {
        echo "  PASS  $name\n";
        $passed++;
    } else {
        echo "  FAIL  $name\n";
        $failed++;
    }
}

/**
 * Invoke the JAR to encrypt/decrypt via sub-command mode.
 * Flow's Java runtime parses CLI args as key=value pairs:
 *
 *   java -jar test_crypto_aes.jar cmd=encrypt data="<plaintext>" key="<key>"
 *   java -jar test_crypto_aes.jar cmd=decrypt data="<token>"     key="<key>"
 *
 * Prints exactly one line: the result.
 *
 * Note: data and key must not contain '=' (they won't — plaintext uses ':'/'-',
 * tokens are pure hex + '-', and keys are hex strings).
 */
function jarEncrypt(string $plaintext, string $key) : string {
    $out = shell_exec(
        "java -jar test_crypto_aes.jar"
        . " cmd=encrypt"
        . " data=" . escapeshellarg($plaintext)
        . " key="  . escapeshellarg($key)
        . " 2>/dev/null"
    );
    return trim($out ?? '');
}

function jarDecrypt(string $token, string $key) : string {
    $out = shell_exec(
        "java -jar test_crypto_aes.jar"
        . " cmd=decrypt"
        . " data=" . escapeshellarg($token)
        . " key="  . escapeshellarg($key)
        . " 2>/dev/null"
    );
    return trim($out ?? '');
}

// ─────────────────────────────────────────────────────────────────────────────

$key   = '03b4054771562ad7f25676f6895f1209a11c778552e2606bd512c381478c058a';
$plain = '42:7:550e8400-e29b-41d4-a716-446655440000';

echo "\n=== PHP self-test ===\n";
$phpToken   = encryptAES256GCM($plain, $key);
$phpDecoded = decryptAES256GCM($phpToken, $key);
check('PHP encrypt→decrypt round-trip', $phpDecoded === $plain);
check('PHP wrong key rejected',         decryptAES256GCM($phpToken, 'wrong') === null);

echo "\n=== PHP → JAR cross-test ===\n";
echo "  PHP token : $phpToken\n";
$jarResult = jarDecrypt($phpToken, $key);
echo "  JAR result: $jarResult\n";
check('JAR decrypts PHP token correctly', $jarResult === $plain);

echo "\n=== JAR → PHP cross-test ===\n";
$jarToken  = jarEncrypt($plain, $key);
echo "  JAR token : $jarToken\n";
$phpResult = decryptAES256GCM($jarToken, $key);
echo "  PHP result: $phpResult\n";
check('PHP decrypts JAR token correctly', $phpResult === $plain);

echo "\n=== Cross-test: unicode payload ===\n";
$uPlain    = 'héllo – 你好';
$uToken    = encryptAES256GCM($uPlain, $key);
$uJarOut   = jarDecrypt($uToken, $key);
check('JAR decrypts PHP unicode token', $uJarOut === $uPlain);

$uJarToken = jarEncrypt($uPlain, $key);
$uPhpOut   = decryptAES256GCM($uJarToken, $key);
check('PHP decrypts JAR unicode token', $uPhpOut === $uPlain);

// ─────────────────────────────────────────────────────────────────────────────
$total = $passed + $failed;
echo "\n─────────────────────────────────────────────────────────────────────────────\n";
echo "Result: $passed/$total passed" . ($failed > 0 ? " — $failed FAILED" : "") . "\n";
echo "─────────────────────────────────────────────────────────────────────────────\n\n";

exit($failed > 0 ? 1 : 0);
