<?php

// Offline transport doubles: namespaced functions leave the real cURL untouched.
namespace FlowFirebaseMessaging {
    function curl_init($url) {
        $GLOBALS['fakeCurl']['url'] = $url;
        $GLOBALS['fakeCurl']['calls']++;
        return $GLOBALS['fakeCurl']['init'] ? new \stdClass() : false;
    }

    function curl_setopt_array($handle, $options) {
        $GLOBALS['fakeCurl']['options'] = $options;
        return $GLOBALS['fakeCurl']['setOptions'];
    }

    function curl_exec($handle) {
        if (!$GLOBALS['fakeCurl']['exec']) {
            return false;
        }
        $write = $GLOBALS['fakeCurl']['options'][CURLOPT_WRITEFUNCTION];
        foreach ($GLOBALS['fakeCurl']['chunks'] as $chunk) {
            if ($write($handle, $chunk) !== strlen($chunk)) {
                return false;
            }
        }
        return true;
    }

    function curl_getinfo($handle, $option) {
        return $GLOBALS['fakeCurl']['status'];
    }

    function curl_close($handle) {
        $GLOBALS['fakeCurl']['closed'] = true;
    }
}

namespace {
    require_once __DIR__ . '/../www/php/firebase/messaging_handler.php';

    use function FlowFirebaseMessaging\handleRequest;
    use function FlowFirebaseMessaging\loadConfiguration;
    use function FlowFirebaseMessaging\pathIsWithin;
    use function FlowFirebaseMessaging\sendRequest;

    if (!extension_loaded('curl')) {
        fwrite(STDERR, "These offline tests require the cURL extension for its constants.\n");
        exit(1);
    }

    $checks = 0;
    $failures = 0;
    function check(string $name, bool $ok): void {
        global $checks, $failures;
        $checks++;
        if (!$ok) {
            $failures++;
            fwrite(STDERR, "FAIL: $name\n");
        }
    }

    function runCase(string $name, array $post, int $status, $authorize = false,
        string $method = 'POST', $transportResult = true): array {
        $events = [];
        $result = handleRequest($method, $post,
            static function () use (&$events, $authorize) {
                $events[] = 'configuration';
                return [
                    'server_key' => 'synthetic-test-key',
                    'authorize' => static function ($request) use (&$events, $authorize) {
                        $events[] = ['authorize', $request];
                        return is_callable($authorize) ? $authorize($request) : $authorize;
                    }
                ];
            },
            static function ($key, $request) use (&$events, $transportResult) {
                $events[] = ['transport', $key, $request];
                if ($transportResult instanceof \Throwable) {
                    throw $transportResult;
                }
                return $transportResult;
            }
        );
        check($name . ': status', $result['status'] === $status);
        if ($status === 400 || $status === 405) {
            check($name . ': no configuration, authorization, or transport', $events === []);
        } elseif ($status === 403 || $status === 503) {
            check($name . ': transport not called', count($events) === 2);
        } else {
            check($name . ': authorize before transport', count($events) === 3 &&
                $events[1][0] === 'authorize' && $events[2][0] === 'transport');
            check($name . ': exact authorized tuple transported', $events[1][1] === $events[2][2]);
        }
        return $result;
    }

    $valid = ['doSubscribe' => 'true', 'topic' => '/topics/example', 'token' => 'device:Ab_12-z'];
    $tuple = ['topic' => '/topics/example', 'token' => 'device:Ab_12-z', 'operation' => 'subscribe'];
    $policy = static function ($request) use ($tuple) { return $request === $tuple; };

    foreach (['GET', 'HEAD', 'OPTIONS', 'DELETE', ''] as $method) {
        runCase('wrong method ' . $method, $valid, 405, true, $method);
    }
    foreach (array_keys($valid) as $field) {
        $post = $valid;
        unset($post[$field]);
        runCase('missing ' . $field, $post, 400, true);
        foreach ([[], ['nested' => 'value'], null, true, 1, new \stdClass()] as $value) {
            $post = $valid;
            $post[$field] = $value;
            runCase('non-string ' . $field, $post, 400, true);
        }
    }
    foreach (['', 'TRUE', '1', '0', 'subscribe', "false\n"] as $operation) {
        runCase('invalid operation', array_replace($valid, ['doSubscribe' => $operation]), 400, true);
    }
    foreach (['', '/topics/', 'example/other', '/topics//topics/example', 'with space',
        "example\n", "example\0", 'é', str_repeat('a', 901)] as $topic) {
        runCase('invalid topic', array_replace($valid, ['topic' => $topic]), 400, true);
    }
    foreach (['', 'with space', 'device/token', 'device=token', "device\r\n", "device\0",
        'é', str_repeat('a', 4097)] as $token) {
        runCase('invalid token', array_replace($valid, ['token' => $token]), 400, true);
    }

