#!/usr/bin/env python3
"""Offline CLI contract checks. Never changes the desktop or real user state."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary = str(Path(sys.argv[1] if len(sys.argv) > 1 else '.build/release/deskloop').resolve())

with tempfile.TemporaryDirectory(prefix='deskloop-verify-') as directory:
    env = dict(os.environ, DESKLOOP_HOME=directory)

    def run(*args, code=0):
        result = subprocess.run([binary, *args], env=env, capture_output=True, text=True, timeout=15)
        assert result.returncode == code, (args, result)
        return result

    # 1. Help verification
    help_text = run('--help').stdout
    assert '\x1b' not in help_text
    assert run('help').stdout == help_text
    assert run('-h').stdout == help_text
    assert run().stdout == help_text
    assert 'Usage: deskloop run' in run('run', '--help').stdout
    assert 'Usage: deskloop run' in run('apply', '--help').stdout
    assert 'Usage: deskloop status' in run('status', '--help').stdout
    assert 'Usage: deskloop stop' in run('stop', '--help').stdout
    assert 'Usage: deskloop version' in run('version', '--help').stdout

    # 2. Version verification
    version_data = json.loads(run('--version', '--json').stdout)
    assert version_data['name'] == 'deskloop'
    assert version_data['version']
    assert run('version').stdout.strip().startswith('deskloop version')

    # 3. Status when stopped
    status_data = json.loads(run('status', '--json').stdout)
    assert status_data['status'] == 'stopped'
    assert 'Stopped' in run('status').stdout

    # 4. Stop when already stopped (successful no-op)
    stop_data = json.loads(run('stop', '--json').stdout)
    assert stop_data['success'] is False
    assert 'No running live wallpaper engine recorded' in stop_data['message']

    # 5. Missing / invalid video file validation
    nonexistent = str(Path(directory, 'nonexistent.mp4'))
    json_err = json.loads(run('run', nonexistent, '--daemon', '--json', code=1).stdout)
    assert 'Video file not found' in json_err['error']['message']

    # Plain text error to stderr
    plain_err = run('run', nonexistent, code=1)
    assert not plain_err.stdout
    assert 'Video file not found' in plain_err.stderr

    # Unsupported format
    text_file = str(Path(directory, 'file.txt'))
    Path(text_file).touch()
    fmt_err = json.loads(run('run', text_file, '--daemon', '--json', code=1).stdout)
    assert 'Unsupported video format' in fmt_err['error']['message']

    # 6. Unknown command handling
    unknown_err = run('unknown_subcommand', code=1)
    assert 'Unknown command' in unknown_err.stderr

    # 7. Engine lock test (simulates already running engine)
    with open(Path(directory, 'engine.lock'), 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        video = Path(directory, 'test.mp4')
        video.touch()
        lock_err = json.loads(run('run', str(video), '--daemon', '--json', code=1).stdout)
        assert 'already running' in lock_err['error']['message']

print('All CLI contract checks passed (offline, isolated state, no desktop changes).')
