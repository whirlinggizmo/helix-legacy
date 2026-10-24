"""Checks of helix.tool, what a game on -lib helix builds with (src/helix/tool, run in the compiler and Haxe's interpreter):

- `haxelib run helix` (Run.hx, helix.tool.setup.Commands): its arguments (no command, --help naming the commands, an unknown command or
  option); the caller's directory haxelib appends (HAXELIB_RUN=1); init's files and its refusal of a directory with anything in it; init --example copying an example as a game, refusing one it hasn't; setup making
  sokol-shdc ready and listing the tools, a program HELIX_SHDC names in place of the cache's and its refusal of one that isn't there.
- The starter's hxml files built on `-lib helix` (a haxelib path holding only this checkout as helix): build.web with its page beside it
  (and a page of the game's kept), build.dist (cleaned, the page, assets/, the zip with index.html at its root).
- Build's steps on a game of their own: the page's title, script, config and icon (the game's, or the library's); cleanOutput's removal of
  what an earlier build left and its refusals; packShaders packing a small screen effect (sokol-shdc, fetched when missing) before the
  build, skipping it once current, refusing a broken one, rewriting the asset manifests as tools/gen_manifest.py writes them;
  copyProgram's refusal of a browser build.
- Watchers.watchShaders packing a shader as it changes, and WebServer.serveDirectory serving a directory with its files' types, a 404
  and nothing outside it.

    python3 tests/tools/helix_tools_test.py"""
import argparse
import http.client
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import gen_manifest

argparse.ArgumentParser(description=__doc__).parse_args()

EFFECT = '''@fs fs
@include_block helix_screen
layout(binding=2) uniform params {
    float strength;
};
void main() {
    helix_output(helix_screen_color().rgb * strength, 1.0);
}
@end
'''

# A haxelib path holding only this checkout, as helix (a dev library): what a game's -lib helix finds.
HAXELIB = Path(tempfile.mkdtemp(prefix='helix-haxelib-'))
(HAXELIB / 'helix').mkdir()
(HAXELIB / 'helix/.dev').write_text(str(ROOT), encoding='utf-8')
LIBRARY_ENV = dict(os.environ, HAXELIB_PATH=str(HAXELIB))


def tearDownModule():
    shutil.rmtree(HAXELIB, ignore_errors=True)


def run_hx(*args, cwd=None, env=None):
    """Run.hx run from the checkout as haxelib runs it, the library's src/ on the class path (with HAXELIB_RUN=1, the caller's directory
    last)."""
    return subprocess.run(['haxe', '-cp', 'src', '--run', 'Run', *args], cwd=cwd or ROOT, env=env, capture_output=True, text=True,
                          encoding='utf-8')


def tool(*args, cwd):
    """`haxelib run helix` run in the directory cwd."""
    return run_hx(*args, str(cwd), env=dict(os.environ, HAXELIB_RUN='1'))


def haxe(game, *args):
    """haxe run in the game's directory with args (an hxml, say), on -lib helix."""
    return subprocess.run(['haxe', *args], cwd=game, env=LIBRARY_ENV, capture_output=True, text=True, encoding='utf-8')


def done(result):
    """result's output, once it succeeded."""
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


def refusal(result):
    """result's error, once it was refused (exit 1)."""
    assert result.returncode == 1, (result.returncode, result.stdout, result.stderr)
    return result.stderr


def starter(directory, name='pocket-game'):
    """A starter game written by init into directory/name; its directory."""
    done(tool('init', name, cwd=directory))
    return Path(directory) / name