    $result = runCase('authorized subscribe', $valid, 200, $policy);
    check('success body', $result['body'] === ['ok' => true]);
    runCase('bare topic normalized before policy', array_replace($valid, ['topic' => 'example']), 200, $policy);
    runCase('allowed character sets and size boundaries', [
        'doSubscribe' => 'true',
        'topic' => '/topics/' . str_repeat('a', 894) . '-_.~%9',
        'token' => str_repeat('a', 4091) . '_:-Z9'
    ], 200, true);
    $unsubscribe = array_replace($valid, ['doSubscribe' => 'false']);
    runCase('authorized unsubscribe', $unsubscribe, 200, static function ($request) use ($tuple) {
        return $request === array_replace($tuple, ['operation' => 'unsubscribe']);
    });
    foreach ([false, null, 1, 'true', []] as $decision) {
        $result = runCase('only literal true grants permission', $valid, 403, $decision);
        check('denial body', $result['body'] === ['error' => 'forbidden']);
    }
    runCase('different topic denied', array_replace($valid, ['topic' => 'other']), 403, $policy);
    runCase('different device denied', array_replace($valid, ['token' => 'other-device']), 403, $policy);
    runCase('different action denied', $unsubscribe, 403, $policy);
    $transported = null;
    $result = handleRequest('POST', $valid, static function () {
        return ['server_key' => 'synthetic-test-key', 'authorize' => static function (&$request) {
            $request['topic'] = '/topics/changed';
            $request['token'] = 'changed-device';
            $request['operation'] = 'unsubscribe';
            return true;
        }];
    }, static function ($key, $request) use (&$transported) { $transported = $request; return true; });
    check('authorization cannot mutate validated transport tuple', $result['status'] === 200 && $transported === $tuple);
    $result = runCase('authorization exception', $valid, 503, static function () {
        throw new \RuntimeException('synthetic private diagnostic');
    });
    check('authorization exception redacted', $result['body'] === ['error' => 'service_unavailable']);

    $badConfigurations = [null, false, [], ['server_key' => 'synthetic-test-key'],
        ['server_key' => 'synthetic-test-key', 'authorize' => 'not_a_callable']];
    foreach (['', [], "invalid\r\nkey", 'key with spaces', str_repeat('a', 4097)] as $key) {
        $badConfigurations[] = ['server_key' => $key, 'authorize' => static function () {
            throw new \RuntimeException('Must not authorize invalid configuration');
        }];
    }
    foreach ($badConfigurations as $config) {
        $transportCalled = false;
        $result = handleRequest('POST', $valid, static function () use ($config) { return $config; },
            static function () use (&$transportCalled) { $transportCalled = true; return true; });
        check('invalid/missing configuration returns 503', $result === [
            'status' => 503, 'body' => ['error' => 'service_unavailable']
        ]);
        check('invalid/missing configuration never calls transport', !$transportCalled);
    }
    $result = handleRequest('POST', $valid, static function () {
        throw new \RuntimeException('synthetic private configuration diagnostic');
    }, static function () { throw new \RuntimeException('Transport must not be called'); });
    check('configuration exception redacted', $result === [
        'status' => 503, 'body' => ['error' => 'service_unavailable']
    ]);
    ob_start();
    $result = handleRequest('POST', $valid, static function () {
        echo 'synthetic configuration output';
        return ['server_key' => 'synthetic-test-key', 'authorize' => static function () {
            echo 'synthetic authorization output';
            return true;
        }];
    }, static function () {
        echo 'synthetic transport output';
        throw new \RuntimeException('synthetic transport exception');
    });
    $unexpectedOutput = ob_get_clean();
    check('callbacks cannot expose output', $unexpectedOutput === '' && $result === [
        'status' => 502, 'body' => ['error' => 'upstream_error']
    ]);
    foreach ([false, null, 1, new \RuntimeException('synthetic private transport diagnostic')] as $outcome) {
        $result = runCase('transport failure', $valid, 502, true, 'POST', $outcome);
        check('transport failure redacted', $result['body'] === ['error' => 'upstream_error']);
    }

