// Run: node --test tests/js/vimeo_player/test.js
// Execute the shipped wrapper with an SDK stub; no browser or network is needed.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '../../..');
const html = fs.readFileSync(path.join(root, 'www/vimeo_player.html'), 'utf8');
const source = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1];
const bridge = fs.readFileSync(path.join(root, 'www/js/toflow.js'), 'utf8');
const reporterStart = bridge.indexOf('function postPlayerStateChanges(');
const reporterEnd = bridge.indexOf('\nfunction openVideo(', reporterStart);
assert.ok(reporterStart >= 0 && reporterEnd > reporterStart);
const reporter = bridge.slice(reporterStart, reporterEnd);
const flush = () => new Promise(resolve => setImmediate(resolve));

function wrapper({ dimensions = () => [1920, 1080], sdk = true } = {}) {
	const messages = [], players = [], timers = new Map();
	let timerId = 0;
	const body = {
		appendChild(el) { el.parentNode = this; },
		removeChild(el) { el.parentNode = null; }
	};
	class Player {
		constructor() { this.events = {}; this.sizeReads = 0; players.push(this); }
		on(name, fn) { this.events[name] = fn; }
		off(name) { delete this.events[name]; }
		emit(name, data) { this.events[name]?.(data); }
		ready() { return Promise.resolve(); }
		getVideoWidth() { this.sizeReads++; return Promise.resolve().then(() => dimensions(this)[0]); }
		getVideoHeight() { return Promise.resolve().then(() => dimensions(this)[1]); }
		getPaused() { return Promise.resolve(true); }
		getEnded() { return Promise.resolve(false); }
		getCurrentTime() { return Promise.resolve(0); }
		getDuration() { return Promise.resolve(30); }
		getVolume() { return Promise.resolve(1); }
		getMuted() { return Promise.resolve(false); }
		destroy() {}
	}
	const context = {
		console, URL, setInterval() { return 1; }, clearInterval() {},
		setTimeout(fn) { const id = ++timerId; timers.set(id, fn); return id; },
		clearTimeout(id) { timers.delete(id); },
		window: { location: { href: 'https://example.test/vimeo_player.html' }, addEventListener() {} },
		document: { body, createElement() { return { setAttribute() {} }; } },
		sessionStorage: { length: 0, getItem() { return null; } },
		postToFlow(message) { messages.push(JSON.parse(JSON.stringify(message))); }
	};
	if (sdk) context.Vimeo = { Player };
	vm.createContext(context);
	vm.runInContext(reporter, context);
	vm.runInContext(source, context);
	return { context, players, messages, timers, sizes: () => messages.flatMap(m => m.playerState.videoSize ? [m.playerState.videoSize] : []) };
}

test('reports portrait metadata before ready and duration, even when loaded fires first', async () => {
	const w = wrapper();
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	let resolveWidth, resolveHeight;
	w.players[0].getVideoWidth = () => new Promise(resolve => { resolveWidth = resolve; });
	w.players[0].getVideoHeight = () => new Promise(resolve => { resolveHeight = resolve; });
	w.players[0].emit('loaded');
	await flush();
	assert.equal(w.context.current.duration, 30, 'playback polling can continue while metadata is pending');
	assert.deepEqual(w.messages, [], 'neither ready nor duration may initialize the fallback early');
	resolveWidth(1080);
	resolveHeight(1920);
	await flush();
	assert.deepEqual(w.messages[0], { playerState: { videoSize: { width: 1080, height: 1920 } } });
	assert.deepEqual(w.messages[1], { playerState: { ready: true } });
	assert.equal(w.messages[2].playerState.duration, 30, 'buffered state is flushed after ready');
});

test('readiness timeout releases fallback and buffered state if metadata never settles', async () => {
	const w = wrapper();
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	w.players[0].getVideoWidth = () => new Promise(() => {});
	w.players[0].getVideoHeight = () => new Promise(() => {});
	w.players[0].emit('loaded');
	await flush();
	assert.deepEqual(w.messages, []);
	w.timers.get(w.context.readyTimer)();
	assert.deepEqual(w.messages[0], { playerState: { ready: true } });
	assert.equal(w.messages[1].playerState.duration, 30);
});

