"""Run with python3 and a Qt runner built from these sources (optionally FLOWCPP).
Use an xattr-capable filesystem and setfacl on Linux, or NTFS on Windows.
"""
import argparse
import os
import shutil
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
from threading import Thread


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--jit', action='store_true', help='use the default JIT instead of interpreter GC stress')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory() as tmp:
    work = Path(tmp)
    spool = work / 'spool'
    spool.mkdir()
    out = work / 'output'
    out.mkdir()
    bytecode = work / 'download.bytecode'
    compiler = root / ('bin/flowc1.bat' if os.name == 'nt' else 'bin/flowc1')
    runner = os.environ.get('FLOWCPP') or root / ('platforms/qt/bin/windows/QtByteRunner.exe' if os.name == 'nt' else 'bin/flowcpp')
    subprocess.run([compiler, 'server=0', f'bytecode={bytecode}',
                    'tests/http_download_file/download.flow'], cwd=root, check=True)

    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(SimpleHTTPRequestHandler, directory=work))
    Thread(target=server.serve_forever, daemon=True).start()

    def download(src, dest, headers=False, error=False, limit=False, defer_quit=False, legacy404=False, cache_target=''):
        cmd = [runner, '--batch', *([] if args.jit else ['--gc-stress-test']), bytecode, '--',
               f'url=http://127.0.0.1:{server.server_port}/{src.name}',
               f'dest={dest}', f'headers={int(headers)}', f'spool={spool}',
               f'deferQuit={int(defer_quit)}', f'legacy404={int(legacy404)}', f'cacheTarget={cache_target}']
        if limit:
            # Limit ordinary files in the runner child only. Large responses hit
            # the HTTP spool limit; small ones hit the destination stage limit.
            cmd[:0] = [sys.executable, '-c', 'import os, resource, signal, sys; '
                       'signal.signal(signal.SIGXFSZ, signal.SIG_IGN); '
                       'resource.setrlimit(resource.RLIMIT_FSIZE, (1024, 1024)); '
                       'os.execv(sys.argv[1], sys.argv[1:])']
        result = subprocess.run(cmd, env=dict(os.environ, FLOW=str(root), TMPDIR=str(spool), TMP=str(spool), TEMP=str(spool)),
                                cwd=work, capture_output=True, text=True, timeout=30)
        events = [line for line in result.stdout.splitlines() if line.startswith('download:')]
        assert len(events) == 1, (result.returncode, result.stdout, result.stderr)
        if error is True:
            assert events[0].startswith('download: error:'), events
        elif error:
            assert events == ['download: error: ' + error], events
        else:
            assert events == ['download: done'], events
        assert result.returncode == int(bool(error)), (result.returncode, result.stderr)
        assert not list(spool.glob('flowtmp*')), list(spool.iterdir())

    src, dest = work / 'source', out / 'result'
    for i, data in enumerate([b'', b'\x00\xffA', b'\xff\xfe' + bytes(range(256)) * 4096 + b'!']):
        src.write_bytes(data)
        download(src, dest, headers=bool(i % 2))
        assert dest.read_bytes() == data
    save_error = 'Could not save downloaded file'
    download(src, work / 'missing' / 'result', error=save_error)
    # Qt still delivers a response notification after a network error. Let that
    # notification run before quitting and check the original file is untouched.
    download(work / 'absent', dest, error=True, defer_quit=True)
    download(work / 'absent', dest, legacy404=True)
    assert dest.read_bytes() == data
    if os.name == 'posix':
        download(src, out / 'new', error='Could not write temporary download file', limit=True, defer_quit=True)
        assert set(out.iterdir()) == {dest}
    # Never run a replacement test against a system device in a writable /dev.
    if os.path.exists('/dev/full') and not os.access('/dev', os.W_OK):
        download(src, '/dev/full', headers=True, error=save_error)
        src.write_bytes(b'x')
        download(src, '/dev/full', error=save_error)  # Buffered error reported on close.
    if os.name == 'posix':
        fifo = work / 'pipe'
        os.mkfifo(fifo)
        src.write_bytes(b'stream')
        with os.fdopen(os.open(fifo, os.O_RDONLY | os.O_NONBLOCK), 'rb') as reader:
            download(src, fifo)
            assert stat.S_ISFIFO(fifo.stat().st_mode) and reader.read() == b'stream'
        src.write_bytes(bytes(range(256)) * 128)
        for target in (dest, out / 'new'):
            download(src, target, error=save_error, limit=True)
            assert dest.read_bytes() == data and set(out.iterdir()) == {dest}
        link = out / 'link'
        link.symlink_to(dest.name)
        download(src, link)
        assert link.is_symlink() and dest.read_bytes() == src.read_bytes()
        dest.write_bytes(b'A' * 150000)
        src.write_bytes(b'B' * 150000)
        download(src, link, cache_target=dest)
        assert link.is_symlink() and dest.read_bytes() == src.read_bytes()
    if sys.platform.startswith('linux'):
        if shutil.which('setfacl'):
            subprocess.run(['setfacl', '-m', f'u:{os.getuid()}:rw-,m::r--', dest], check=True)
            acl = os.getxattr(dest, 'system.posix_acl_access')
            src.write_bytes(b'updated with ACL')
            download(src, dest)
            assert dest.read_bytes() == src.read_bytes() and os.getxattr(dest, 'system.posix_acl_access') == acl
            previous = dest.read_bytes()
            src.write_bytes(b'x' * 4096)
            download(src, dest, error=save_error, limit=True)
            assert dest.read_bytes() == previous and os.getxattr(dest, 'system.posix_acl_access') == acl
            # The stage may inherit an ACL that the original file never had.
            with tempfile.TemporaryDirectory(dir=out) as nested:
                plain = Path(nested) / 'plain'
                plain.write_bytes(b'old')
                subprocess.run(['setfacl', '-b', plain], check=True)
                mode = stat.S_IMODE(plain.stat().st_mode)
                subprocess.run(['setfacl', '-d', '-m', f'u:{os.getuid()}:r--', nested], check=True)
                download(src, plain)
                assert plain.read_bytes() == src.read_bytes() and stat.S_IMODE(plain.stat().st_mode) == mode
                assert 'system.posix_acl_access' not in os.listxattr(plain) and set(Path(nested).iterdir()) == {plain}
        else:
            print('Skipping named ACL case: setfacl not installed')
        os.setxattr(dest, 'user.flow-test', b'keep')
        previous = dest.read_bytes()
        src.write_bytes(b'different')
        download(src, dest, error=save_error)
        assert dest.read_bytes() == previous and os.getxattr(dest, 'user.flow-test') == b'keep'
        assert set(out.iterdir()) == {dest, link}
    if os.name == 'nt':
        # Run on NTFS. The secondary stream belongs to the existing destination.
        stream = Path(str(dest) + ':notes')
        stream.write_bytes(b'keep stream')
        previous = dest.read_bytes()
        src.write_bytes(b'different')
        download(src, dest, error=save_error)
        download(src, stream, error=save_error)
        assert dest.read_bytes() == previous and stream.read_bytes() == b'keep stream'
        stream.unlink()
        import ctypes
        if ctypes.windll.advapi32.EncryptFileW(str(dest)):
            download(src, dest, error=save_error)
            assert dest.read_bytes() == previous and dest.stat().st_file_attributes & stat.FILE_ATTRIBUTE_ENCRYPTED
        else:
            print('Skipping EFS case: EncryptFileW unavailable on test volume/account')
        assert set(out.iterdir()) == {dest}
    server.shutdown()
    server.server_close()
print('Binary download tests passed')
