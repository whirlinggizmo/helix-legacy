#!/usr/bin/env python3
"""Checks the adapter rule (docs/ARCHITECTURE.md) where it can be checked mechanically:

  1. An adapter (src/helix/adapter/) names no engine code: no rendering, no engine service (the shared Fetch, Storage, ImageDecoding,
     AudioDecoding, InputRouter and job pool among them; their result types are the contracts' and allowed), no generated program
     class, no shared decoder or policy. It implements a platform contract and nothing else.
  2. Engine code (src/helix/ outside adapter/ and profile/) uses no platform API (js.html, js.Browser, js.Syntax, js.lib, sys., cpp.)
     and no target conditional (#if js, cpp, sys, hl). The build macros (src/helix/macro/) run in the compiler, not on a target, and may
     ask the machine building (helix.macro.Haxelib reads its architecture for hxcpp); so do the build tools (src/helix/tool/: Build,
     Watchers and WebServer's macros, the shader packer, haxelib run helix-legacy's commands), run in the compiler or Haxe's interpreter, never in a game.
  3. An adapter's C includes no generated shader header: programs reach adapters as data.
  4. Adapters of the same contract don't copy code: no run of DUPLICATE_LINES or more identical (normalized) lines in two adapters of
     one area. A call into an adapter's own extern bridge (its internal/*Bridge) is its own, as it reaches that adapter's C: two thin
     adapters over shared code in adapter/shared/ (the native hosts over NativeHost) differ in what they call. The same logic written
     differently isn't caught here; review is for that.
  5. Each adapter directory (adapter/<contract>/) is named for its contract: some class in it implements I<Contract>, the directory's
     name being the interface's without the I, lowercased.
  6. Each API directory (adapter/<contract>/<api>/) holds the adapter <Api><Contract>Adapter implementing I<Contract>, words the API's
     name ends with and the contract's starts with written once (webaudio + Audio is WebAudioAdapter, haxehttp + Http HaxeHttpAdapter).
  7. Every type in adapter/ and profile/ but a module's private ones is @:noCompletion: platform code a game never names, so the
     language server doesn't offer it and the API reference leaves it out (dox and tools/gen_apidoc.py skip what's marked).

Known violations, each with what removes it, would be listed in KNOWN (the audit's list, docs/ADAPTER_AUDIT.md, emptied as its steps
landed); one that has gone must be taken off, so the list only shrinks. Exits 1 on any other violation.

    python3 tools/check_adapters.py"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'src/helix'
ADAPTERS = SRC / 'adapter'
DUPLICATE_LINES = 6

# Engine code an adapter must not name.
ENGINE = re.compile(r'\bhelix\.(render2d|render3d|particles|App\b|app\.Ticker|graphics\.(Pipelines|Shader\b|Shaders|ShaderParameters|ScreenEffect|'
                    r'PostProcess|Mipmaps|ImageDecoding(?!\.))|audio\.(AudioResources|AudioPlayback|AudioClip|AudioStream|AudioDecoding(?!\.))|'
                    r'assets\.(AssetService|Assets|FetchService(?!\.)|Fetch|StorageService(?!\.)|Storage)|input\.(InputRouter|InputState|Input)|core\.Jobs|'
                    r'host\.(Runner|Host|Window|Screen)|graphics\.(Graphics|Screenshots|ScreenshotService)|audio\.Audio|debug\.TestHarness|time\.Time)\b|\b[A-Z][A-Za-z0-9]*[0-9]DProgram\b|\bGeneratedShader\b')
PLATFORM = re.compile(r'\bjs\.(html|Browser|Syntax|lib)\b|\bsys\.[a-z]|\bcpp\.[A-Za-z]|#if\s+!?(js|cpp|sys|hl)\b')
# A type's declaration at a line's start (a module's private types begin with private, and are hidden already).
DECLARATION = re.compile(r'^(?:(?:extern|final|abstract|enum)\s+)*(?:class|interface|enum|typedef|abstract)\s+(\w+)')
GENERATED_HEADER = re.compile(r'#include\s+"([^"]*\.glsl\.h|shaders\.h)"')

# Known violations: (rule, file relative to src/helix, the step that removes it).
KNOWN = []


def code_lines(path):
    """The file's lines with comments and string contents blanked, as (number, text)."""
    text = path.read_text(encoding='utf-8')
    text = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), text, flags=re.S)
    out = []
    for number, line in enumerate(text.split('\n'), 1):
        line = re.sub(r'//.*', '', line)
        out.append((number, line))
    return out


def normalized(line):
    """A line as the duplicate check compares it: whitespace collapsed, empty and brace-only lines dropped."""
    s = ' '.join(line.split())
    return '' if s in ('', '{', '}', '};', '});', ')') or s.startswith(('import ', 'package ', '#include ')) else s


def duplicates(files):
    """Runs of DUPLICATE_LINES or more identical normalized lines in two different files: (file a, line a, file b, line b, length)."""
    seqs = {}
    for f in files:
        # A call into the adapter's own bridge (one in its API directory's internal/) is qualified by that adapter, so calls into different
        # C differ; a shared bridge's calls stay as they are.
        api = ADAPTERS / f.relative_to(ADAPTERS).parts[0] / f.relative_to(ADAPTERS).parts[1]
        own = {b.stem for b in (api / 'internal').glob('*Bridge.hx')}
        def qualify(line):
            return re.sub(r'\b(\w+Bridge)\b', lambda m: api.name + '.' + m.group(1) if m.group(1) in own else m.group(1), line)
        seqs[f] = [(n, qualify(normalized(l))) for n, l in code_lines(f) if normalized(l)]
    found = []
    names = sorted(seqs)
    for i, a in enumerate(names):
        index = {}
        for k in range(len(seqs[a]) - DUPLICATE_LINES + 1):
            index.setdefault(tuple(t for _, t in seqs[a][k:k + DUPLICATE_LINES]), k)
        for b in names[i + 1:]:
            k = 0
            while k <= len(seqs[b]) - DUPLICATE_LINES:
                key = tuple(t for _, t in seqs[b][k:k + DUPLICATE_LINES])
                if key in index:
                    found.append((a, seqs[a][index[key]][0], b, seqs[b][k][0]))
                    k += DUPLICATE_LINES
                else:
                    k += 1
    return found


