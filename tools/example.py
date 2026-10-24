"""Examples: develop one under hotreload-hx, or build it for the browser or natively; `all build BUILD` builds every example (`--group I/N`,
a share of them).

  python3 tools/example.py NAME build|autopilot|dev [BUILD]

A build is named by the rule in docs/CONVENTIONS.md (Build, tools/variants.py): `<platform>-<config>-<backend>`, given here as
`<config>-<backend>` (this machine's platform, js for webgl2) or whole. build builds release-webgl2 when not told; autopilot compares a
native build, release-sokol-gl when not told, against the browser's in the same config; dev serves the browser's, debug-webgl2 when not
told, as its own build with the dev option (`js-debug-webgl2-dev`), in a directory no build writes, so a build or autopilot of the same example
never writes over the page a dev server serves.

An example is examples/<name>/App.hx, or for a larger one examples/<name>/src/App.hx beside its own files. Every example's page is the
library's template (templates/index.html, the one a game copies), and its launcher is shared (examples/shared/launch).
The generated code they compile against (generated/: the framework's programs, the packed shader library, the font) is made current first
(tools/gen_code.py). A build's examples go to its out/ directory: natively
bin/<example>/, the program named for its example, in the browser site/<example>/; beside them one assets directory they share (bin/assets,
site/assets), which each loads as ../assets: the files in examples/assets, and each example's own, which may not claim a path the shared
files or another example has. A larger example adds its autopilot/ scripts (as autopilot/<name>/) and its own assets/ directory (a gen_*.py
there makes what's missing first); the browser's directory carries manifests (tools/gen_manifest.py), which the page's asset cache follows.
An example's shaders/*.glsl are packed (tools/shader_tool.py) into shaders/*.hxshader, and in dev packed again as they change, reloading
in the page. The HXML and hxcpp's work are in build/<build>/.

release builds as the examples ship: full dead-code elimination and the analyzer's optimizations, and in the browser Terser. debug builds
for finding faults: Haxe's -debug (in the browser a source map; natively hxcpp's debug runtime, stack traces with lines and null checks,
and the adapters' C unoptimized with its assertions and sokol's validation on), the standard library's dead-code elimination, no
optimizer.

autopilot builds both and replays each of the example's autopilot scripts on both, with sound off: in a headless browser, and natively in
a window. On Linux the window is on a private display (tools/private_display.py); elsewhere it opens on the desktop, so run it there in a
logged-in session (tools/remote_windows.py --desktop). Both must publish the same final game, and the same samples of the frame (the
autopilot's sample: each point's color within the sample's tolerance per channel, 3 unless the script says, on both). Reports go to
build/results/<name>/."""
import argparse
from contextlib import nullcontext
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import shader_tool
import gen_code
import gen_manifest
from native_build import ARCH
from variants import Build,parse

ROOT=Path(__file__).resolve().parents[1]
SHARED=ROOT/'examples/shared'
# The page every example is served from: the library's template, the one a game copies (BUILDING.md).
TEMPLATE=ROOT/'templates/index.html'

def run(args,env=None):subprocess.run(list(map(str,args)),cwd=ROOT,env=env,check=True)

def source(name):
    """The example's source directory: examples/<name>/src for a larger example, else examples/<name>."""
    return f'examples/{name}/src' if (ROOT/f'examples/{name}/src/App.hx').is_file() else f'examples/{name}'

def hxml(name,build):
    """The example's build arguments for build (a variants.Build), written to build/<build>/<name>.hxml, where the dev server and haxe
    read them."""
    # The generated code's class paths listed, as src/helix/macro/Haxelib.hx lists them for a game on -lib helix: the dev server watches a
    # listed one, so a repacked library shader reloads.
    lines=['-cp src',f'-cp {source(name)}','-cp examples/shared/launch',f'-D helix-backend={build.backend}','-cp generated/shaders','-cp generated/fonts','-main Main',f'-D example={name}']
    # release: what ships; debug: Haxe's debug build (natively hxcpp's, its null checks on), the standard DCE, no optimizer.
    lines+=['-debug']+([] if build.web else ['-D HXCPP_CHECK_POINTER']) if build.debug else ['-dce full','-D analyzer-optimize']
    lines+=[f'-js {page(name,build).relative_to(ROOT).as_posix()}/app.js'] if build.web else [f'-cpp {(build.scratch/name).relative_to(ROOT).as_posix()}',f'-D {ARCH}','-D HXCPP_COMPILE_THREADS=4']
    # SDL_GPU's programs carry its dialects, which other builds leave out.
    if build.backend=='sdl3-gpu':lines+=['-D helix_sdl3_gpu','-cp generated/shaders-sdlgpu']
    path=build.scratch/f'{name}.hxml';path.parent.mkdir(parents=True,exist_ok=True);path.write_text('\n'.join(lines)+'\n', encoding='utf-8')
    return path.relative_to(ROOT)

