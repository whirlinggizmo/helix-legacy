"""The generated Haxe the library ships, in generated/ (committed; docs/DECISIONS.md 138): the framework's programs
(generated/shaders/<Name>Program.hx, from src/helix/graphics/shaders by sokol-shdc and shader_metadata.py), the shader library packed
(generated/shaders/<Name>Packed.hx and PackedShaders.hx, from src/helix/shader by src/helix/tool/shader/ShaderPacker.hx), SDL_GPU's dialects of
both (generated/shaders-sdlgpu, by src/helix/tool/shader/GpuShaders.hx; only sdl3-gpu builds carry them) and the built-in font (generated/fonts/GeneratedFont.hx, by
bake_fonts.py). A build on -lib helix-legacy finds them through src/helix/macro/Haxelib.hx; the repository's own builds list them.

  python3 tools/gen_code.py                 # what's missing or older than its source, SDL_GPU's dialects included
  python3 tools/gen_code.py --regenerate    # all of it anew
  python3 tools/gen_code.py --check         # fails when what's committed differs from what the sources give now (CI, helix.py test)

Every build path (tools/example.py, check_types, the tests) calls generate() first, so an edited shader or font is current by the time it
compiles; the dev loop calls it on every change. Scratch (shdc's reflection and dialect sources, shader-contract.json, the font's atlas) is
in build/generated. Needs sokol-shdc, and for the dialects glslang and SPIRV-Cross, which the Haxe shader tool fetches into the user's cache
(tools/shader_tool.py); a game needs none of them."""
import base64
import filecmp
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zlib

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'generated'
SHADERS_OUT,SDL_GPU_OUT,FONTS_OUT=OUT/'shaders',OUT/'shaders-sdlgpu',OUT/'fonts'
SCRATCH=ROOT/'build/generated/shaders'
SOURCES=ROOT/'src/helix/graphics/shaders'

def run(args):subprocess.run(list(map(str,args)),cwd=ROOT,check=True)

def shader_stamp():
    """The newest change to the framework's shader sources, their manifest, and the tool writing their generated code."""
    return max([p.stat().st_mtime for p in SOURCES.iterdir() if p.suffix in ('.glsl','.json')]+[(ROOT/'tools/shader_metadata.py').stat().st_mtime])

def programs(scratch,out,regenerate=False):
    """The framework's programs: sokol-shdc run on each (into scratch) and their classes written into out, when a source is newer than
    scratch's shader-contract.json (or regenerate)."""
    from shader_metadata import generate,manifest
    scratch.mkdir(parents=True,exist_ok=True);contract=scratch/'shader-contract.json'
    if regenerate or not contract.is_file() or contract.stat().st_mtime<shader_stamp() or not all((out/f'{p}Program.hx').is_file() for p in classes()):
        import shader_tool
        shdc=shader_tool.shdc_path()
        for spec in manifest(SOURCES/'shaders.json'):
            program=spec['program']
            run([shdc,'-i',SOURCES/f'{program}.glsl','-o',scratch/program,'-l','glsl410:glsl300es','-f','bare_yaml','--no-log-cmdline'])
        generate(SOURCES/'shaders.json',scratch,ROOT,out)

def classes():
    """The programs' class names without their Program suffix, from the manifest."""
    from shader_metadata import class_name,manifest
    return [class_name(spec['program']) for spec in manifest(SOURCES/'shaders.json')]

def dialects(scratch,out,regenerate=False):
    """SDL_GPU's dialects of the framework's programs (<Name>SdlGpu.hx in out), from the GLSL 410 programs() left in scratch, when that or
    the translators changed (or regenerate); scratch/sdlgpu-stamp records when."""
    from shader_metadata import generate_sdl_gpu
    import shader_tool
    stamp=scratch/'sdlgpu-stamp';contract=scratch/'shader-contract.json'
    if regenerate or not stamp.is_file() or stamp.stat().st_mtime<max(contract.stat().st_mtime,shader_tool.stamp(),(ROOT/'dependencies.json').stat().st_mtime) or not all((out/f'{p}SdlGpu.hx').is_file() for p in classes()):
        generate_sdl_gpu(SOURCES/'shaders.json',scratch,out);stamp.write_text('',encoding='utf-8', newline='\n')

def generate(sdl_gpu=True,regenerate=False):
    """Everything in generated/ that's missing or older than its source (or regenerate): the shader library packed, the programs, with
    sdl_gpu their SDL_GPU dialects (left alone otherwise, so a build that doesn't need them never fetches the translators), and the font."""
    import bake_fonts,shader_tool
    if regenerate:
        for directory,suffix in ((SHADERS_OUT,'Packed'),(SDL_GPU_OUT,'PackedSdlGpu')):
            for stale in directory.glob(f'*{suffix}.hx'):stale.unlink()
    shader_tool.pack_library(SHADERS_OUT,SDL_GPU_OUT if sdl_gpu else None)
    programs(SCRATCH,SHADERS_OUT,regenerate)
    if sdl_gpu:dialects(SCRATCH,SDL_GPU_OUT,regenerate)
    bake_fonts.generate(regenerate)

def font_parts(text):
    """A GeneratedFont.hx as (its text without the atlas, the atlas's bytes): zlib's output differs between its versions, the atlas doesn't."""
    match=re.search(r'public static final atlas = "([^"]*)";',text)
    if not match:return text,b''
    return text[:match.start(1)]+text[match.end(1):],zlib.decompress(base64.b64decode(match.group(1)))

def check():
    """Generates everything anew into a scratch directory and returns what differs from generated/: stale files, missing ones and extras."""
    import bake_fonts,shader_tool
    from shader_metadata import generate_sdl_gpu
    problems=[]
    with tempfile.TemporaryDirectory(prefix='helix-gen-') as temp:
        fresh=Path(temp)
        shader_tool.pack_library(fresh/'shaders',fresh/'shaders-sdlgpu')
        programs(fresh/'scratch',fresh/'shaders',True)
        generate_sdl_gpu(SOURCES/'shaders.json',fresh/'scratch',fresh/'shaders-sdlgpu')
        bake_fonts.generate(True,fresh/'fonts')
        for directory in ('shaders','shaders-sdlgpu','fonts'):
            made={p.name:p for p in (fresh/directory).glob('*.hx')};have={p.name:p for p in (OUT/directory).glob('*.hx')}
            for name in sorted(made.keys()|have.keys()):
                if name not in have:problems.append(f'generated/{directory}/{name}: missing')
                elif name not in made:problems.append(f'generated/{directory}/{name}: no source makes it')
                elif name=='GeneratedFont.hx':
                    if font_parts(made[name].read_text(encoding='utf-8'))!=font_parts(have[name].read_text(encoding='utf-8')):problems.append(f'generated/{directory}/{name}: stale')
                elif not filecmp.cmp(made[name],have[name],shallow=False):problems.append(f'generated/{directory}/{name}: stale')
    return problems

def main():
    import cli
    p=cli.parser(__doc__)
    p.add_argument('--check',action='store_true',help="write nothing; fail when generated/ isn't what the sources give")
    p.add_argument('--regenerate',action='store_true',help='make everything again, current or not')
    a=p.parse_args()
    if a.check:
        problems=check()
        if problems:sys.exit('\n'.join(problems)+'\ngenerated/ is stale: python3 tools/gen_code.py --regenerate, and commit it')
        print(f'generated/ is current: {sum(1 for _ in OUT.rglob("*.hx"))} files',flush=True);return
    generate(regenerate=a.regenerate)
    print(f'generated/: {sum(1 for _ in OUT.rglob("*.hx"))} files',flush=True)

if __name__=='__main__':main()
