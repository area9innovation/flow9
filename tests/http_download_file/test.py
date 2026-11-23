"""Run with python3. Requires a Qt runner built from these sources."""
import os
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import tempfile
from threading import Thread


root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory() as tmp:
    work = Path(tmp)
    bytecode = work / 'download.bytecode'
    subprocess.run([root / 'bin/flowc1', 'server=0', f'bytecode={bytecode}',
                    'tests/http_download_file/download.flow'], cwd=root, check=True)

    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(SimpleHTTPRequestHandler, directory=work))
    Thread(target=server.serve_forever, daemon=True).start()

    def download(src, dest, headers=False, error=False):
        result = subprocess.run([root / 'bin/flowcpp', '--batch', bytecode, '--',
                                 f'url=http://127.0.0.1:{server.server_port}/{src.name}',
                                 f'dest={dest}', f'headers={int(headers)}'],
                                cwd=work, capture_output=True, text=True, timeout=30)
        events = [line for line in result.stdout.splitlines() if line.startswith('download:')]
        assert len(events) == 1, (events, result.stderr)
        if error:
            assert events[0].startswith('download: error:'), events
        else:
            assert events == ['download: done'], events
        assert result.returncode == int(error), (result.returncode, result.stderr)

    src, dest = work / 'source', work / 'result'
    for i, data in enumerate([b'', b'\x00\xffA', b'\xff\xfe' + bytes(range(256)) * 4096 + b'!']):
        src.write_bytes(data)
        download(src, dest, headers=bool(i % 2))
        assert dest.read_bytes() == data
    download(src, work / 'missing' / 'result', error=True)
    if os.path.exists('/dev/full'):
        download(src, '/dev/full', headers=True, error=True)
        src.write_bytes(b'x')
        download(src, '/dev/full', error=True)  # Buffered error reported on close.
    server.shutdown()
    server.server_close()
print('Binary download tests passed')