test('readiness does not publish default playback values before the first poll completes', async () => {
	const w = wrapper();
	w.context.createPlayer('https://player.vimeo.com/video/1?autoplay=1#t=12s', {});
	let resolvePaused;
	w.players[0].getPaused = () => new Promise(resolve => { resolvePaused = resolve; });
	w.players[0].getCurrentTime = () => Promise.resolve(12);
	w.players[0].getDuration = () => Promise.resolve(60);
	await flush();
	assert.ok(w.messages.some(m => m.playerState.ready === true));
	assert.ok(w.messages.every(m => !('status' in m.playerState) && !('currentTime' in m.playerState) && !('duration' in m.playerState)));
	resolvePaused(false);
	await flush();
	assert.deepEqual(w.messages.at(-1).playerState, { status: 'PLAYING', duration: 60, currentTime: 12, volume: 100 });
});

test('readiness flushes partial observed state without inventing an unobserved status', async () => {
	const w = wrapper();
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	w.players[0].getPaused = () => new Promise(() => {});
	w.players[0].emit('timeupdate', { seconds: 12, duration: 60 });
	await flush();
	assert.deepEqual(w.messages.at(-1).playerState, { duration: 60, currentTime: 12 });
	w.players[0].emit('seeked', { seconds: 14 });
	assert.deepEqual(w.messages.at(-1).playerState, { currentTime: 14 });
});

test('readiness timeout does not manufacture playback state when both reads are pending', async () => {
	const w = wrapper();
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	w.players[0].getPaused = () => new Promise(() => {});
	w.players[0].getVideoWidth = () => new Promise(() => {});
	w.players[0].getVideoHeight = () => new Promise(() => {});
	await flush();
	w.timers.get(w.context.readyTimer)();
	assert.deepEqual(w.messages, [{ playerState: { ready: true } }]);
});

test('reports intrinsic dimensions independently of the iframe layout', async () => {
	const w = wrapper();
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	await flush();
	assert.deepEqual(w.sizes(), [{ width: 1920, height: 1080 }]);
	// Repeated load/metadata notifications must keep the original landscape ratio.
	for (let i = 0; i < 8; i++) {
		w.context.iframe.width = 800 / (i + 1);
		w.context.iframe.height = 450;
		w.players[0].emit('loaded');
		await flush();
	}
	assert.deepEqual(w.sizes(), [{ width: 1920, height: 1080 }]);
});

test('updates dimensions when the intrinsic media size changes', async () => {
	let dimensions = [1920, 1080];
	const w = wrapper({ dimensions: () => dimensions });
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	await flush();
	dimensions = [1080, 1920];
	w.players[0].emit('resize');
	await flush();
	assert.deepEqual(w.sizes().at(-1), { width: 1080, height: 1920 });
});

test('retries rejected or invalid resize metadata even with a previously cached size', async () => {
	for (const invalid of [null, [0, 0]]) {
		let dimensions = [1920, 1080];
		const w = wrapper({ dimensions: () => {
			if (!dimensions) throw new Error('resize metadata not ready');
			return dimensions;
		} });
		w.context.createPlayer('https://player.vimeo.com/video/1', {});
		await flush();
		dimensions = invalid;
		w.players[0].emit('resize');
		await flush();
		assert.deepEqual(w.sizes(), [{ width: 1920, height: 1080 }]);
		dimensions = [1080, 1920];
		w.context.refresh();
		await flush();
		assert.deepEqual(w.sizes().at(-1), { width: 1080, height: 1920 });
	}
});

test('a resize during a pending metadata read is retried and its obsolete result is ignored', async () => {
	const w = wrapper();
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	await flush();
	let resolveWidth, resolveHeight;
	w.players[0].getVideoWidth = () => new Promise(resolve => { resolveWidth = resolve; });
	w.players[0].getVideoHeight = () => new Promise(resolve => { resolveHeight = resolve; });
	w.players[0].emit('resize');
	w.players[0].emit('resize');
	resolveWidth(640);
	resolveHeight(360);
	await flush();
	assert.deepEqual(w.sizes(), [{ width: 1920, height: 1080 }]);
	w.players[0].getVideoWidth = () => Promise.resolve(1080);
	w.players[0].getVideoHeight = () => Promise.resolve(1920);
	w.context.refresh();
	await flush();
	assert.deepEqual(w.sizes().at(-1), { width: 1080, height: 1920 });
});

