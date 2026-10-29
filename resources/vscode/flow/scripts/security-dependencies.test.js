'use strict';

const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const test = require('node:test');

// Resolve the actual packaging-tool dependency tree, including nested overrides.
const requireVsce = createRequire(require.resolve('@vscode/vsce'));
const requireIdentity = createRequire(requireVsce.resolve('@azure/identity'));
const { ConfidentialClientApplication } = requireIdentity('@azure/msal-node');
const { ClientSecretCredential, AuthorizationCodeCredential } = requireVsce('@azure/identity');
const { createHttpHeaders } = requireIdentity('@azure/core-rest-pipeline');
const requireSecretlint = createRequire(requireVsce.resolve('@secretlint/node'));
const requireConfigLoader = createRequire(requireSecretlint.resolve('@secretlint/config-loader'));
const requireAjv = createRequire(requireConfigLoader.resolve('ajv'));
const uri = requireAjv('fast-uri');

const tenant = '00000000-0000-0000-0000-000000000001';
const clientId = '00000000-0000-0000-0000-000000000002';
const authority = `https://login.microsoftonline.com/${tenant}`;
const scope = 'https://management.azure.com/.default';
const metadata = {
    authorization_endpoint: `${authority}/oauth2/v2.0/authorize`,
    token_endpoint: `${authority}/oauth2/v2.0/token`,
    issuer: `${authority}/v2.0`,
    jwks_uri: `${authority}/discovery/v2.0/keys`,
};
const tokenResponse = {
    access_token: 'offline-test-token',
    token_type: 'Bearer',
    expires_in: 3600,
    scope,
};

test('GHSA-w74x-v6f9-j3xg: percent-encoded schemes fail closed', () => {
    for (const input of ['%6Aavascript:alert(1)', 'ht%74ps://example.com:443']) {
        assert.equal(uri.parse(input).error, 'URI scheme is malformed.');
        assert.equal(uri.normalize(input), input);
        assert.equal(uri.equal(input, input), false);
        assert.throws(() => uri.resolve('https://trusted.example/', input), /URI scheme is malformed\./);
    }
    assert.equal(uri.normalize('HTTPS://Example.COM:443/path'), 'https://example.com/path');
});

test('GHSA-xhq7-xmqj-769h: relative normalization preserves the target', () => {
    const base = 'https://trusted.example/a/b/file';
    for (const input of ['a/../b', '../x', 'x/..', 'a/..//x']) {
        assert.equal(uri.resolve(base, uri.normalize(input)), uri.resolve(base, input));
    }
    assert.equal(uri.equal('../x', 'x'), false);
    assert.equal(uri.equal('a/../b', '/b'), false);
    assert.equal(uri.equal('a/../b', 'b'), true);
});

test('GHSA-wjr9-j795-jxcr: malformed hosts cannot alias another host', () => {
    for (const input of ['https://a@b@evil.example/', 'https://ev\til.example/']) {
        assert.equal(uri.parse(input).error, 'URI host is malformed.');
        assert.equal(uri.normalize(input), input);
        assert.equal(uri.equal(input, 'https://evil.example/'), false);
        assert.throws(() => uri.resolve('https://trusted.example/', input), /URI host is malformed\./);
    }
    assert.equal(uri.parse('https://user:pass@example.com:8080/').host, 'example.com');
});

test('GHSA-333x-w4r6-6crp: suffix normalization cannot introduce a scheme', () => {
    const options = { reference: 'suffix', scheme: 'x' };
    for (const input of ['javascript:alert(1)', 'data:text/html,x', 'vbscript:msgbox(1)']) {
        assert.equal(uri.parse(uri.normalize(input, options)).scheme, undefined);
    }
    assert.equal(uri.normalize('javascript:alert(1)', options), 'javascript%3Aalert(1)');
    for (const input of ['./a:b', 'a/../a:b']) {
        const normalized = uri.normalize(input, options);
        assert.equal(normalized, './a:b');
        assert.equal(uri.parse(normalized).scheme, undefined);
    }
});

function createConfidentialClient(requests) {
    return new ConfidentialClientApplication({
        auth: {
            clientId,
            clientSecret: 'offline-test-secret',
            authority,
            knownAuthorities: ['login.microsoftonline.com'],
            authorityMetadata: JSON.stringify(metadata),
        },
        system: {
            networkClient: {
                async sendGetRequestAsync(url) {
                    assert.fail(`Unexpected network discovery: ${url}`);
                },
                async sendPostRequestAsync(url, options) {
                    requests.push({ url, body: new URLSearchParams(options.body) });
                    return { status: 200, headers: {}, body: tokenResponse };
                },
            },
        },
    });
}

test('GHSA-xcx6-jx8p-x3h5: authorization response cannot redirect confidential token exchange', async () => {
    const requests = [];
    const client = createConfidentialClient(requests);
    const token = await client.acquireTokenByCode({
        code: 'trusted-request-code',
        redirectUri: 'http://localhost/callback',
        scopes: [scope],
    }, {
        code: 'untrusted-response-code',
        cloud_instance_host_name: 'attacker.example',
        cloud_graph_host_name: 'attacker.example',
        msgraph_host: 'attacker.example',
    });

    assert.equal(token.accessToken, tokenResponse.access_token);
    assert.equal(requests.length, 1);
    assert.equal(requests[0].url.split('?')[0], metadata.token_endpoint);
    assert.equal(requests[0].body.get('code'), 'trusted-request-code');
    assert.equal(requests[0].body.get('client_secret'), 'offline-test-secret');
});

test('confidential clients reject instance-aware authorization requests', async () => {
    const client = createConfidentialClient([]);
    await assert.rejects(client.getAuthCodeUrl({
        redirectUri: 'http://localhost/callback',
        scopes: [scope],
        extraQueryParameters: { instance_aware: 'true' },
    }), { errorCode: 'unsupported_cca_instance_aware' });
});

for (const grant of ['client_credentials', 'authorization_code']) {
    test(`Azure Identity remains compatible with overridden MSAL (${grant})`, async () => {
        const requests = [];
        const options = {
            disableInstanceDiscovery: true,
            httpClient: {
                async sendRequest(request) {
                    requests.push(request);
                    assert.equal(new URL(request.url).origin, 'https://login.microsoftonline.com');
                    const body = request.method === 'GET' ? metadata : tokenResponse;
                    return {
                        request,
                        status: 200,
                        headers: createHttpHeaders({ 'content-type': 'application/json' }),
                        bodyAsText: JSON.stringify(body),
                    };
                },
            },
        };
        const credential = grant === 'client_credentials'
            ? new ClientSecretCredential(tenant, clientId, 'offline-test-secret', options)
            : new AuthorizationCodeCredential(tenant, clientId, 'offline-test-secret',
                'offline-test-code', 'http://localhost/callback', options);

        const token = await credential.getToken(scope);
        assert.equal(token.token, tokenResponse.access_token);
        assert.ok(token.expiresOnTimestamp > Date.now());
        const exchanges = requests.filter(request => request.method === 'POST');
        assert.equal(exchanges.length, 1);
        assert.equal(exchanges[0].url.split('?')[0], metadata.token_endpoint);
        const body = new URLSearchParams(exchanges[0].body);
        assert.equal(body.get('grant_type'), grant);
        assert.equal(body.get('client_secret'), 'offline-test-secret');
        if (grant === 'authorization_code') {
            assert.equal(body.get('code'), 'offline-test-code');
        }
    });
}
