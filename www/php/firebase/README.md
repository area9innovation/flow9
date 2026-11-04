# Web topic subscriptions

`messaging.php` is an optional server-side helper for the web implementations of
`subscribeToFBTopic` and `unsubscribeFromFBTopic`. It is **disabled by default**.
Copying a Firebase credential into a public script is not a supported setup.
Native Android and iOS topic subscriptions do not use this PHP helper.

## Setup and migration

1. Deploy both `messaging.php` and `messaging_handler.php` with PHP 7.4 or newer,
   the cURL extension, and an up-to-date TLS trust store.
2. Create a PHP configuration file **outside every web-accessible directory**.
   Set `FLOW_FIREBASE_MESSAGING_CONFIG` in the PHP server environment to its
   absolute filename. The helper rejects configuration inside its public tree or
   the server's `DOCUMENT_ROOT`, including paths resolved through symlinks. Do not
   expose the configuration through web-server aliases, static hosting, or source
   control. Configure the PHP worker's local process environment, not a
   client-supplied header or request parameter. With PHP-FPM, explicitly pass
   this setting through its pool's `env` configuration when needed.
3. Return an array with `server_key` (the server-only Firebase credential) and
   `authorize` (a server-side callable). Load the credential from your existing
   server-side secret management. Do not put it in JavaScript, Flow code, or a
   browser configuration file.
4. Implement and test the authorization hook using your application's existing
   backend authentication and policy. Enable the helper only after that
   integration is complete. An existing deployment that only set `$server_key`
   must migrate to this configuration; otherwise requests return HTTP 503.

This configuration shape deliberately **denies every request** until the
application supplies its own authorization implementation:

```php
<?php
return [
    'server_key' => '', // Supply through server-side secret management.
    'authorize' => static function (array $request): bool {
        return false; // Replace with the application's backend checks below.
    }
];
```

### Authorization contract

The hook runs once per valid POST, before any Firebase call, with:

```php
[
    'topic' => '/topics/example',
    'token' => 'example-device-token',
    'operation' => 'subscribe' // Or 'unsubscribe'.
]
```

It must return literal `true` only after all of these checks succeed:

- Authenticate the caller using trusted backend identity (for example, the
  application's verified session or verified access token). The helper does not
  start a session or interpret an authentication header on the application's
  behalf.
- Verify that this identity is authorized for **this topic, this registered
  device token, and this operation**. Use trusted backend ownership/registration
  state for device tokens, not the fact that the caller submitted a token.
- Apply the application's CSRF protection for cookie-authenticated requests and
  its normal request/rate limits. CORS, a browser-embedded shared key, a public
  Firebase configuration, and syntactic validation are not caller authorization.

The hook may read the application's server-side request/session context, but
must not output data or send an HTTP response. Return `false` to deny access;
exceptions fail closed with a generic service-unavailable response. It receives
canonical values identical to those sent to Firebase. Do not grant access based
solely on a topic allowlist or device-token format.

The existing JS client sends only `doSubscribe`, `topic`, and `token`, using a
same-origin POST. That wire format remains supported; no public client secret
is added. Applications requiring additional authentication or CSRF headers must
integrate their authenticated request layer (or make an authenticated POST from
application code). The high-level Flow subscription functions do not expose
custom headers or report this helper's response. They do not establish identity
or register token ownership for the backend.

## Requests and responses

- Only POST is accepted. `doSubscribe` must be the string `true` or `false`;
  `topic` and `token` must also be strings, not arrays or other values.
- A topic name contains 1–900 ASCII letters, digits, or `-_.~%`. Both a bare name
  and `/topics/` followed by a name are accepted and normalized to `/topics/name`
  before authorization. Policy implementations should use this normalized form.
- A device token contains 1–4096 ASCII letters, digits, or `_:-`. Whitespace,
  control characters, empty strings, and other characters are rejected. These
  checks do not establish token validity or ownership.
- HTTP 200 means Firebase returned a successful result for the single token.
  Errors use JSON `{"error":"..."}`: 400 `invalid_request`, 403 `forbidden`
  (including unauthenticated callers), 405 `method_not_allowed` with `Allow:
  POST`, 503 `service_unavailable` for missing/invalid configuration or a failing
  authorization hook, and 502 `upstream_error` for transport/Firebase failures.
  Responses are non-cacheable and never forward upstream bodies or exceptions.
- The transport uses a fixed HTTPS destination, verifies TLS, does not follow
  redirects, has 5-second connection and 15-second overall timeouts, and limits
  the response body to 64 KiB. The helper retains the existing Firebase IID batch
  API and server-credential scheme; verify provider support for your deployment.

## Offline tests

From the repository root, with PHP CLI and cURL available:

```sh
php -l www/php/firebase/messaging.php
php -l www/php/firebase/messaging_handler.php
php tests/test_firebase_messaging.php
```

The tests use synthetic configuration, authorization callbacks, and a fake cURL
transport. They do not contact Firebase or need credentials. Applications must
also test their real backend authorization integration before enabling the helper.