class Commands(unittest.TestCase):
    def test_arguments(self):
        result = run_hx()
        self.assertEqual(result.returncode, 2)
        self.assertIn('command', result.stderr)
        result = run_hx('--help')
        self.assertEqual(result.returncode, 0, result.stderr)
        for word in ('init', 'setup', 'haxelib run helix', 'helix.tool'):
            self.assertIn(word, result.stdout)
        for gone in ('site', 'shader', 'bogus'):
            result = run_hx(gone)
            self.assertEqual(result.returncode, 2)
            self.assertIn(gone, result.stderr)
        result = run_hx('init', '--bogus')
        self.assertEqual(result.returncode, 2)
        self.assertIn('--bogus', result.stderr)
        for command in ('init', 'setup'):
            result = run_hx(command, '--help')
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_caller_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            # haxelib appends the caller's directory: the command works there, not in the library's.
            done(run_hx('init', 'here', directory, env=dict(os.environ, HAXELIB_RUN='1')))
            self.assertTrue((Path(directory) / 'here/src/Main.hx').is_file())
            self.assertFalse((ROOT / 'here').exists())

    def test_init_refuses_a_directory_in_use(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / 'something.txt').write_text('x', encoding='utf-8')
            self.assertIn('not empty', refusal(tool('init', '.', cwd=directory)))
            (Path(directory) / 'file.txt').write_text('x', encoding='utf-8')
            self.assertIn('not empty', refusal(tool('init', 'file.txt', cwd=directory)))

    def test_init_example(self):
        with tempfile.TemporaryDirectory() as directory:
            # A larger example (its src/), its own assets and autopilot scripts, the starter around it.
            said = done(tool('init', 'rocks', '--example', 'asteroids', cwd=directory))
            self.assertIn('the example asteroids', said)
            game = Path(directory) / 'rocks'
            for path in ('src/Main.hx', 'src/App.hx', 'src/Game.hx', 'hxml/common.hxml', 'assets/audio/sfx/fire.ogg',
                         'assets/fonts', 'assets/CREDITS.md'):
                self.assertTrue((game / path).exists(), path)
            self.assertTrue(any((game / 'assets/autopilot/asteroids').iterdir()))
            self.assertFalse(list(game.rglob('*.py')))
            main = (game / 'src/Main.hx').read_text(encoding='utf-8')
            self.assertIn('new App(options)', main)
            self.assertIn('"rocks"', main)
            # A small example (its App.hx) with shaders and a config; its own Game.hx none, so the starter's isn't written.
            done(tool('init', 'waves', '--example', 'sprite2d', cwd=directory))
            game = Path(directory) / 'waves'
            self.assertTrue((game / 'src/App.hx').is_file() and (game / 'shaders/wave.glsl').is_file())
            self.assertFalse((game / 'src/Game.hx').exists())
            done(tool('init', 'flow', '--example', 'scenes', cwd=directory))
            self.assertTrue((Path(directory) / 'flow/config.json').is_file())
            # An example the library hasn't: refused, the examples listed, nothing written.
            said = refusal(tool('init', 'nothing', '--example', 'nope', cwd=directory))
            self.assertIn('no example nope', said)
            self.assertIn('asteroids', said)
            self.assertFalse((Path(directory) / 'nothing').exists())
            self.assertEqual(run_hx('init', 'x', '--example').returncode, 2)

    def test_setup(self):
        with tempfile.TemporaryDirectory() as directory:
            listed = done(tool('setup', cwd=directory))
            shdc = next(line for line in listed.splitlines() if line.startswith('sokol-shdc'))
            self.assertTrue(Path(shdc.split()[2]).is_file(), listed)
            self.assertIn('cache:', listed)
            self.assertIn('unexpected', run_hx('setup', 'extra', directory, env=dict(os.environ, HAXELIB_RUN='1')).stderr)
            # A program of the user's own, in a cache with nothing in it: listed in place of the pin, nothing fetched.
            cache = Path(directory) / 'cache'
            empty = dict(os.environ, HAXELIB_RUN='1', XDG_CACHE_HOME=str(cache), LOCALAPPDATA=str(cache), HOME=str(cache),
                         USERPROFILE=str(cache))
            mine = Path(directory) / 'my-shdc'
            mine.write_bytes(b'shdc')
            listed = done(run_hx('setup', directory, env=dict(empty, HELIX_SHDC=str(mine))))
            row = next(line for line in listed.splitlines() if line.startswith('sokol-shdc')).split()
            self.assertEqual(row[1], 'HELIX_SHDC')
            # The same file, however the system spells its path (macOS's /var is /private/var; Windows may give a user's short name).
            self.assertTrue(Path(row[2]).samefile(mine), listed)
            self.assertIn('not there yet', listed)
            self.assertFalse((cache / 'helix').exists())
            self.assertIn('HELIX_SHDC names', refusal(run_hx('setup', directory, env=dict(empty, HELIX_SHDC=str(mine) + '-not'))))


