#!/usr/bin/env python3
"""Offline CLI/MCP contract checks. Never changes the desktop or real user state."""
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

    help_text = run('--help').stdout
    assert '\x1b' not in help_text
    assert run('help').stdout == help_text
    assert run().stdout == help_text
    assert run('live', '--help').stdout == run('apply', '--help').stdout
    for command in ['apply', 'status', 'stop', 'featured', 'search', 'download',
                    'set-static', 'sources', 'cache', 'mcp', 'version']:
        assert 'Usage: deskloop ' + command in run(command, '--help').stdout
        assert run('help', command).stdout == run(command, '--help').stdout
    assert json.loads(run('--version', '--json').stdout)['version']
    assert len(json.loads(run('sources', '--json').stdout)['sources']) == 2
    assert json.loads(run('status', '--json').stdout)['status'] == 'stopped'
    assert json.loads(run('cache', 'list', '--json').stdout)['totalBytes'] == 0
    for args in [('featured', '0'), ('unknown',), ('download', 'id'), ('apply', 'id')]:
        result = run(*args, '--json', code=1)
        assert json.loads(result.stdout)['error']['message']
        assert not result.stderr
    error = run('unknown', code=1)
    assert not error.stdout and 'deskloop:' in error.stderr

    def mcp(messages):
        result = subprocess.run([binary, 'mcp'], env=env,
                                input='\n'.join(json.dumps(x) if not isinstance(x, str) else x for x in messages)+'\n',
                                capture_output=True, text=True, timeout=15)
        assert result.returncode == 0, result
        return [json.loads(line) for line in result.stdout.splitlines()]

    def call(name, arguments):
        return {'jsonrpc': '2.0', 'id': 1, 'method': 'tools/call',
                'params': {'name': name, 'arguments': arguments}}

    discovery = mcp([{'jsonrpc': '2.0', 'id': 1, 'method': 'initialize'},
                     {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
                     {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'}])
    assert discovery[0]['result']['serverInfo']['name'] == 'deskloop'
    tools = {tool['name']: tool for tool in discovery[1]['result']['tools']}
    assert len(tools) == 6
    assert tools['list_featured']['inputSchema']['properties']['limit']['minimum'] == 1
    assert mcp([call('unknown_tool', {})])[0]['result']['isError']
    responses = mcp(['{bad', {'jsonrpc': '2.0', 'id': 2, 'method': 'ping'}])
    assert responses[0]['error']['code'] == -32700
    assert responses[1]['id'] == 2
    catalog = Path(directory, 'cache', 'apple_entries.json')
    catalog.parent.mkdir(exist_ok=True)
    catalog.write_text(json.dumps({'assets': [
        {'id': 'fixture-id', 'accessibilityLabel': 'Fixture Greenland',
         'url-4K-SDR': 'https://example.invalid/fixture.mov'}]}))
    assert json.loads(run('search', 'Greenland', '--json').stdout)[0]['id'] == 'fixture-id'
    assert len(json.loads(run('featured', '1', '--json').stdout)) == 1
    for tool in ['list_featured', 'search_wallpapers']:
        assert not mcp([call(tool, {'query': 'Greenland', 'limit': 1})])[0]['result']['isError']
        for limit in [-1, 0, 101, True, 1.5, '10']:
            response = mcp([call(tool, {'query': 'test', 'limit': limit})])[0]
            assert response['result']['isError'], (tool, limit, response)
    Path(directory, 'live.json').write_text('{corrupt')
    assert mcp([call('get_status', {})])[0]['result']['isError']
    assert json.loads(run('status', '--json', code=1).stdout)['error']
    Path(directory, 'live.json').unlink()

    # Hold the same lease as a running engine. The child must fail before creating windows.
    with open(Path(directory, 'engine.lock'), 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        video = Path(directory, 'fixture.mp4')
        video.touch()
        assert json.loads(run('apply', str(video), '--daemon', '--json', code=1).stdout)['error']
        assert mcp([call('apply_wallpaper', {'target': str(video)})])[0]['result']['isError']

print('CLI/MCP contract checks passed (offline, isolated state, no desktop changes).')