def tool_modules():
    """The tools/*.py modules this process has loaded, but this one."""
    here=Path(__file__).resolve().parent
    return [m for n,m in list(sys.modules.items()) if n!='__main__' and m is not sys.modules.get(__name__) and getattr(m,'__file__',None)
        and Path(m.__file__).resolve().parent==here]

def tool_stamps():
    """The loaded tools' files' times, and the Haxe shader tool's (tools/shader_tool.py), to tell when one is edited."""
    return {m.__name__:Path(m.__file__).stat().st_mtime for m in tool_modules()}|{'src/helix/tool':shader_tool.stamp()}

def reload_tools():
    """Loads the tools again (twice, so one taking another's names gets the new ones), then this module's names taken from them with
    `from ... import` (shader_metadata's generate and the rest) are bound to the new ones."""
    import importlib
    modules=tool_modules()
    for _ in range(2):
        for module in modules:importlib.reload(module)
    names=globals()
    for name,value in list(names.items()):
        owner=sys.modules.get(getattr(value,'__module__',None) or '')
        if owner in modules and hasattr(owner,name):names[name]=getattr(owner,name)

def page(name,build):
    """The example's directory in build's results: its page in the browser (site/<name>), its program natively (bin/<name>)."""
    return build.programs/name

def prepare(name,build):
    """The generated code made current, and the browser build's directory for the example (page(name,build)): the page from the template,
    and the example's files in the build's shared assets."""
    gen_code.generate(sdl_gpu=False)
    web=page(name,build);web.mkdir(parents=True,exist_ok=True)
    # The example's config.json (DECISIONS 131) beside the page, and the page told it has one; none, and the page makes no request.
    config=ROOT/f'examples/{name}/config.json';meta='<meta name="helix-config" content="config.json">' if config.is_file() else ''
    (web/'index.html').write_text(TEMPLATE.read_text(encoding='utf-8').replace('{{title}}',f'HeliX {name}').replace('{{meta}}',meta),encoding='utf-8')
    if config.is_file():shutil.copyfile(config,web/'config.json')
    elif (web/'config.json').exists():(web/'config.json').unlink()
    shutil.copyfile(ROOT/'templates/starter/favicon.svg',web/'favicon.svg')
    assets(name,build)
    licenses(web)

def assets(name,build):
    """The build's shared assets (bin/assets or site/assets), which its examples share: the shared files, then the example's own (its
    autopilot scripts as autopilot/<name>/, its own assets/ directory (a gen_*.py there first) and its shaders, with SDL_GPU's dialects for
    sdl3-gpu). The example's own files may not claim a path the shared files or another example has."""
    out=build.assets
    shutil.copytree(ROOT/'examples/assets',out,dirs_exist_ok=True)
    pilots=ROOT/f'examples/{name}/autopilot'
    if (out/'autopilot'/name).exists():shutil.rmtree(out/'autopilot'/name)
    if pilots.is_dir():shutil.copytree(pilots,out/'autopilot'/name)
    # The example's own assets (examples/<name>/assets), copied in over the shared ones: a gen_*.py beside them makes what's missing first
    # (Asteroids' sounds are committed, so it makes nothing unless one is gone); the recipes themselves aren't assets.
    own=ROOT/f'examples/{name}/assets'
    if own.is_dir():
        import importlib.util
        for recipe in sorted(own.glob('gen_*.py')):
            spec=importlib.util.spec_from_file_location(f'{name}_{recipe.stem}',recipe);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
            module.generate()
        files=[p for p in own.rglob('*') if p.is_file() and p.suffix!='.py' and '__pycache__' not in p.parts]
        claim(build,name,[p.relative_to(own).as_posix() for p in files])
        for p in files:
            dest=out/p.relative_to(own);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
    pack_shaders(name,build)
    # The browser's manifests (tools/gen_manifest.py), so a returning page re-fetches exactly what changed; native builds read in place.
    if build.web:gen_manifest.write(out)