class Starter(unittest.TestCase):
    def test_files_and_builds(self):
        with tempfile.TemporaryDirectory() as directory:
            game = starter(directory, 'my-jam-game')
            names = ('build.web', 'build.native', 'build.dist', 'dev', 'serve.dist')
            hxml = ['hxml/common.hxml', 'hxml/web.hxml'] + [f'hxml/{name}.hxml' for name in names]
            for relative in ['src/Main.hx', 'src/Game.hx', *hxml, 'favicon.svg', '.gitignore', '.vscode/settings.json', 'README.md']:
                self.assertTrue((game / relative).is_file(), relative)
            self.assertEqual(json.loads((game / '.vscode/settings.json').read_text(encoding='utf-8')), {'haxe.configurations': [['hxml/build.web.hxml']]})
            self.assertEqual(list((game / 'assets').iterdir()), [])
            self.assertIn('options.product = "my-jam-game"', (game / 'src/Main.hx').read_text(encoding='utf-8'))
            self.assertIn('Window.title = "My Jam Game"', (game / 'src/Game.hx').read_text(encoding='utf-8'))
            self.assertIn('out/my-jam-game-web.zip', (game / 'hxml/build.dist.hxml').read_text(encoding='utf-8'))
            self.assertEqual((game / '.gitignore').read_text(encoding='utf-8'), 'out/\n.haxelib/\n')
            readme = (game / 'README.md').read_text(encoding='utf-8')
            for relative in hxml[2:]:
                self.assertIn(f'haxe {relative}', readme)
            # The browser build, its page beside it, written by the build; one there is the game's, and kept.
            done(haxe(game, 'hxml/build.web.hxml'))
            page = (game / 'out/web/index.html').read_text(encoding='utf-8')
            self.assertIn('<title>my-jam-game</title>', page)
            self.assertIn('<script src="app.js">', page)
            self.assertEqual((game / 'out/web/favicon.svg').read_bytes(), (game / 'favicon.svg').read_bytes())
            (game / 'out/web/index.html').write_text('mine', encoding='utf-8')
            done(haxe(game, 'hxml/build.web.hxml'))
            self.assertEqual((game / 'out/web/index.html').read_text(encoding='utf-8'), 'mine')
            # The distribution: the release build, the page, assets/, zipped with index.html at its root.
            done(haxe(game, 'hxml/build.dist.hxml'))
            self.assertEqual(sorted(p.name for p in (game / 'out/dist').iterdir()), ['app.js', 'assets', 'favicon.svg', 'index.html'])
            names = zipfile.ZipFile(game / 'out/my-jam-game-web.zip').namelist()
            self.assertEqual(sorted(names), ['app.js', 'favicon.svg', 'index.html'])


