'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
const path = require('node:path');
const test = require('node:test');

const { createRequire } = Module;
const root = path.join(__dirname, '..');

// Resolve the actual dependency tree, including overrides.
const requireVsce = createRequire(require.resolve('@vscode/vsce'));
const requireIdentity = createRequire(requireVsce.resolve('@azure/identity'));
const { ConfidentialClientApplication } = requireIdentity('@azure/msal-node');
const { ClientSecretCredential, AuthorizationCodeCredential } = requireVsce('@azure/identity');
const { createHttpHeaders } = requireIdentity('@azure/core-rest-pipeline');
const requireClient = createRequire(require.resolve('vscode-languageclient/node'));
const semver = requireVsce('semver');

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

// The first fixed version for each advisory that has been raised against this tree.
const patched = {
    'minimatch': ['11.0.1', 'GHSA-g3hv-75wg-m249'],
    '@azure/msal-node': ['7.1.0', 'GHSA-xcx6-jx8p-x3h5'],
    'fast-uri': ['3.1.9', 'GHSA-w74x-v6f9-j3xg, GHSA-xhq7-xmqj-769h, GHSA-wjr9-j795-jxcr, GHSA-333x-w4r6-6crp'],
};

test('the lockfile has no version older than its advisory fix', () => {
    const lock = JSON.parse(fs.readFileSync(path.join(root, 'package-lock.json'), 'utf8'));
    let seen = 0;
    for (const [key, entry] of Object.entries(lock.packages)) {
        const name = key.slice(key.lastIndexOf('node_modules/') + 'node_modules/'.length);
        if (!key || !(name in patched)) {
            continue;
        }
        const [fixed, advisories] = patched[name];
        assert.ok(semver.gte(entry.version, fixed), `${key}@${entry.version} is affected by ${advisories}`);
        seen++;
    }
    assert.ok(seen > 0);
});

// A stand-in for the `vscode` module: the members the file operation feature
// uses, and an empty stub for everything the extension touches at load time.
function stubVscode() {
    const listeners = [];
    const members = {
        __esModule: true,
        FileType: { File: 1, Directory: 2 },
        workspace: {
            onDidCreateFiles(listener, thisArg) {
                listeners.push(listener.bind(thisArg));
                return { dispose() {} };
            },
            fs: { async stat() { return { type: 1 }; } },
        },
    };
    const stub = { get: (target, key) => key in target ? target[key] : new Proxy(function () {}, stub) };
    const vscode = new Proxy(members, stub);
    const resolve = Module._resolveFilename;
    Module._resolveFilename = function (request, ...rest) {
        return request === 'vscode' ? 'vscode' : resolve.call(this, request, ...rest);
    };
    require.cache.vscode = { id: 'vscode', filename: 'vscode', loaded: true, exports: vscode };
    return listeners;
}

test('GHSA-g3hv-75wg-m249: `**/..` expansion is bounded', () => {
    const minimatch = require('minimatch');
    assert.equal(requireVsce('minimatch'), minimatch);
    assert.equal(requireClient('minimatch'), minimatch);
    const pattern = Array.from({ length: 16 }, (_, i) => `a${i}/**/..`).join('/') + '/x';
    const start = Date.now();
    assert.throws(() => new minimatch.Minimatch(pattern, { optimizationLevel: 2 }), RangeError);
    assert.ok(Date.now() - start < 5000);
});

test('vscode-languageclient file operation filters work with minimatch 11', async () => {
    const listeners = stubVscode();
    // The extension entry point installs the Minimatch#makeRe() shim.
    require(path.join(root, 'out', 'extension.js'));
    const { DidCreateFilesFeature } = requireClient('vscode-languageclient/$test/common/fileOperations');

    const sent = [];
    const warnings = [];
    const client = {
        code2ProtocolConverter: {
            asDidCreateFilesParams: event => ({ files: event.files.map(uri => ({ uri: uri.toString() })) }),
        },
        middleware: {},
        sendNotification: async (_type, params) => { sent.push(params); },
        warn: message => warnings.push(message),
        info() {},
    };
    const feature = new DidCreateFilesFeature(client);
    feature.initialize({
        workspace: {
            fileOperations: {
                didCreate: {
                    filters: [
                        { scheme: 'file', pattern: { glob: '**/*.{flow,lingo}' } },
                        { pattern: { glob: '**/flow.config', options: { ignoreCase: true } } },
                        { pattern: { glob: '**/lib', matches: 'folder' } },
                    ],
                },
            },
        },
    });
    assert.deepEqual(warnings, []);

    const file = (fsPath, scheme = 'file') => ({ fsPath, scheme, toString: () => `${scheme}://${fsPath}` });
    await listeners[0]({
        files: [
            file('/w/a.flow'), file('/w/b.ts'), file('/w/sub/c.lingo'), file('/w/.hidden/d.flow'),
            file('/w/Flow.Config'), file('/w/lib'), file('/w/e.flow', 'untitled'),
        ],
    });
    assert.deepEqual(sent, [{
        files: ['file:///w/a.flow', 'file:///w/sub/c.lingo', 'file:///w/.hidden/d.flow', 'file:///w/Flow.Config']
            .map(uri => ({ uri })),
    }]);

    // A pattern that matches nothing is still rejected.
    feature.initialize({ workspace: { fileOperations: { didCreate: { filters: [{ pattern: { glob: '#comment' } }] } } } });
    assert.equal(warnings.length, 1);
    assert.match(warnings[0], /Invalid pattern #comment/);
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
    test(`Azure Identity works with MSAL Node 7 (${grant})`, async () => {
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