def copy_changed_assets(name,build,since):
    """The shared assets (examples/assets) and the example's own (examples/<name>/assets, not their recipes) changed since `since` (a
    time), copied into the build's shared assets again, as the dev loop runs: a sheet made again while it runs is the one the page reloads,
    not the one there when it started. Returns the newest file's time."""
    own=ROOT/f'examples/{name}/assets';newest=since
    for root in (ROOT/'examples/assets',own):
        if not root.is_dir():continue
        for source in root.rglob('*'):
            if not source.is_file() or source.suffix=='.py' or '__pycache__' in source.parts:continue
            stamp=source.stat().st_mtime
            if stamp>since:
                dest=build.assets/source.relative_to(root);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
            newest=max(newest,stamp)
    return newest

def claim(build,name,paths):
    """Records that the example owns these paths in the build's shared assets (in build/<build>/assets-claims.json); exits when one is a
    shared file or another example's."""
    record=build.scratch/'assets-claims.json'
    owners=json.loads(record.read_text(encoding='utf-8')) if record.is_file() else {}
    for path in paths:
        if (ROOT/'examples/assets'/path).exists():sys.exit(f'examples/{name}: its {path} is also a shared file (examples/assets/{path})')
        if owners.get(path,name)!=name:sys.exit(f'examples/{name}: its {path} is also examples/{owners[path]}\'s, in their shared assets directory')
        owners[path]=name
    # Written beside and moved into place, so a build or dev loop starting at the same moment never reads it half written (a claim missed
    # by that race is made again the next time that example packs or builds). Windows refuses the move while another reads it: retried.
    record.parent.mkdir(parents=True,exist_ok=True)
    staged=record.with_name(f'{record.name}.{os.getpid()}')
    staged.write_text(json.dumps(owners,indent=1,sort_keys=True)+'\n',encoding='utf-8')
    for attempt in range(50):
        try:os.replace(staged,record);return
        except PermissionError:time.sleep(.02)
    os.replace(staged,record)

def pack_shaders(name,build,since=0):
    """The example's shaders/*.glsl packed into the build's shared assets as shaders/*.hxshader (with SDL_GPU's dialects for sdl3-gpu),
    claimed there: those changed since `since` (a time), all by default. Returns the newest source's time."""
    newest=since;sources=sorted((ROOT/f'examples/{name}/shaders').glob('*.glsl'))
    claim(build,name,[f'shaders/{source.stem}.hxshader' for source in sources])
    changed=[source for source in sources if source.stat().st_mtime>since]
    shader_tool.pack([(source,build.assets/'shaders'/(source.stem+'.hxshader')) for source in changed],build.backend=='sdl3-gpu')
    return max([newest]+[source.stat().st_mtime for source in sources])

def licenses(out):
    """HeliX's license, the third-party notices and the license texts they name, which go with every build (THIRD_PARTY_NOTICES.md)."""
    target=out/'licenses'
    if target.exists():shutil.rmtree(target)
    target.mkdir(parents=True)
    shutil.copyfile(ROOT/'THIRD_PARTY_NOTICES.md',target/'THIRD_PARTY_NOTICES.md')
    for name,source in [('HeliX-MIT.txt','LICENSE'),('sokol-zlib.txt','vendor/LICENSE'),('sokol_utils-zlib.txt','vendor/sokol_utils/LICENSE'),('JetBrainsMono-OFL.txt','vendor/fonts/JetBrainsMono/OFL.txt'),('libsndfile-LGPL-2.1.txt','vendor/sndfile/COPYING')]:
        shutil.copyfile(ROOT/source,target/name)

def program(name,build):
    """The example's program in a native build's results: bin/<name>/<name>, .exe on Windows."""
    return page(name,build)/(name+('.exe' if os.name=='nt' else ''))