class Build(unittest.TestCase):
    def test_web_page_and_clean(self):
        with tempfile.TemporaryDirectory() as directory:
            game = starter(directory)
            (game / 'config.json').write_text('{"quality": "high"}', encoding='utf-8')
            (game / 'favicon.svg').write_text('<svg/>', encoding='utf-8')
            (game / 'assets/sub').mkdir()
            (game / 'assets/sub/b.txt').write_text('b', encoding='utf-8')
            (game / 'out/dist/old').mkdir(parents=True)
            (game / 'out/dist/stale.txt').write_text('x', encoding='utf-8')
            done(haxe(game, 'hxml/build.dist.hxml'))
            out = game / 'out/dist'
            page = (out / 'index.html').read_text(encoding='utf-8')
            self.assertIn('<title>pocket-game</title>', page)
            self.assertIn('<meta name="helix-config" content="config.json">', page)
            self.assertIn('<link rel="icon" href="favicon.svg">', page)
            self.assertNotIn('{{', page)
            self.assertEqual((out / 'config.json').read_text(encoding='utf-8'), '{"quality": "high"}')
            self.assertEqual((out / 'favicon.svg').read_text(encoding='utf-8'), '<svg/>')
            self.assertEqual((out / 'assets/sub/b.txt').read_text(encoding='utf-8'), 'b')
            self.assertFalse((out / 'stale.txt').exists())
            self.assertFalse((out / 'old').exists())
            names = zipfile.ZipFile(game / 'out/pocket-game-web.zip').namelist()
            self.assertEqual(sorted(names), ['app.js', 'assets/sub/b.txt', 'config.json', 'favicon.svg', 'index.html'])
            # A script of another name, and a game without its own icon or config: the library's icon, no config.
            (game / 'config.json').unlink()
            (game / 'favicon.svg').unlink()
            done(haxe(game, 'hxml/common.hxml', '-D', 'helix-backend=webgl2', '-js', 'out/other/game.js', '--macro', 'helix.tool.Build.cleanOutput()',
                      '--macro', 'helix.tool.Build.generateWebPage()'))
            page = (game / 'out/other/index.html').read_text(encoding='utf-8')
            self.assertIn('<script src="game.js">', page)
            self.assertNotIn('helix-config', page)
            self.assertEqual((game / 'out/other/favicon.svg').read_bytes(), (ROOT / 'templates/starter/favicon.svg').read_bytes())

    def test_refusals(self):
        with tempfile.TemporaryDirectory() as directory:
            game = starter(directory)
            # cleanOutput on a build written into the game's own directory, or a native build's; copyProgram on a browser build.
            web = ['hxml/common.hxml', '-D', 'helix-backend=webgl2']
            self.assertIn('holds the game itself', refusal(haxe(game, *web, '-js', 'app.js', '--macro', 'helix.tool.Build.cleanOutput()')))
            self.assertTrue((game / 'src/Main.hx').is_file())
            self.assertIn('writes no program', refusal(haxe(game, *web, '-js', 'out/x/app.js', '--macro', 'helix.tool.Build.copyProgram("out/y")')))
            (game / 'out/native').mkdir(parents=True)
            native = ['hxml/common.hxml', '-D', 'helix-backend=sokol-gl', '-cpp', 'out/native', '--no-output']
            self.assertIn('hxcpp', refusal(haxe(game, *native, '--macro', 'helix.tool.Build.cleanOutput()')))

    def test_pack_shaders(self):
        with tempfile.TemporaryDirectory() as directory:
            game = starter(directory)
            (game / 'shaders').mkdir()
            (game / 'shaders/glow.glsl').write_text(EFFECT, encoding='utf-8')
            self.assertIn('glow.glsl -> assets/shaders/glow.hxshader', done(haxe(game, 'hxml/build.web.hxml')))
            packed = game / 'assets/shaders/glow.hxshader'
            self.assertEqual(json.loads(packed.read_text(encoding='utf-8'))['kind'], 'screen')
            self.assertNotIn('sdlGpu', json.loads(packed.read_text(encoding='utf-8')))
            # Current: not packed again.
            self.assertNotIn('glow.glsl', done(haxe(game, 'hxml/build.web.hxml')))
            # A shader the packer refuses: the build ends with the packer's message.
            (game / 'shaders/bad.glsl').write_text(EFFECT.replace('@include_block helix_screen', ''), encoding='utf-8')
            self.assertIn('exactly one framework block', refusal(haxe(game, 'hxml/build.web.hxml')))
            (game / 'shaders/bad.glsl').unlink()
            # Assets carrying manifests: rewritten from their root, as tools/gen_manifest.py writes them (a sibling directory's kept).
            (game / 'assets/sprites').mkdir()
            (game / 'assets/sprites/hero.png').write_bytes(b'\x89PNG')
            gen_manifest.write(game / 'assets')
            time.sleep(1.1)
            (game / 'shaders/glow.glsl').write_text(EFFECT.replace('* strength', '* strength * 2.0'), encoding='utf-8')
            self.assertIn('manifests rewritten under assets', done(haxe(game, 'hxml/build.web.hxml')))
            shaders = (game / 'assets/shaders/manifest.json').read_bytes()
            self.assertIn('glow.hxshader', json.loads(shaders)['files'])
            top = (game / 'assets/manifest.json').read_bytes()
            self.assertEqual(json.loads(top)['dirs']['shaders'], gen_manifest.digest(shaders))
            gen_manifest.write(game / 'assets')
            self.assertEqual((game / 'assets/manifest.json').read_bytes(), top, "the Python writer's bytes")
            self.assertEqual((game / 'assets/shaders/manifest.json').read_bytes(), shaders)


