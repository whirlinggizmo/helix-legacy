"""HeliX's front door for the tests and the services checks. Python owns external tools; HXML owns Haxe settings.

Examples have their own: tools/example.py; a game on -lib helix-legacy its own: hxml files whose build steps are helix.tool macros, and `haxelib run helix-legacy` (Run.hx) for init and setup."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parent
UNIT={'InputTests':[],'BoundsTests':['generated/shaders','generated/fonts'],'ActionsTests':['generated/shaders','generated/fonts'],'AudioBusTests':['generated/shaders','generated/fonts'],'HostTests':[],'ConfigTests':[],'AssetTests':[],'AssetCacheTests':[],'Render2DTests':['generated/shaders','generated/fonts'],'ParticleTests':['generated/shaders','generated/fonts'],'Render3DTests':['generated/shaders','generated/fonts'],'PostProcessTests':['generated/shaders','generated/fonts'],'EnvironmentTests':[],'TrigTests':[],'LogTests':[],'RandomTests':[],'TimeTests':[],'TweenTests':[],'CurveTests':[],'SpriteSheetTests':['generated/shaders','generated/fonts'],'CameraFollowTests':['generated/shaders','generated/fonts'],'SaveTests':['generated/shaders','generated/fonts'],'StageTests':['generated/shaders','generated/fonts'],'ViewTests':['generated/shaders','generated/fonts'],'CollisionTests':['generated/shaders','generated/fonts'],'SceneTests':['generated/shaders','generated/fonts'],'TiledTests':['generated/shaders','generated/fonts'],'BehaviorTests':['generated/shaders','generated/fonts'],'CombatProbeTests':['generated/shaders','generated/fonts'],'SceneFileTests':['generated/shaders','generated/fonts'],'SceneInstanceTests':['generated/shaders','generated/fonts'],'PresentationTests':['generated/shaders','generated/fonts'],'PngTests':[],'ShaderLibraryTests':['generated/shaders','generated/fonts'],'SpriteEffectTests':['generated/shaders','generated/fonts'],'PickTests':['generated/shaders','generated/fonts'],'UiTests':['generated/shaders','generated/fonts'],'AnimationTests':['generated/shaders','generated/fonts'],'OutfitTests':['generated/shaders','generated/fonts','examples/dressing-room/src'],'BlocksTests':['examples/blocks/src'],'SimulationTests':['examples/asteroids/src']}

def run(args,env=None):subprocess.run(list(map(str,args)),cwd=ROOT,env=env,check=True)

def test(native,audio_device):
    """The adapter rule's check, the 2D and 3D names' check (tools/check_names.py), the tools' check (tools/check_tools.py), the generated code's check (tools/gen_code.py --check), the tool tests (shaders and the shader library, gltf2scene, the autopilot's sample comparison, helix.App's build, the game front door), the package smoke test on the interpreter and Node, every unit test, and with native the C service tests and
    native network streaming (tests/streaming, a local server and SDL3's dummy audio driver)."""
    sys.path.insert(0,str(ROOT/'tools'))
    from gen_fixtures import generate
    generate()
    # The generated code (generated/, committed and shipped) must be what the sources give, before anything regenerates it in place.
    run([sys.executable,'tools/gen_code.py','--check'])
    run([sys.executable,'tools/check_adapters.py'])
    run([sys.executable,'tools/check_names.py'])
    run([sys.executable,'tools/check_tools.py'])
    run([sys.executable,'tools/gen_apidoc.py','--check'])
    run([sys.executable,'tools/measure_sizes.py','--check'])
    run([sys.executable,'tools/check_docs.py'])
    for test in ('shaders/shader_metadata_test','shaders/shader_packer_test','tools/gltf2scene_test','tools/autopilot_samples_test','tools/app_test','tools/helix_tools_test'):run([sys.executable,f'tests/{test}.py'])
    run(['haxe','-cp','src','-cp','tests/consumer','-main','PackageSmoke','--interp'])
    (ROOT/'build/tests').mkdir(parents=True,exist_ok=True)
    run(['haxe','-cp','src','-cp','tests/consumer','-main','PackageSmoke','-js','build/tests/package-smoke.js','-dce','full'])
    run(['node','build/tests/package-smoke.js'])
    for main,classpaths in UNIT.items():
        output=subprocess.check_output(['haxe','-cp','src','-cp','tests/unit',*sum((['-cp',c] for c in classpaths),[]),'-main',main,'--interp'],cwd=ROOT,text=True, encoding='utf-8')
        value=json.loads(output[output.index('{'):]);assert value['passed']
        print(f'{main}: {value["checks"]} checks',flush=True)
    trig(native)
    if native and not sys.platform.startswith('linux'):
        print('Native C service tests: skipped here (they feed Linux input_event records and build with cc)',flush=True)
    elif native:
        from native_build import tool
        print(subprocess.check_output([str(tool('native-services-test'))],text=True, encoding='utf-8'),end='')
        print(subprocess.check_output([str(tool('native-sdl3-input-test'))],text=True, encoding='utf-8'),end='')
        if audio_device:print(subprocess.check_output([str(tool('native-audio-probe'))],text=True, encoding='utf-8'),end='')
    if native:run([sys.executable,'tests/streaming/streaming_test.py'])

def trig(native):
    """helix.math.Trig's bits over fixed inputs: the same hash under the interpreter, in JS (Node) and, with native, in hxcpp. When they
    differ, the parts' hashes say where."""
    def lines(args, **kw):return [l for l in subprocess.check_output(args, cwd=ROOT, text=True, encoding='utf-8', **kw).splitlines() if l.startswith('trig ')]
    base = ['-cp', 'src', '-cp', 'tests/trig', '-main', 'TrigBits']
    outputs = {'interpreter': lines(['haxe', *base, '--interp'])}
    run(['haxe', *base, '-js', 'build/tests/trigbits.js', '-dce', 'full', '-D', 'analyzer-optimize'])
    outputs['js'] = lines(['node', 'build/tests/trigbits.js'])
    if native:
        from pins import check_hxcpp
        from native_build import ARCH
        check_hxcpp()
        run(['haxe', *base, '-cpp', 'build/tests/trigbits-cpp', '-dce', 'full', '-D', 'analyzer-optimize', '-D', ARCH],
            env={**os.environ, 'HAXELIB_PATH': str(ROOT / 'build/haxelib')})
        outputs['hxcpp'] = lines([str(ROOT / 'build/tests/trigbits-cpp' / ('TrigBits.exe' if sys.platform == 'win32' else 'TrigBits'))])
    hashes = {target: out[0] for target, out in outputs.items()}
    if len(set(hashes.values())) != 1:
        for parts in zip(*outputs.values()):
            if len(set(parts)) != 1:print('differs: ' + '  '.join(f'{target}: {part}' for target, part in zip(outputs, parts)))
        sys.exit(f'helix.math.Trig differs between targets: {hashes}')
    print(f'Trig bits: the same on {", ".join(hashes)}: {next(iter(hashes.values()))}', flush=True)

def main():
    p=argparse.ArgumentParser(description=__doc__);sub=p.add_subparsers(dest='command',required=True,metavar='command')
    tests=sub.add_parser('test',help='Run the tool, package and unit tests; --native adds the native service tests');tests.add_argument('--native',action='store_true');tests.add_argument('--audio-device',action='store_true')
    services=sub.add_parser('services',help='Check the browser (and optionally native) platform services');services.add_argument('--browser',required=True);services.add_argument('--native',nargs='?',const='release-sokol-gl',metavar='BUILD',help='also natively: release-sokol-gl when not given, or release-sdl3-gl, either in debug (tools/services.py)')
    a=p.parse_args()
    if a.command=='test':
        if a.audio_device and not a.native:p.error('--audio-device requires --native')
        test(a.native,a.audio_device)
    else:run([sys.executable,ROOT/'tools/services.py','--browser',a.browser,*(['--native',a.native] if a.native else [])])

if __name__=='__main__':main()
