"""Run with python3 and a Qt runner built from these sources (optionally FLOWCPP).
Use an xattr-capable filesystem and setfacl on Linux. The default Windows suite needs local
transaction-capable NTFS; --windows-no-txf-dir DIR tests an unsupported ACL-bearing volume separately.
On Linux, build with qmake DEFINES+=FLOW_TEST_NO_SEARCH_HANDLE and pass --no-search-handle
to also check the refusal when the long-path fallback has no writable temporary directory.
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
parser.add_argument('--no-search-handle', action='store_true', help='expect a Linux runner built with FLOW_TEST_NO_SEARCH_HANDLE (run unprivileged with procfs)')
windows = parser.add_mutually_exclusive_group()
windows.add_argument('--windows-audit', action='store_true', help='also check an explicit audit rule (requires SACL access on the disposable NTFS fixture)')
windows.add_argument('--windows-no-txf-dir', type=Path, metavar='DIR',
                     help='only test create/refused refresh in a writable directory on an ACL-bearing SMB share, ReFS or other volume without usable TxF')
args = parser.parse_args()
if args.no_search_handle and (not sys.platform.startswith('linux') or os.geteuid() == 0 or not Path('/proc/self/fd').is_dir()):
    parser.error('--no-search-handle needs an unprivileged Linux process with procfs')
if args.windows_no_txf_dir and os.name != 'nt':
    parser.error('--windows-no-txf-dir requires Windows')
root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory() as tmp:
    work = Path(tmp)
    spool = work / 'spool'
    spool.mkdir(mode=0o700)
    out = work / 'output'
    out.mkdir()
    bytecode = work / 'download.bytecode'
    compiler = root / ('bin/flowc1.bat' if os.name == 'nt' else 'bin/flowc1')
    runner = os.environ.get('FLOWCPP') or root / ('platforms/qt/bin/windows/QtByteRunner.exe' if os.name == 'nt' else 'bin/flowcpp')
    subprocess.run([compiler, 'server=0', f'bytecode={bytecode}',
                    'tests/http_download_file/download.flow'], cwd=root, check=True)

    class Handler(SimpleHTTPRequestHandler):
        def do_GET(self):
            if self.path == '/while-missing':
                # A second producer finishes after the request starts, before its response.
                with peer.open('xb') as writer:
                    writer.write(b'peer result')
            super().do_GET()

    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=work))
    Thread(target=server.serve_forever, daemon=True).start()

    def download(src, dest, headers=False, error=False, limit=False, defer_quit=False, legacy404=False, cache_target='', next_cwd='', cwd=work, fd_marker=''):
        cmd = [runner, '--batch', *([] if args.jit else ['--gc-stress-test']), bytecode, '--',
               f'url=http://127.0.0.1:{server.server_port}/{src.name}',
               f'dest={dest}', f'headers={int(headers)}', f'spool={spool}',
               f'deferQuit={int(defer_quit)}', f'legacy404={int(legacy404)}', f'cacheTarget={cache_target}', f'nextCwd={next_cwd}',
               f'fdMarker={fd_marker}']
        if limit:
            # Limit ordinary files in the runner child only. Large responses hit
            # the HTTP spool limit; small ones hit the destination stage limit.
            cmd[:0] = [sys.executable, '-c', 'import os, resource, signal, sys; '
                       'signal.signal(signal.SIGXFSZ, signal.SIG_IGN); '
                       'resource.setrlimit(resource.RLIMIT_FSIZE, (1024, 1024)); '
                       'os.execv(sys.argv[1], sys.argv[1:])']
        result = subprocess.run(cmd, env=dict(os.environ, FLOW=str(root), TMPDIR=str(spool), TMP=str(spool), TEMP=str(spool)),
                                cwd=cwd, capture_output=True, text=True, timeout=30)
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
    save_error = 'Could not save downloaded file'
    if args.windows_no_txf_dir:
        with tempfile.TemporaryDirectory(dir=args.windows_no_txf_dir.resolve()) as folder:
            target = Path(folder) / 'result'
            src.write_bytes(b'first download')
            download(src, target)
            assert target.read_bytes() == b'first download'
            with target.open('r+b') as writable:  # Ordinary write access is not the reason for refusal.
                writable.write(b'first download')
            src.write_bytes(b'refresh')
            download(src, target, headers=True, error=save_error)
            assert target.read_bytes() == b'first download' and set(Path(folder).iterdir()) == {target}
        server.shutdown()
        server.server_close()
        print('Windows create/refused refresh test passed')
        sys.exit(0)

    other = work / 'other-cwd'
    other.mkdir()
    (other / 'cwd-marker').touch()
    src.write_bytes(b'new download')
    download(src, 'relative-new', headers=True, next_cwd=other)
    assert (work / 'relative-new').read_bytes() == src.read_bytes() and not (other / 'relative-new').exists()

    cached = work / 'relative-cached'
    cached.write_bytes(b'A' * 150000)
    (other / cached.name).write_bytes(b'C' * 150000)
    src.write_bytes(b'B' * 150000)
    download(src, cached.name, cache_target=cached, next_cwd=other)
    assert cached.read_bytes() == src.read_bytes() and (other / cached.name).read_bytes() == b'C' * 150000

    if os.name == 'posix':
        # The filesystem interprets '..' after following the directory symlink.
        child = work / 'tree' / 'child'
        child.mkdir(parents=True)
        (work / 'shortcut').symlink_to(child)
        download(src, 'shortcut/../through-link', next_cwd=other)
        assert (child.parent / 'through-link').read_bytes() == src.read_bytes() and not (work / 'through-link').exists()

        # Keep the test driver's own paths short via a directory alias halfway
        # down the tree. The runner's physical cwd fits; cwd + '/' + leaf does not.
        path_max = os.pathconf(work, 'PC_PATH_MAX')
        if path_max > 0:
            deep = short = work.resolve()
            components = []
            while len(os.fsencode(deep)) < path_max - 41:
                component = 'd' * min(120, path_max - 40 - len(os.fsencode(deep)) - 1)
                deep, short = deep / component, short / component
                short.mkdir()
                components.append(short)
                if deep == short and len(os.fsencode(deep)) >= path_max // 2:
                    short = work / 'deep-alias'
                    short.symlink_to(deep, target_is_directory=True)
            leaf = 'result-' + 'r' * 80
            alias = 'alias-' + 'a' * 80
            assert all(len(os.fsencode(deep / name)) >= path_max for name in (leaf, alias))
            marker = 'download-start-dir'
            (short / marker).touch()
            probe = marker if Path('/proc/self/fd').is_dir() else ''
            location = dict(cwd=short, next_cwd=other, fd_marker=probe)
            short.chmod(0o300)  # Search and create, but no directory listing.
            try:
                src.write_bytes(b'A' * 150000)
                download(src, leaf, **location)
                assert (short / leaf).read_bytes() == src.read_bytes() and not (other / leaf).exists()
                (short / 'sub').mkdir()
                (short / 'sub' / 'second').symlink_to('../' + leaf)
                (short / alias).symlink_to('sub/second')
                (other / alias).write_bytes(b'C' * 150000)
                src.write_bytes(b'B' * 150000)
                download(src, alias, headers=True, cache_target=short / leaf, **location)
                assert (short / alias).is_symlink() and (short / leaf).read_bytes() == src.read_bytes()
                assert (other / alias).read_bytes() == b'C' * 150000
                download(work / 'absent', leaf, error=True, defer_quit=True, **location)
                download(src, 'missing/result', error=save_error, **location)
                assert not (other / 'missing/result').exists() and (short / leaf).read_bytes() == src.read_bytes()
                (short / 'dangling').symlink_to('absent')
                download(src, 'dangling', error=save_error, **location)
                assert (short / 'dangling').is_symlink() and not (short / 'absent').exists()
                peer = short / 'peer'
                delayed = work / 'while-missing'
                delayed.write_bytes(b'response')
                download(delayed, peer.name, headers=True, error=save_error, **location)
                assert peer.read_bytes() == b'peer result' and not (other / peer.name).exists()
            finally:
                short.chmod(0o700)
            assert set(os.listdir(short)) == {leaf, alias, marker, 'sub', 'dangling', 'peer'}

            if sys.platform.startswith('linux') and os.geteuid() != 0 and probe:
                # Now even the suffix below the nearest readable directory is too long.
                # Keep using the test driver's short alias; the runner only gets the leaf.
                long_leaf = 'f' * 200
                assert len(os.fsencode((deep / long_leaf).relative_to(work.resolve()))) >= path_max, 'use a shorter TMPDIR for the long-suffix fixture'
                (work / marker).touch()  # also detect the fallback's ancestor fd in the callback
                for directory in components:
                    directory.chmod(0o300)
                try:
                    target = short / long_leaf
                    target.write_bytes(b'ordinary creation')
                    target.unlink()
                    for headers in (False, True):
                        src.write_bytes(b'A' * 150000)
                        download(src, long_leaf, headers=headers, defer_quit=True, **location)
                        assert target.read_bytes() == src.read_bytes() and not (other / long_leaf).exists()
                        (other / long_leaf).write_bytes(b'C' * 150000)
                        src.write_bytes(b'B' * 150000)
                        download(src, long_leaf, headers=headers, cache_target=target, **location)
                        assert target.read_bytes() == src.read_bytes() and (other / long_leaf).read_bytes() == b'C' * 150000
                        src.write_bytes(b'x' * 4096)
                        download(src, long_leaf, headers=headers, limit=True, error=save_error, defer_quit=True, **location)
                        assert target.read_bytes() == b'B' * 150000
                        target.unlink()
                        (other / long_leaf).unlink()

                    peer = target
                    download(delayed, long_leaf, headers=True, error=save_error, defer_quit=True, **location)
                    assert target.read_bytes() == b'peer result' and not (other / long_leaf).exists()
                    target.unlink()
                    target.symlink_to(alias)  # long name -> two existing links -> regular file
                    download(src, long_leaf, **location)
                    assert target.is_symlink() and (short / leaf).read_bytes() == src.read_bytes()
                    target.unlink()

                    # This writable child can itself be opened and pinned at request start.
                    download(src, 'sub/' + long_leaf, **location)
                    assert (short / 'sub' / long_leaf).read_bytes() == src.read_bytes()
                    (short / 'sub' / long_leaf).unlink()

                    spool.chmod(0o300)  # The shortcut need not list even its temp parent.
                    try:
                        download(src, long_leaf, **location)
                        assert target.read_bytes() == src.read_bytes()
                    finally:
                        spool.chmod(0o700)
                    assert not list(spool.iterdir())

                    # A small response needs no HTTP spool. Only the fallback shortcut
                    # needs a writable TMPDIR; the ordinary handle must still work.
                    target.write_bytes(b'original')
                    spool.chmod(0o500)
                    try:
                        download(src, long_leaf, error=save_error if args.no_search_handle else False,
                                 headers=True, defer_quit=True, **location)
                        assert target.read_bytes() == (b'original' if args.no_search_handle else src.read_bytes())
                    finally:
                        spool.chmod(0o700)
                    target.unlink()
                finally:
                    for directory in components:
                        directory.chmod(0o700)
                    (work / marker).unlink()
                assert set(os.listdir(short)) == {leaf, alias, marker, 'sub', 'dangling', 'peer'}
    elif os.name == 'nt' and work.drive.endswith(':'):
        for leaf, spelling in [('drive-relative', work.drive + 'drive-relative'),
                               ('drive-rooted', str(work / 'drive-rooted')[len(work.drive):])]:
            download(src, spelling, next_cwd=other)
            assert (work / leaf).read_bytes() == src.read_bytes() and not (other / leaf).exists()

    for i, data in enumerate([b'', b'\x00\xffA', b'\xff\xfe' + bytes(range(256)) * 4096 + b'!']):
        src.write_bytes(data)
        download(src, dest, headers=bool(i % 2))
        assert dest.read_bytes() == data
    delayed = work / 'while-missing'
    delayed.write_bytes(b'response')
    peer = out / 'peer'
    download(delayed, peer, error=save_error)
    assert peer.read_bytes() == b'peer result'
    peer.unlink()
    (other / 'missing').mkdir()
    download(src, 'missing/result', error=save_error, next_cwd=other)
    assert not (other / 'missing' / 'result').exists()
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
        with tempfile.TemporaryDirectory(dir=out) as nested:
            shared = Path(nested)
            other = next((g for g in os.getgroups() if g != os.getegid()), None)
            if other is not None:
                os.chown(shared, -1, other)
                shared.chmod(0o2700)
                control, created = shared / 'ordinary', shared / 'download'
                control.touch()
                download(src, created)
                assert created.read_bytes() == src.read_bytes() and control.stat().st_gid == created.stat().st_gid == other
            else:
                print('Skipping distinct setgid group case: no supplementary group')

            write_only = shared / 'write-only'
            write_only.write_bytes(b'old')
            write_only.chmod(0o200)
            download(src, write_only)
            assert stat.S_IMODE(write_only.stat().st_mode) == 0o200
            write_only.chmod(0o600)
            assert write_only.read_bytes() == src.read_bytes()
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
        # No privilege is needed for this positive control: updating the same
        # NTFS object retains even security information inaccessible to a caller.
        before = dest.stat()
        src.write_bytes(b'new payload')
        download(src, dest)
        assert dest.read_bytes() == src.read_bytes() and os.path.samestat(before, dest.stat())
        alias = out / 'hardlink'
        os.link(dest, alias)
        src.write_bytes(b'not for the other link')
        download(src, dest, error=save_error)
        assert dest.samefile(alias) and alias.read_bytes() == b'new payload'
        alias.unlink()

        if args.windows_audit:
            audit = ['powershell.exe', '-NoProfile', '-NonInteractive', '-File',
                     str(root / 'tests/http_download_file/test_audit.ps1'), str(dest)]
            expected = subprocess.check_output([*audit, '-Install'], text=True).strip()
            assert expected.startswith('S:')
            download(src, dest)
            assert dest.read_bytes() == src.read_bytes() and subprocess.check_output(audit, text=True).strip() == expected
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