def build(name,chosen):
    """Builds the example as chosen (a variants.Build): into its site/<name> in the browser, its bin/<name> natively, hxcpp working
    in build/<build>/<name>."""
    if chosen.web:
        prepare(name,chosen)
        run(['haxe',hxml(name,chosen)])
        terser=ROOT/'build/tools/node_modules/terser/bin/terser';js=page(name,chosen)/'app.js'
        if not chosen.debug and terser.is_file():run(['node',terser,js,'--compress','--mangle','--output',js])
    else:
        from pins import check_hxcpp,check_sokol
        from native_build import env as native_env,place_runtimes
        # SDL_GPU's builds carry the dialects; no other fetches their translators.
        gen_code.generate(sdl_gpu=chosen.backend=='sdl3-gpu')
        check_hxcpp();check_sokol(ROOT)
        sdl3=None
        if chosen.backend.startswith('sdl3'):
            import sdl3 as finder
            sdl3=finder.find();print(f'sdl3: {sdl3.origin}',flush=True)
        run(['haxe',hxml(name,chosen)],native_env(sdl3))
        # hxcpp names the program for the main class (Main, Main-debug in a debug build); the results name it for the example.
        made=chosen.scratch/name/(('Main-debug' if chosen.debug else 'Main')+('.exe' if os.name=='nt' else ''))
        directory=page(name,chosen);directory.mkdir(parents=True,exist_ok=True)
        shutil.copy2(made,program(name,chosen))
        place_runtimes(directory,sdl3)
        config=ROOT/f'examples/{name}/config.json'
        if config.is_file():shutil.copyfile(config,directory/'config.json')
        elif (directory/'config.json').exists():(directory/'config.json').unlink()
        assets(name,chosen)
        licenses(directory)
    print(f'{name}: {page(name,chosen).relative_to(ROOT).as_posix()}',flush=True)

def compare_samples(browser,native,tolerance=3):
    """What differs between the samples the browser and the native run published (the autopilot's snapshot's samples: by name, the points,
    the colors as [r, g, b, a] and the tolerance, tolerance when it gives none): a sample one side lacks, another number of points, or a
    point's channel further apart than its tolerance. Empty when they agree."""
    problems=[]
    for sample in sorted(set(browser)|set(native)):
        if sample not in browser or sample not in native:
            problems.append(f'{sample}: only in the {"browser" if sample in browser else "native run"}');continue
        a,b=browser[sample]['colors'],native[sample]['colors'];allowed=browser[sample].get('tolerance',tolerance)
        if len(a)!=len(b):problems.append(f'{sample}: {len(a)} points in the browser, {len(b)} natively');continue
        for i,(seen,there) in enumerate(zip(a,b)):
            apart=max(abs(x-y) for x,y in zip(seen,there))
            if apart>allowed:problems.append(f'{sample} point {i} {browser[sample]["points"][i]}: browser {seen}, native {there}, {apart} apart (tolerance {allowed})')
    return problems