    // Exercise the real configuration loader using disposable files only.
    $originalConfig = getenv('FLOW_FIREBASE_MESSAGING_CONFIG');
    $originalRoot = $_SERVER['DOCUMENT_ROOT'] ?? null;
    $configFile = tempnam(sys_get_temp_dir(), 'sec-firebase-');
    $link = $configFile . '-link';
    try {
        unset($_SERVER['DOCUMENT_ROOT']);
        putenv('FLOW_FIREBASE_MESSAGING_CONFIG');
        check('no configuration setting', loadConfiguration() === null);
        putenv('FLOW_FIREBASE_MESSAGING_CONFIG=relative-config.php');
        check('relative configuration rejected', loadConfiguration() === null);
        putenv('FLOW_FIREBASE_MESSAGING_CONFIG=' . $configFile . '-missing');
        check('missing configuration rejected', loadConfiguration() === null);
        putenv('FLOW_FIREBASE_MESSAGING_CONFIG=' . $configFile);
        file_put_contents($configFile, '<?php return ["server_key" => "synthetic-test-key", "authorize" => static function ($r) { return false; }];');
        $loaded = loadConfiguration();
        check('server-only configuration loaded', is_array($loaded) && is_callable($loaded['authorize']));
        $_SERVER['DOCUMENT_ROOT'] = dirname($configFile);
        check('configuration in document root rejected', loadConfiguration() === null);
        unset($_SERVER['DOCUMENT_ROOT']);
        putenv('FLOW_FIREBASE_MESSAGING_CONFIG=' . realpath(__DIR__ . '/../www/php/firebase/messaging_handler.php'));
        check('configuration in public tree rejected', loadConfiguration() === null);
        if (symlink(realpath(__DIR__ . '/../www/php/firebase/messaging_handler.php'), $link)) {
            putenv('FLOW_FIREBASE_MESSAGING_CONFIG=' . $link);
            check('symlink into public tree rejected', loadConfiguration() === null);
        } else {
            check('create symlink for configuration check', false);
        }
        putenv('FLOW_FIREBASE_MESSAGING_CONFIG=' . $configFile);
        foreach (['<?php return false;', '<?php throw new RuntimeException("synthetic diagnostic");',
            '<?php this is not valid PHP;'] as $contents) {
            file_put_contents($configFile, $contents);
            check('invalid configuration fails closed', loadConfiguration() === null);
        }
        file_put_contents($configFile, 'synthetic non-PHP configuration content');
        ob_start();
        $loaded = loadConfiguration();
        $unexpectedOutput = ob_get_clean();
        check('non-PHP configuration content not exposed', $loaded === null && $unexpectedOutput === '');
    } finally {
        if (is_link($link)) unlink($link);
        unlink($configFile);
        putenv($originalConfig === false ? 'FLOW_FIREBASE_MESSAGING_CONFIG' :
            'FLOW_FIREBASE_MESSAGING_CONFIG=' . $originalConfig);
        if ($originalRoot === null) unset($_SERVER['DOCUMENT_ROOT']);
        else $_SERVER['DOCUMENT_ROOT'] = $originalRoot;
    }
    check('path containment respects directory boundary', !pathIsWithin('/publicity/config.php', '/public'));
    check('path containment handles filesystem root', pathIsWithin('/config.php', '/'));

