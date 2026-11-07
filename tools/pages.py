"""The examples' site, for GitHub Pages: every example built as js-release-webgl2 (tools/example.py), into out/js/release-webgl2/site, a
thumbnail of each taken in a headless browser (tools/pages_shots.cjs), and the site's index.html, the examples as tiles in groups, each its
thumbnail, name and what it shows (from docs/EXAMPLES.md), with its size: its code (app.js), as sent (gzipped, as Pages serves it), and the
assets it loaded before its thumbnail, which the browser caches. Each example's page gains a bar: the index, the previous and next example,
and its source. out/js/release-webgl2/site is then the site as it's served, the examples sharing its assets/, and the API reference at api/.

  python3 tools/pages.py --browser /path/to/chromium [--no-build]"""
import argparse
import functools
import gzip
import html
import json
import shutil
import http.server
import re
import subprocess
import sys
import threading
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import example
from variants import Build

# The build the site is: the browser's release build, its site/ directory.
BUILD=Build('js','release','webgl2')
SITE=BUILD.programs

# The index's groups, in order; every example is in one, so a new example must be placed.
GROUPS=[
    ('Games',['asteroids','blocks']),
    ('3D',['hello3d','meshes','follow3d','materials','lights','environment','shadows','model','animation','instancing','pick','scene3d','sprite3d','text3d',
           'particles','shaders','postprocess','shader-gallery','render-target','dressing-room','scene-file']),
    ('2D',['app-hello','stage','views','sprite2d','stage2d','motion','tilemap','tiled','sprite-sheet','platformer','font','textures','ui']),
    ('App and services',['app-skeleton','app-tick','app-window','app-gamepad','app-touch','touch-stick','scenes','transitions','audio-music','asset-fetch','asset-force-fetch','quit']),
]
# The most milliseconds an example's capture waits for it to settle (tools/pages_shots.cjs captures once nothing has loaded for a moment):
# longer where it prepares more (environment's lighting bake takes most of a minute on CI's software renderer, SwiftShader).
WAIT=30000
WAITS={'environment':120000,'scene-file':120000}
SOURCE='https://github.com/whirlinggizmo/helix-legacy/tree/main/examples/'

def names():
    """Every example, by name."""
    return sorted(d.name for d in (ROOT/'examples').iterdir() if (ROOT/example.source(d.name)/'App.hx').is_file())

def descriptions():
    """What each example shows, from docs/EXAMPLES.md: the catalog's table, and the larger examples' list."""
    text=(ROOT/'docs/EXAMPLES.md').read_text(encoding='utf-8');shows={}
    for name,description in re.findall(r'^\| `([a-z0-9-]+)` \| (.+?) \|$',text,re.M):shows[name]=description
    for title,name,description in re.findall(r'^- \*\*(\w+)\*\* \(`examples/([a-z0-9-]+)`\): (.+)$',text,re.M):shows[name]=description
    return shows

def inline(markdown):
    """A description's Markdown as HTML: escaped, its `code` spans kept."""
    return re.sub(r'`([^`]+)`',r'<code>\1</code>',html.escape(markdown,quote=False))

def plain(markdown):
    """A description as plain text, for the filter and a tile's tooltip."""
    return markdown.replace('`','')

def order():
    """The examples in the index's order; exits when one is in no group, or a group names one that isn't an example."""
    grouped=[name for _,members in GROUPS for name in members];known=set(names())
    if set(grouped)!=known or len(grouped)!=len(known):
        sys.exit(f'pages: GROUPS must hold every example once: missing {sorted(known-set(grouped))}, unknown {sorted(set(grouped)-known)}')
    return grouped

def size(count):
    """A byte count for people: KB under a megabyte, else MB."""
    return f'{count/1024:.0f} KB' if count<1024*1024 else f'{count/1024/1024:.1f} MB'

def sizes(requested):
    """Each example's code (app.js, minified, then gzipped as Pages sends it) and the assets it requested, in bytes, from the files served."""
    web=SITE;out={}
    for name,paths in requested.items():
        script=(web/name/'app.js').read_bytes()
        assets=sum((web/p.lstrip('/')).stat().st_size for p in set(paths) if p.startswith('/assets/') and (web/p.lstrip('/')).is_file())
        out[name]=(len(script),len(gzip.compress(script,6)),assets)
    return out