test('ignores dimensions returned after the player has been replaced', async () => {
	let resolveWidth, resolveHeight;
	const w = wrapper();
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	await flush();
	w.players[0].getVideoWidth = () => new Promise(resolve => { resolveWidth = resolve; });
	w.players[0].getVideoHeight = () => new Promise(resolve => { resolveHeight = resolve; });
	w.players[0].emit('resize');
	w.context.createPlayer('https://player.vimeo.com/video/2', {});
	await flush();
	w.messages.length = 0;
	resolveWidth(100);
	resolveHeight(200);
	await flush();
	assert.deepEqual(w.sizes(), []);
});

test('rejects zero, negative, missing and non-finite dimensions', async () => {
	for (const dimensions of [[0, 0], [-1, 720], [1280, undefined], [Infinity, 720], [1280, NaN]]) {
		const w = wrapper({ dimensions: () => dimensions });
		w.context.createPlayer('https://player.vimeo.com/video/1', {});
		await flush();
		w.players[0].emit('loaded');
		await flush();
		assert.deepEqual(w.sizes(), []);
		assert.ok(w.messages.some(m => m.playerState.ready === true));
	}
});

test('metadata failure does not prevent the ready notification', async () => {
	const w = wrapper({ dimensions: () => { throw new Error('not available'); } });
	// SDK methods reject asynchronously, as the real SDK does.
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	w.players[0].getVideoWidth = () => Promise.reject(new Error('not available'));
	w.players[0].getVideoHeight = () => Promise.reject(new Error('not available'));
	await flush();
	w.players[0].emit('loaded');
	await flush();
	assert.deepEqual(w.sizes(), []);
	assert.ok(w.messages.some(m => m.playerState.ready === true));
});

test('retries late metadata after zero dimensions or rejection, then stops polling it', async () => {
	for (const initial of [[0, 0], null]) {
		let dimensions = initial;
		const w = wrapper({ dimensions: () => {
			if (!dimensions) throw new Error('metadata not ready');
			return dimensions;
		} });
		w.context.createPlayer('https://player.vimeo.com/video/1', {});
		await flush();
		assert.deepEqual(w.sizes(), []);
		dimensions = [1920, 1080];
		w.context.refresh();
		await flush();
		assert.deepEqual(w.sizes(), [{ width: 1920, height: 1080 }]);
		const reads = w.players[0].sizeReads;
		for (let i = 0; i < 8; i++) {
			w.context.refresh();
			await flush();
		}
		assert.equal(w.players[0].sizeReads, reads);
	}
});

test('does not overlap metadata requests while a previous read is pending', async () => {
	const w = wrapper();
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	let reads = 0, resolveWidth, resolveHeight;
	w.players[0].getVideoWidth = () => { reads++; return new Promise(resolve => { resolveWidth = resolve; }); };
	w.players[0].getVideoHeight = () => new Promise(resolve => { resolveHeight = resolve; });
	await flush();
	for (let i = 0; i < 8; i++) {
		w.context.refresh();
		await flush();
	}
	assert.equal(reads, 1);
	resolveWidth(1920);
	resolveHeight(1080);
	await flush();
	assert.deepEqual(w.sizes(), [{ width: 1920, height: 1080 }]);
});

test('retries metadata without a positive duration for live streams', async () => {
	let dimensions = [0, 0];
	const w = wrapper({ dimensions: () => dimensions });
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	w.players[0].getDuration = () => Promise.resolve(0);
	await flush();
	assert.equal(w.context.current.duration, 0);
	dimensions = [1280, 720];
	w.context.refresh();
	await flush();
	assert.deepEqual(w.sizes(), [{ width: 1280, height: 720 }]);
});

test('resets cached dimensions and retry state when switching videos', async () => {
	const w = wrapper();
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	await flush();
	w.context.createPlayer('https://player.vimeo.com/video/2', {});
	await flush();
	assert.deepEqual(w.sizes(), [{ width: 1920, height: 1080 }, { width: 1920, height: 1080 }]);
});

test('plain iframe fallback still becomes ready without the SDK', () => {
	const w = wrapper({ sdk: false });
	w.context.createPlayer('https://player.vimeo.com/video/1', {});
	w.context.iframe.onload();
	assert.deepEqual(w.sizes(), []);
	assert.ok(w.messages.some(m => m.playerState.ready === true));
});
