"""Linux: python3 platforms/common/cpp/tests/run_staged_copy_tests.py cpp3|nim

Needs flowc1 and either a CPP3 toolchain or Nim with httpbeast installed.
"""

import os
from pathlib import Path
import resource
import signal
import subprocess
import sys
from tempfile import TemporaryDirectory


def check(exe, work):
    src, dst = work / 'legacy.src', work / 'legacy.dst'

    def run(expected, limit=None):
        def setup():
            os.umask(0o027)
            if limit is not None:
                signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
                resource.setrlimit(resource.RLIMIT_FSIZE, (limit, limit))

        actual = subprocess.run([exe], cwd=work, preexec_fn=setup).returncode
        assert actual == expected, (actual, expected)
        assert set(work.iterdir()) <= {src, dst}, list(work.iterdir())

    large = bytes(range(256)) * 1025 + b'\x00'
    for data in (b'', b'\xff\x01\x00', b'ABC\x00', large):
        src.write_bytes(data)
        run(0)
        assert src.read_bytes() == dst.read_bytes() == data
        assert dst.stat().st_mode & 0o777 == 0o640
        dst.unlink()

    run(1, 32768)
    assert src.read_bytes() == large and not dst.exists()
    os.link(src, dst)
    run(1)
    assert src.samefile(dst) and src.read_bytes() == large
    dst.unlink()

    dst.write_bytes(b'previous result')
    dst.chmod(0o604)
    # Constrain only the child, never the test process. Exercise a small
    # buffered write and a multi-buffer copy in a disposable directory.
    for data, limit in ((b'ABC' * 100, 128), (large, 32768)):
        src.write_bytes(data)
        with dst.open('rb') as previous:
            run(1, limit)
            assert src.read_bytes() == data
            assert os.path.samestat(dst.stat(), os.fstat(previous.fileno()))
            assert previous.read() == dst.read_bytes() == b'previous result'
            assert dst.stat().st_mode & 0o777 == 0o604

    src.unlink()
    run(1)
    assert dst.read_bytes() == b'previous result'
    src.write_bytes(large)
    with dst.open('rb') as previous:
        run(0)
        assert previous.read() == b'previous result'
    assert src.read_bytes() == dst.read_bytes() == large
    assert dst.stat().st_mode & 0o777 == 0o604


def main(backend):
    root = Path(__file__).resolve().parents[4]
    fixtures = Path('platforms/common/cpp/tests/fixtures')
    with TemporaryDirectory() as temp:
        build = Path(temp)
        exe = build / 'copy'
        flowc = root / 'bin/flowc1'
        if backend == 'cpp3':
            subprocess.run([flowc, fixtures / 'legacy_copy.flow', f'cpp3={exe}'], cwd=root, check=True)
        elif backend == 'nim':
            subprocess.run([flowc, fixtures / 'backend_copy.flow', f'nim={exe}.nim', 'nim-build=0'], cwd=root, check=True)
            entry = 'fl0w_platforms_common_cpp_tests_fixtures_backend_copy.nim'
            subprocess.run(['nim', 'c', '--threads:on', '-d:ssl', '-d:release', *sys.argv[2:],
                            f'--out:{exe}', entry], cwd=build / 'nimgen', check=True)
        else:
            raise SystemExit(__doc__)
        work = build / 'files'
        work.mkdir()
        check(exe, work)
        print(f'{backend}: staged copy contracts passed')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else None)