def adapter_name(api, contract):
    """The lowercased class name an adapter for contract (I<Contract>, given without the I) in api/ must have: api, the contract without
    the words api already ends with, then 'adapter'."""
    words = [w.lower() for w in re.findall(r'[A-Z][a-z0-9]*', contract)]
    for k in range(len(words), 0, -1):
        if api.endswith(''.join(words[:k])):
            return api + ''.join(words[k:]) + 'adapter'
    return api + ''.join(words) + 'adapter'


def main():
    import cli
    cli.parser(__doc__).parse_args()
    violations = []
    for path in sorted(ADAPTERS.rglob('*.hx')):
        for number, line in code_lines(path):
            if ENGINE.search(line):
                violations.append(('engine', path, number, line.strip()))
    for path in sorted(ADAPTERS.rglob('*.c')) + sorted(ADAPTERS.rglob('*.h')):
        for number, line in enumerate(path.read_text(encoding='utf-8').split('\n'), 1):
            if GENERATED_HEADER.search(line):
                violations.append(('header', path, number, line.strip()))
    for path in sorted(SRC.rglob('*.hx')):
        if path.is_relative_to(ADAPTERS) or path.is_relative_to(SRC / 'profile') or path.is_relative_to(SRC / 'macro') or path.is_relative_to(SRC / 'tool'):
            continue
        for number, line in code_lines(path):
            if PLATFORM.search(line):
                violations.append(('platform', path, number, line.strip()))
    # Duplicates between adapters of one area (audio, host, ...), in Haxe and in C.
    for area in sorted(p for p in ADAPTERS.iterdir() if p.is_dir() and p.name != 'shared'):
        for suffix in ('*.hx', '*.c'):
            files = sorted(area.rglob(suffix))
            for a, la, b, lb in duplicates(files):
                violations.append(('duplicate', area, la, f'{a.relative_to(SRC)}:{la} repeats in {b.relative_to(SRC)}:{lb}'))
    # Each area is named for a contract one of its classes implements.
    for area in sorted(p for p in ADAPTERS.iterdir() if p.is_dir() and p.name != 'shared'):
        contracts = {m.lower() for f in area.rglob('*.hx') for m in re.findall(r'\bimplements\s+(?:[\w.]+\.)?I(\w+)', f.read_text(encoding='utf-8'))}
        if area.name not in contracts:
            violations.append(('name', area, 0, f'no adapter in {area.name}/ implements I<{area.name}> (it implements {sorted(contracts)})'))
    # Each API directory holds <Api><Contract>Adapter, its overlap written once.
    for area in sorted(p for p in ADAPTERS.iterdir() if p.is_dir() and p.name != 'shared'):
        for api in sorted(p for p in area.iterdir() if p.is_dir() and p.name != 'internal'):
            found = []
            for f in api.glob('*.hx'):
                for name, contract in re.findall(r'\bclass\s+(\w+)[^{]*?\bimplements\s+(?:[\w.]+\.)?I(\w+)', f.read_text(encoding='utf-8')):
                    if contract.lower() == area.name:
                        found.append(name)
                        expected = adapter_name(api.name, contract)
                        if name.lower() != expected:
                            violations.append(('name', f, 0, f'{name} implements I{contract} in {area.name}/{api.name}/: expected {expected} (any case)'))
            if not found and any(api.glob('*.hx')):
                violations.append(('name', api, 0, f'no class in {area.name}/{api.name}/ implements I<{area.name}>'))
    # Platform code is hidden: its types are @:noCompletion, among the metadata lines right above each.
    for path in sorted(ADAPTERS.rglob('*.hx')) + sorted((SRC / 'profile').rglob('*.hx')):
        lines = path.read_text(encoding='utf-8').split('\n')
        for number, line in enumerate(lines, 1):
            found = DECLARATION.match(line)
            if not found:
                continue
            above = number - 2
            metas = []
            while above >= 0 and lines[above].startswith('@'):
                metas.append(lines[above])
                above -= 1
            if not any('@:noCompletion' in m for m in metas):
                violations.append(('hidden', path, number, f'{found.group(1)} is platform code: mark it @:noCompletion on the line above'))
    known = {(rule, SRC / file) for rule, file, _ in KNOWN}
    seen = set()
    failed = False
    for rule, path, number, text in violations:
        key = (rule, path)
        if key in known:
            seen.add(key)
            continue
        failed = True
        print(f'{path.relative_to(ROOT)}:{number}: {rule}: {text}')
    for rule, file, step in KNOWN:
        if (rule, SRC / file) not in seen:
            failed = True
            print(f'{file}: known {rule} violation is gone ({step}): take it off KNOWN in tools/check_adapters.py')
    pending = len(seen)
    print(f'check_adapters: {"FAILED" if failed else "ok"}; {pending} known violation(s) left, each removed by an audit step')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
