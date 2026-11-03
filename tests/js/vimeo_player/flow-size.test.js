const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '../../..');

test('Flow sizing: Vimeo fallback/reloads/intrinsic metadata and YouTube legacy behavior', () => {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flow-vimeo-size-'));
	try {
		// Append a test entry point to the actual implementation to exercise its private constructors
		// without exporting test hooks or initializing a renderer. The repository source is untouched.
		const source = fs.readFileSync(path.join(root, 'lib/material/internal/material_player.flow'), 'utf8');
		const fixture = fs.readFileSync(path.join(__dirname, 'size-regression.flow'), 'utf8');
		fs.writeFileSync(path.join(dir, 'player-size.flow'), source + '\n' + fixture);
		for (const [program, args] of [
			['flowc1', ['player-size.flow', 'bytecode=player-size.bytecode', `I=${path.join(root, 'lib')}`]],
			['flowcpp', ['--batch', 'player-size.bytecode']]
		]) {
			const result = spawnSync(path.join(root, 'bin', program), args, { cwd: dir, encoding: 'utf8', timeout: 60000 });
			assert.equal(result.status, 0, `${program} failed: ${result.error || ''}\n${result.stdout || ''}\n${result.stderr || ''}`);
		}
	} finally {
		fs.rmSync(dir, { recursive: true, force: true });
	}
});
