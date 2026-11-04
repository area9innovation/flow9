<?php

require_once __DIR__ . '/messaging_handler.php';

$response = \FlowFirebaseMessaging\handleRequest(
    $_SERVER['REQUEST_METHOD'] ?? '',
    $_POST,
    'FlowFirebaseMessaging\\loadConfiguration',
    'FlowFirebaseMessaging\\sendRequest'
);

http_response_code($response['status']);
header('Content-Type: application/json');
header('Cache-Control: no-store');
if ($response['status'] === 405) {
    header('Allow: POST');
}
echo json_encode($response['body']);