    function resetCurl(): void {
        $GLOBALS['fakeCurl'] = [
            'calls' => 0, 'init' => true, 'setOptions' => true, 'exec' => true,
            'status' => 200, 'chunks' => ['{"results":[', '{}]}'], 'closed' => false
        ];
    }
    foreach (['subscribe' => 'Add', 'unsubscribe' => 'Remove'] as $operation => $suffix) {
        resetCurl();
        $request = array_replace($tuple, ['operation' => $operation]);
        check('transport accepts successful ' . $operation, sendRequest('synthetic-test-key', $request));
        $fake = $GLOBALS['fakeCurl'];
        $options = $fake['options'];
        check('fixed upstream URL', $fake['url'] === 'https://iid.googleapis.com/iid/v1:batch' . $suffix);
        check('transport JSON payload', json_decode($options[CURLOPT_POSTFIELDS], true) === [
            'to' => $tuple['topic'], 'registration_tokens' => [$tuple['token']]
        ]);
        check('transport headers', $options[CURLOPT_HTTPHEADER] === [
            'Authorization:key=synthetic-test-key', 'Content-Type:application/json'
        ]);
        check('transport timeouts', $options[CURLOPT_CONNECTTIMEOUT] === 5 && $options[CURLOPT_TIMEOUT] === 15);
        check('transport TLS and no redirects', $options[CURLOPT_POST] === true &&
            $options[CURLOPT_FOLLOWLOCATION] === false && $options[CURLOPT_PROTOCOLS] === CURLPROTO_HTTPS &&
            $options[CURLOPT_SSL_VERIFYPEER] === true && $options[CURLOPT_SSL_VERIFYHOST] === 2);
        check('transport closes handle', $fake['closed']);
    }
    foreach ([301, 400, 401, 403, 429, 500] as $status) {
        resetCurl();
        $GLOBALS['fakeCurl']['status'] = $status;
        check('non-200 upstream rejected', !sendRequest('synthetic-test-key', $tuple));
        check('non-200 handle closed', $GLOBALS['fakeCurl']['closed']);
    }
    foreach (['', 'not JSON', '{}', '{"results":[]}', '{"results":[[]]}', '{"results":[{},{}]}',
        '{"results":[{"error":"NOT_FOUND"}]}', '{"error":"synthetic upstream detail"}',
        '{"results":[{}],"error":"synthetic upstream detail"}'] as $body) {
        resetCurl();
        $GLOBALS['fakeCurl']['chunks'] = [$body];
        check('unsuccessful upstream body rejected', !sendRequest('synthetic-test-key', $tuple));
    }
    foreach (['init', 'setOptions', 'exec'] as $failure) {
        resetCurl();
        $GLOBALS['fakeCurl'][$failure] = false;
        check('cURL failure rejected: ' . $failure, !sendRequest('synthetic-test-key', $tuple));
        if ($failure !== 'init') check('failed transport closed', $GLOBALS['fakeCurl']['closed']);
    }
    resetCurl();
    $GLOBALS['fakeCurl']['chunks'] = [str_repeat('a', 65536), 'a'];
    check('oversized upstream response rejected', !sendRequest('synthetic-test-key', $tuple));

    // Check the deployed entry point too, without invoking an external service.
    $savedServer = $_SERVER;
    $savedPost = $_POST;
    $savedConfig = getenv('FLOW_FIREBASE_MESSAGING_CONFIG');
    $entryConfig = tempnam(sys_get_temp_dir(), 'sec-firebase-');
    $bodies = [];
    resetCurl();
    try {
        putenv('FLOW_FIREBASE_MESSAGING_CONFIG');
        foreach ([['GET', $valid, 405, 'method_not_allowed'],
            ['POST', array_replace($valid, ['topic' => []]), 400, 'invalid_request'],
            ['POST', $valid, 503, 'service_unavailable']] as $case) {
            $_SERVER['REQUEST_METHOD'] = $case[0];
            $_POST = $case[1];
            ob_start();
            include __DIR__ . '/../www/php/firebase/messaging.php';
            $bodies[] = ob_get_clean();
            check('entry point HTTP status', http_response_code() === $case[2]);
            check('entry point JSON body', json_decode(end($bodies), true) === ['error' => $case[3]]);
        }
        check('entry point never calls transport before authorization', $GLOBALS['fakeCurl']['calls'] === 0);
        unset($_SERVER['DOCUMENT_ROOT']);
        putenv('FLOW_FIREBASE_MESSAGING_CONFIG=' . $entryConfig);
        foreach ([false, true] as $allowed) {
            file_put_contents($entryConfig, '<?php return ["server_key" => "synthetic-test-key", ' .
                '"authorize" => static function ($request) { return ' . ($allowed ? 'true' : 'false') . '; }];');
            resetCurl();
            $_SERVER['REQUEST_METHOD'] = 'POST';
            $_POST = $valid;
            ob_start();
            include __DIR__ . '/../www/php/firebase/messaging.php';
            $body = ob_get_clean();
            check('configured entry point status', http_response_code() === ($allowed ? 200 : 403));
            check('configured entry point body', json_decode($body, true) ===
                ($allowed ? ['ok' => true] : ['error' => 'forbidden']));
            check('configured entry point transport calls', $GLOBALS['fakeCurl']['calls'] === ($allowed ? 1 : 0));
        }
    } finally {
        unlink($entryConfig);
        $_SERVER = $savedServer;
        $_POST = $savedPost;
        putenv($savedConfig === false ? 'FLOW_FIREBASE_MESSAGING_CONFIG' :
            'FLOW_FIREBASE_MESSAGING_CONFIG=' . $savedConfig);
    }

    echo ($checks - $failures) . "/$checks checks passed\n";
    exit($failures === 0 ? 0 : 1);
}