class Running(unittest.TestCase):
    """The tools an hxml of their own runs until stopped."""

    def test_watch_shaders(self):
        with tempfile.TemporaryDirectory() as directory:
            game = starter(directory)
            (game / 'shaders').mkdir()
            (game / 'shaders/glow.glsl').write_text(EFFECT, encoding='utf-8')
            watcher = subprocess.Popen(['haxe', '-lib', 'helix', '--macro', 'helix.tool.Watchers.watchShaders()'], cwd=game, env=LIBRARY_ENV, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True)
            try:
                packed = game / 'assets/shaders/glow.hxshader'
                self.assertTrue(wait(packed.is_file), 'packed at the start')
                first = packed.stat().st_mtime
                time.sleep(1.1)
                (game / 'shaders/glow.glsl').write_text(EFFECT.replace('* strength', '* strength * 2.0'), encoding='utf-8')
                self.assertTrue(wait(lambda: packed.stat().st_mtime > first), 'packed again on a change')
                (game / 'shaders/rim.glsl').write_text(EFFECT, encoding='utf-8')
                self.assertTrue(wait((game / 'assets/shaders/rim.hxshader').is_file), 'a new shader packed')
            finally:
                watcher.kill()
                watcher.communicate()

    def test_web_server(self):
        with tempfile.TemporaryDirectory() as directory:
            site = Path(directory) / 'site'
            (site / 'assets').mkdir(parents=True)
            (site / 'index.html').write_text('<!doctype html>', encoding='utf-8')
            (site / 'favicon.svg').write_text('<svg/>', encoding='utf-8')
            (site / 'assets/a.txt').write_text('a', encoding='utf-8')
            port = 8097

            def get(path):
                try:
                    with urllib.request.urlopen(f'http://localhost:{port}{path}', timeout=3) as answer:
                        return answer.status, answer.headers['Content-Type'], answer.read()
                except urllib.error.HTTPError as error:
                    return error.code, None, b''
                except OSError:
                    return None, None, b''

            def serve():
                return subprocess.Popen(['haxe', '-lib', 'helix', '--macro', f'helix.tool.WebServer.serveDirectory("site", {port})'], cwd=directory,
                                        env=LIBRARY_ENV, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

            server = serve()
            try:
                self.assertTrue(wait(lambda: get('/')[0] == 200), 'serving')
                self.assertEqual(get('/favicon.svg')[:2], (200, 'image/svg+xml'))
                self.assertEqual(get('/')[1], 'text/html; charset=utf-8')
                self.assertEqual(get('/assets/a.txt')[2], b'a')
                self.assertEqual(get('/missing')[0], 404)
                # A path climbing out of the directory, sent as it is: not served.
                connection = http.client.HTTPConnection('localhost', port, timeout=3)
                connection.request('GET', '/../site/index.html')
                self.assertEqual(connection.getresponse().status, 404)
                connection.close()
                # Another program on the port: refused, plainly.
                second = serve()
                self.assertIn('is something else using it', second.communicate(timeout=60)[0])
                self.assertEqual(second.returncode, 1)
            finally:
                server.kill()
                server.communicate()
            # Served again at once, its last connections still closing on the port.
            server = serve()
            try:
                self.assertTrue(wait(lambda: get('/')[0] == 200), 'serving again at once')
            finally:
                server.kill()
                server.communicate()


def wait(ready, seconds=60):
    """Whether ready() came true within seconds."""
    end = time.time() + seconds
    while time.time() < end:
        try:
            if ready():
                return True
        except OSError:
            pass
        time.sleep(0.2)
    return False


if __name__ == '__main__':
    unittest.main()