def index(shows,commit,weights):
    """The site's index.html: a section a group, a tile an example."""
    sections=[]
    for title,members in GROUPS:
        tiles=[]
        for name in members:
            description=shows.get(name)
            if description is None:sys.exit(f'pages: docs/EXAMPLES.md says nothing of {name}')
            tiles.append(f'<li data-text="{html.escape((name+" "+plain(description)).lower())}"><a class="tile" href="{name}/" title="{html.escape(plain(description))}">'
                         f'<figure><img src="thumbnails/{name}.webp" width="640" height="360" alt="{name}" loading="lazy">'
                         f'<figcaption><span class="name">{name}</span>{weight(*weights[name])}<span class="shows">{inline(description)}</span></figcaption></figure></a></li>')
        sections.append(f'<section><h2>{html.escape(title)}</h2>\n<ul class="grid">\n'+'\n'.join(tiles)+'\n</ul></section>')
    page=(ROOT/'examples/shared/pages/index.html').read_text(encoding='utf-8')
    page=page.replace('{{sections}}','\n'.join(sections)).replace('{{count}}',str(len(order()))).replace('{{commit}}',commit).replace('{{short}}',commit[:7])
    (SITE/'index.html').write_text(page,encoding='utf-8')

def weight(code,sent,assets):
    """A tile's size: the code, with what's sent of it (gzipped) in parentheses, then the assets it loads, which the browser keeps."""
    more=f' + {size(assets)} assets <span class="sent">(cached)</span>' if assets else ''
    return (f'<span class="size" title="The code, minified; as sent, gzipped; and the assets it loads, kept in the browser once loaded">'
            f'{size(code)} <span class="sent">({size(sent)} gzipped)</span>{more}</span>')

def bar(name,previous,following):
    """The bar on an example's page: the index, the previous and next example, and its source; small, in a corner, over the canvas."""
    style=('#helix-pages{position:fixed;right:10px;bottom:10px;display:flex;gap:2px;font:13px/1 system-ui,sans-serif;z-index:10;'
           'background:rgba(20,28,48,.78);border-radius:8px;padding:3px;backdrop-filter:blur(4px)}'
           '#helix-pages a{color:#e6ebf5;text-decoration:none;padding:7px 10px;border-radius:6px}'
           '#helix-pages a:hover,#helix-pages a:focus-visible{background:rgba(255,255,255,.14)}')
    links=[('../','All examples','☰ All'),(f'../{previous}/',f'Previous: {previous}','‹'),(f'../{following}/',f'Next: {following}','›'),
           (SOURCE+name,f'The source of {name} on GitHub','Source')]
    return (f'<style>{style}</style><nav id="helix-pages" aria-label="Examples">'
            +''.join(f'<a href="{href}" title="{html.escape(label)}" aria-label="{html.escape(label)}">{text}</a>' for href,label,text in links)+'</nav>')

def shots(browser,all_names):
    """The thumbnails, thumbnails/<name>.webp in the site, from the site served locally; returns what each example requested (its paths)."""
    out=SITE/'thumbnails';out.mkdir(parents=True,exist_ok=True)
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self,*args):pass
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Quiet,directory=str(SITE)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    requests=BUILD.scratch/'pages-requests.json';requests.parent.mkdir(parents=True,exist_ok=True)
    try:subprocess.run(['node',str(ROOT/'tools/pages_shots.cjs'),browser,f'http://127.0.0.1:{server.server_address[1]}',str(out),str(requests)]
                       +[f'{name}={WAITS.get(name,WAIT)}' for name in all_names],cwd=ROOT,check=True)
    finally:server.shutdown()
    return json.loads(requests.read_text(encoding='utf-8'))

def main():
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--browser',required=True,help='Chromium, for the thumbnails');p.add_argument('--no-build',action='store_true',help='use the examples already built')
    a=p.parse_args()
    ordered=order();shows=descriptions()
    if not a.no_build:
        for name in ordered:example.build(name,BUILD)
    for i,name in enumerate(ordered):
        page=SITE/name/'index.html';text=page.read_text(encoding='utf-8')
        text=re.sub(r'<style>#helix-pages.*?</nav>','',text,flags=re.S)
        page.write_text(text.replace('<script src="app.js">',bar(name,ordered[i-1],ordered[(i+1)%len(ordered)])+'<script src="app.js">'),encoding='utf-8')
    (SITE/'favicon.png').write_bytes((example.SHARED/'favicon.png').read_bytes())
    # The API reference beside the examples, at /api/ (tools/gen_apidoc.py, from the doc comments).
    import gen_apidoc
    gen_apidoc.generate()
    if (SITE/'api').exists():shutil.rmtree(SITE/'api')
    shutil.copytree(ROOT/'build/api',SITE/'api',ignore=shutil.ignore_patterns('xml','unused*'))
    weights=sizes(shots(a.browser,ordered))
    commit=subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
    index(shows,commit,weights)
    print(f'pages: {SITE.relative_to(ROOT).as_posix()} holds the site, {len(ordered)} examples',flush=True)

if __name__=='__main__':main()