def autopilot(name,browser,native):
    """Replays every examples/<name>/autopilot script in the browser and natively, under native (a native variants.Build), against the
    browser's build in the same config; returns the scripts whose final games or samples differ or that failed."""
    import functools,http.server,threading
    if sys.platform.startswith('linux'):from private_display import private_display
    scripts=sorted(p.name for p in (ROOT/f'examples/{name}/autopilot').glob('*.json'))
    if not scripts:sys.exit(f'examples/{name}/autopilot has no scripts')
    web=Build('js',native.config,'webgl2')
    for each in (web,native):build(name,each)
    out=ROOT/f'build/results/{name}';out.mkdir(parents=True,exist_ok=True)
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self,*args):pass
    handler=functools.partial(Quiet,directory=str(web.programs))
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),handler);threading.Thread(target=server.serve_forever,daemon=True).start()
    failed=[];executable=program(name,native);label=native.variant
    try:
        with private_display() if sys.platform.startswith('linux') else nullcontext(dict(os.environ)) as env:
            for script in scripts:
                options={'autopilot':f'autopilot/{name}/{script}','autoclose':'1','audio':'0','fast':'1'}
                query='&'.join(f'{k}={v}' for k,v in options.items())
                # The native program's Vulkan driver choice (lavapipe, for SDL_GPU on a private display) isn't Chrome's: there it leaves WebGL2 out.
                browser_env={k:v for k,v in os.environ.items() if k not in ('VK_DRIVER_FILES','VK_ICD_FILENAMES')}
                ran=subprocess.run(['node',ROOT/'tools/autopilot.cjs',browser,f'http://127.0.0.1:{server.server_address[1]}/{name}/?{query}'],cwd=ROOT,env=browser_env,capture_output=True,text=True, encoding='utf-8')
                if ran.returncode:failed.append(script);print(f'{script}: browser run failed\n{ran.stderr}',flush=True);continue
                web=json.loads(ran.stdout)
                result=out/f'{label}-{script}';result.unlink(missing_ok=True)
                # Its saves in a directory of its own, empty, as the browser's run starts with none: a script that saves (settings) doesn't
                # reach the next, nor the user's own saves.
                with tempfile.TemporaryDirectory() as saves:
                    child=dict(env,HELIX_RESULT=str(result),HELIX_SAVES=saves,**{'HELIX_'+k.upper():v for k,v in options.items()})
                    process=subprocess.run([str(executable)],cwd=page(name,native),env=child,capture_output=True,text=True, encoding='utf-8',timeout=300)
                if process.returncode or not result.is_file():
                    reason=json.loads(result.read_text(encoding='utf-8')).get('failed') if result.is_file() else None
                    failed.append(script);print(f'{script}: native run failed'+(f': {reason}' if reason else f'\n{process.stdout}{process.stderr}'),flush=True);continue
                # What the native graphics said it runs on (SDL_GPU's backend), as SDL chooses it.
                for line in process.stderr.splitlines():
                    if line.startswith('HeliX SDL_GPU: '):print(f'{script}: {line}',flush=True)
                published=json.loads(result.read_text(encoding='utf-8'));same=web['result']['game']==published['game'] and not web['errors']
                samples=compare_samples(web['result'].get('autopilot',{}).get('samples',{}),published.get('autopilot',{}).get('samples',{}))
                (out/f'autopilot-{label}-{script}').write_text(json.dumps({'script':script,'sameGame':same,'sampleDifferences':samples,'browserErrors':web['errors'],'browser':web['result'],'native':published},indent=2)+'\n', encoding='utf-8')
                ran=web.get('renderer')+(f', after the GPU gave none: {web["fallback"]}' if web.get('fallback') else '')
                print(f'{script}: same final game in the browser and {label}: {same} (the browser on {ran})',flush=True)
                count=len(web['result'].get('autopilot',{}).get('samples',{}))
                if count:print(f'{script}: {count} samples alike within their tolerances: {not samples}'+''.join(f'\n  {problem}' for problem in samples),flush=True)
                if not same or samples:failed.append(script)
    finally:server.shutdown()
    return failed

