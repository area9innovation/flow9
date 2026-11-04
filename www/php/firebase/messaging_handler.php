<?php

namespace FlowFirebaseMessaging;

function response(int $status, string $error = ''): array {
    return [
        'status' => $status,
        'body' => $error === '' ? ['ok' => true] : ['error' => $error]
    ];
}

function withoutOutput(callable $callback) {
    $bufferLevel = ob_get_level();
    ob_start();
    try {
        return $callback();
    } finally {
        while (ob_get_level() > $bufferLevel) {
            ob_end_clean();
        }
    }
}

function validateRequest(array $post): ?array {
    foreach (['doSubscribe', 'topic', 'token'] as $field) {
        if (!isset($post[$field]) || !is_string($post[$field])) {
            return null;
        }
    }
    if ($post['doSubscribe'] !== 'true' && $post['doSubscribe'] !== 'false') {
        return null;
    }

    $topic = $post['topic'];
    if (strncmp($topic, '/topics/', 8) === 0) {
        $topic = substr($topic, 8);
    }
    if (!preg_match('/\A[a-zA-Z0-9_.~%\-]{1,900}\z/', $topic) ||
        !preg_match('/\A[a-zA-Z0-9_:\-]{1,4096}\z/', $post['token'])) {
        return null;
    }

    // Authorization and transport receive exactly the same canonical values.
    return [
        'topic' => '/topics/' . $topic,
        'token' => $post['token'],
        'operation' => $post['doSubscribe'] === 'true' ? 'subscribe' : 'unsubscribe'
    ];
}

function pathIsWithin(string $path, string $directory): bool {
    $path = str_replace('\\', '/', $path);
    $directory = rtrim(str_replace('\\', '/', $directory), '/');
    if (DIRECTORY_SEPARATOR === '\\') {
        $path = strtolower($path);
        $directory = strtolower($directory);
    }
    return $path === $directory || strpos($path, $directory . '/') === 0;
}

function loadConfiguration(): ?array {
    // This setting belongs to the PHP server environment, never to a request.
    $configuredPath = getenv('FLOW_FIREBASE_MESSAGING_CONFIG', true);
    if (!is_string($configuredPath) ||
        !preg_match('~\A(?:/|[a-zA-Z]:[\\\\/])~', $configuredPath)) {
        return null;
    }
    $path = realpath($configuredPath);
    if ($path === false || !is_file($path) || !is_readable($path)) {
        return null;
    }

    // Resolve symlinks before checking both the copied public tree and webroot.
    $publicRoots = [dirname(__DIR__, 2)];
    if (isset($_SERVER['DOCUMENT_ROOT']) && $_SERVER['DOCUMENT_ROOT'] !== '') {
        if (!is_string($_SERVER['DOCUMENT_ROOT'])) {
            return null;
        }
        $documentRoot = realpath($_SERVER['DOCUMENT_ROOT']);
        if ($documentRoot === false) {
            return null;
        }
        $publicRoots[] = $documentRoot;
    }
    foreach ($publicRoots as $root) {
        if (pathIsWithin($path, $root)) {
            return null;
        }
    }

    try {
        $config = withoutOutput(static function () use ($path) { return @include $path; });
        return is_array($config) ? $config : null;
    } catch (\Throwable $error) {
        return null;
    }
}

function handleRequest(string $method, array $post, callable $loadConfig, callable $transport): array {
    if ($method !== 'POST') {
        return response(405, 'method_not_allowed');
    }
    $request = validateRequest($post);
    if ($request === null) {
        return response(400, 'invalid_request');
    }

    try {
        $config = withoutOutput($loadConfig);
        if (!is_array($config) ||
            !isset($config['server_key'], $config['authorize']) ||
            !is_string($config['server_key']) ||
            !preg_match('/\A[\x21-\x7E]{1,4096}\z/', $config['server_key']) ||
            !is_callable($config['authorize'])) {
            return response(503, 'service_unavailable');
        }
        // The hook must authenticate the caller and authorize this exact tuple.
        // Only literal true grants permission; exceptions also fail closed.
        $authorizationRequest = $request;
        $authorized = withoutOutput(static function () use ($config, $authorizationRequest) {
            return $config['authorize']($authorizationRequest);
        });
        if ($authorized !== true) {
            return response(403, 'forbidden');
        }
    } catch (\Throwable $error) {
        return response(503, 'service_unavailable');
    }

    try {
        $sent = withoutOutput(static function () use ($transport, $config, $request) {
            return $transport($config['server_key'], $request);
        });
        if ($sent === true) {
            return response(200);
        }
    } catch (\Throwable $error) {
        // Do not expose credentials, device tokens, or upstream error details.
    }
    return response(502, 'upstream_error');
}

function sendRequest(string $serverKey, array $request): bool {
    if (!function_exists('curl_init')) {
        return false;
    }
    $url = 'https://iid.googleapis.com/iid/v1:batch' .
        ($request['operation'] === 'subscribe' ? 'Add' : 'Remove');
    $body = json_encode([
        'to' => $request['topic'],
        'registration_tokens' => [$request['token']]
    ]);
    if ($body === false) {
        return false;
    }
    $ch = curl_init($url);
    if ($ch === false) {
        return false;
    }
    $responseBody = '';
    try {
        if (!curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_HTTPHEADER => [
                'Authorization:key=' . $serverKey,
                'Content-Type:application/json'
            ],
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_PROTOCOLS => CURLPROTO_HTTPS,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_WRITEFUNCTION => static function ($handle, $chunk) use (&$responseBody) {
                if (strlen($responseBody) + strlen($chunk) > 65536) {
                    return 0;
                }
                $responseBody .= $chunk;
                return strlen($chunk);
            }
        ])) {
            return false;
        }
        if (curl_exec($ch) === false || curl_getinfo($ch, CURLINFO_HTTP_CODE) !== 200) {
            return false;
        }
        $result = json_decode($responseBody);
        return $result instanceof \stdClass && !property_exists($result, 'error') && isset($result->results) &&
            is_array($result->results) && count($result->results) === 1 &&
            $result->results[0] instanceof \stdClass &&
            count(get_object_vars($result->results[0])) === 0;
    } finally {
        curl_close($ch);
    }
}