def main():
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter);p.add_argument('name');p.add_argument('action',choices=['dev','build','autopilot'])
    p.add_argument('build',nargs='?',help='<config>-<backend> or a whole build name (docs/CONVENTIONS.md, Build): release-webgl2 to build, release-sokol-gl to autopilot, debug-webgl2 for dev when not given')
    p.add_argument('--port',type=int,default=8060);p.add_argument('--browser',help='Chromium for autopilot')
    p.add_argument('--group',help='with all: build only group I of N (I/N, from 1), every Nth example in name order, so N runners share them');a=p.parse_args()
    default={'build':'release-webgl2','autopilot':'release-sokol-gl','dev':'debug-webgl2'}[a.action]
    try:chosen=parse(a.build or default,('dev',) if a.action=='dev' else ())
    except ValueError as error:p.error(str(error))
    if a.action=='dev':
        if not chosen.web:p.error('dev serves the browser\'s build: <config>-webgl2')
        chosen=Build(chosen.platform,chosen.config,chosen.backend,('dev',))
    if a.action=='autopilot' and chosen.web:p.error('autopilot compares a native build with the browser\'s: <config>-sokol-gl, -sdl3-gl or -sdl3-gpu')
    if a.name=='all':
        if a.action!='build':p.error('all only builds')
        names=sorted(d.name for d in (ROOT/'examples').iterdir() if (ROOT/source(d.name)/'App.hx').is_file())
        if a.group:
            index,count=map(int,a.group.split('/'))
            if not 1<=index<=count:p.error('--group is I/N with 1 <= I <= N')
            names=names[index-1::count]
        failed=[]
        for name in names:
            try:build(name,chosen)
            except subprocess.CalledProcessError:failed.append(name)
        print(f'built {len(names)-len(failed)} of {len(names)} examples as {chosen}',flush=True)
        if failed:sys.exit('Failed: '+', '.join(failed))
        return
    if not (ROOT/source(a.name)/'App.hx').is_file():sys.exit(f'No examples/{a.name}/App.hx or examples/{a.name}/src/App.hx')
    if a.action=='autopilot':
        if not a.browser:p.error('autopilot needs --browser')
        failed=autopilot(a.name,a.browser,chosen)
        if failed:sys.exit('Autopilot outcomes or samples differ: '+', '.join(failed)+f'; see build/results/{a.name}')
        return
    if a.action=='dev':
        prepare(a.name,chosen)
        # The edit loop: hotreload-hx rebuilds on save and swaps code and served files into the running page.
        # The dev server watches Haxe source; shader source is regenerated here, and the new program classes (Sprite2DProgram.hx and the rest) reload like any Haxe edit.
        # The page loads ../assets/, which from the served root is /assets/: the dev build's shared assets, mounted there.
        served=chosen.assets.relative_to(ROOT).as_posix()
        server=subprocess.Popen(['haxe','-lib','hotreload-hx','--run','hotreload.DevServer','--port',str(a.port),'--mount',f'/assets={served}',hxml(a.name,chosen)],cwd=ROOT)
        print(f'{chosen}: {page(a.name,chosen).relative_to(ROOT).as_posix()}. Open http://localhost:{a.port}/ and edit; Ctrl+C stops.',flush=True)
        try:
            failed=None;library_seen=None;packed=time.time();copied=time.time()
            tools=tool_stamps()
            while server.poll() is None:
                # A tool this loop uses edited (the packer, the shader generator, the font baker, ...): every one loaded again, and every
                # shader packed and generated again with them.
                if tool_stamps()!=tools:
                    tools=tool_stamps()
                    try:reload_tools();packed=0;library_seen=None;failed=None
                    except Exception as error:print('example: a tool failed to load again, the rest kept as they were:',error,flush=True)
                # The assets, copied again as they change (a generated sheet made again, an image saved), with their manifest; the page
                # reloads what it loaded of them.
                recopied=copy_changed_assets(a.name,chosen,copied)
                if recopied!=copied:gen_manifest.write(chosen.assets);copied=recopied
                # The example's shaders, packed again as they change; the page reloads the asset.
                try:
                    repacked=pack_shaders(a.name,chosen,packed)
                    # A repacked shader changes its manifest, or the next page load would refuse it.
                    if repacked!=packed:gen_manifest.write(chosen.assets)
                    packed=repacked
                except SystemExit as error:print('example: shader packing failed:',error,flush=True);packed=time.time()
                # The shader library's sources, packed into generated Haxe again as they change (generated/shaders, which the dev server
                # watches): it rebuilds, and the reload builds the changed ones again in place (helix.shader.ShaderLibrary). The packer
                # runs when a source or the packer changed since it last ran; a failed source is retried once it changes again.
                library=max([p.stat().st_mtime for p in (ROOT/'src/helix/shader').glob('*.glsl')]+[shader_tool.stamp()])
                if library!=library_seen:
                    library_seen=library
                    try:shader_tool.pack_library(gen_code.SHADERS_OUT)
                    except SystemExit as error:print('example: library shader packing failed:',error,flush=True)
                # The framework's programs likewise; a failed source is retried only once it changes again.
                stamp=gen_code.shader_stamp()
                if stamp!=failed:
                    try:gen_code.programs(gen_code.SCRATCH,gen_code.SHADERS_OUT);failed=None
                    except (subprocess.CalledProcessError,RuntimeError) as error:print('example: shader generation failed:',error,flush=True);failed=stamp
                time.sleep(.25)
        except KeyboardInterrupt:pass
        finally:
            try:urllib.request.urlopen(f'http://127.0.0.1:{a.port}/__hotreload_stop',timeout=5).read();server.wait(timeout=10)
            except Exception:server.terminate()
        return
    build(a.name,chosen)

if __name__=='__main__':main()
