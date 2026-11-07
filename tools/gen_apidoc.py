"""Generate HeliX's API reference from its doc comments: as HTML with dox (pinned in dependencies.json) into build/api,
published on the examples' site at /api/; and as Markdown in docs/api, committed, so the repository carries a readable
reference without the site (README.md, the index of packages, then a file a package with each type's public members).

The reference is what a game writes against: a type or member marked @:noCompletion is the engine's own (the adapters and
profiles, checked by tools/check_adapters.py, and the services behind the static classes), hidden from the language server
and left out here as dox leaves it out. Haxe describes the code once per target (XML), js and cpp; engine code has no target
conditional, so both must describe the same types with the same public members, and the tool fails when they differ. The HTML is then made from one of them, so dox has nothing to mark as one target's. --check regenerates
the Markdown in memory and fails when docs/api differs, so a change to a doc comment is committed with its reference
(helix.py test runs it)."""
import json
import re
import os
from pathlib import Path
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/api'
DOCS=ROOT/'docs/api'
# The platform code: each target's adapters compile on it alone, so neither description includes them (they're @:noCompletion anyway).
PLATFORM=('helix.adapter','helix.profile')
# What the reference says of its targets, once.
TARGETS='Every type here is on both of HeliX\'s Haxe targets, js (the browser) and cpp (native); the engine\'s own types beneath them (@:noCompletion: the adapters, profiles and services behind the static classes), which a game never names, are left out.'

def describe(target):
    """Haxe's XML description of package helix for one target, the platform code left out."""
    output=OUT/'xml'/f'{target}.xml';output.parent.mkdir(parents=True,exist_ok=True)
    # The tools' internals run in the compiler or Haxe's interpreter, not on a target: Build, Watchers and WebServer are their face.
    ignore=[p+'*' for p in PLATFORM]+['helix.tool.setup','helix.tool.shader','helix.tool.shared']
    macro="include('helix',true,["+",".join(f"'{p}'" for p in ignore)+"])"
    args=['haxe','-cp','src','-cp','generated/shaders','-cp','generated/fonts','--macro',macro,'-xml',str(output),'-D','doc-gen','--no-output']
    args+=['-js',str(OUT/'unused.js')] if target=='js' else ['-cpp',str(OUT/'unused-cpp')]
    subprocess.run(args,cwd=ROOT,check=True)

def hidden(node):
    """Whether a type or member is marked @:noCompletion, the engine's own."""
    meta=node.find('meta')
    return meta is not None and any(m.get('n')==':noCompletion' for m in meta)

def public_types(file):
    """A target's XML description's documented types: helix's public ones not hidden, {path: node} (a module's private types have a
    path through the module, helix.asset._AssetService.Attempt)."""
    return {n.get('path'):n for n in ET.parse(file).getroot()
        if (n.get('path') or '').startswith('helix.') and '._' not in n.get('path') and n.get('private')!='1' and not hidden(n)}

def hidden_paths(file):
    """The paths of a description's hidden types: helix's marked @:noCompletion."""
    return {n.get('path') for n in ET.parse(file).getroot() if (n.get('path') or '').startswith('helix.') and hidden(n)}

def leaks(file):
    """Each shown member whose signature names a hidden type, 'Type.member: Hidden', so the reference never points at what it leaves
    out: such a member is the engine's too (hide it, or make it private), or the type isn't. An optional argument may: a game leaves it out."""
    secret=hidden_paths(file);found=[]
    def named(node):
        for e in node.iter():
            if e.get('path') in secret:yield e.get('path')
    def signature(member):
        """What a game meets of a member: its type, but for a method's optional arguments (left out, as a GPU or backend for tests)."""
        kids=[c for c in member if c.tag not in ('haxe_doc','meta')]
        if not kids:return []
        t=kids[0]
        if member.get('set')!='method' or t.tag!='f':return [t]
        names=t.get('a','').split(':') if t.get('a') else [];parts=list(t)
        return [k for n,k in zip(names,parts[:-1]) if not n.startswith('?')]+parts[-1:]
    for path,node in sorted(public_types(file).items()):
        for member in node:
            if member.tag in ('haxe_doc','meta') or member.get('public')!='1' or hidden(member):continue
            for name in sorted({n for part in signature(member) for n in named(part)}):found.append(f'{path}.{member.tag}: {name}')
    return found

def same_on_both(js,cpp):
    """Fails unless both targets describe the same documented types, each with the same public members as written."""
    a=public_types(js);b=public_types(cpp)
    differ=[f'{p}: only on {"js" if p in a else "cpp"}' for p in sorted(set(a)^set(b))]
    for path in sorted(set(a)&set(b)):
        known=set(a)
        ma={m[:2] for m in (member_lines(c,known) for c in a[path]) if m};mb={m[:2] for m in (member_lines(c,known) for c in b[path]) if m}
        differ+=[f'{path}: {sig} only on {"js" if (sig,d) in ma else "cpp"}' for sig,d in sorted(ma^mb)]
    if differ:
        sys.exit('gen_apidoc: js and cpp describe the API differently (engine code has no target conditional):\n  '+'\n  '.join(differ))

def short(path):
    """A type's name without its package."""
    return path.rsplit('.',1)[-1]

def package_file(path):
    """The Markdown file a package's types go in: the package's name after helix."""
    package=path.rsplit('.',1)[0]
    return package[len('helix.'):].replace('.','-')+'.md' if package!='helix' else 'helix.md'

def type_text(node,known):
    """A type as Haxe writes it, from the XML's type element, helix's own types by their short names (the index finds them)."""
    tag=node.tag
    if tag in ('c','x','t','e'):
        path=node.get('path');params=[type_text(c,known) for c in node]
        # A method's type parameter comes as '<method>.T': written as Haxe writes it, T.
        head,_,last=path.rpartition('.')
        method=head and '.' not in head and head[:1].islower() and head not in ('haxe','sys','js','cpp','eval','hl','helix')
        name=last if method else short(path) if path.startswith('helix.') else path
        return name+(f'<{", ".join(params)}>' if params else '')
    if tag=='d':return 'Dynamic'
    if tag=='f':
        names=node.get('a','').split(':') if node.get('a') else []
        kids=list(node);ret=type_text(kids[-1],known) if kids else 'Void'
        args=[(f'{n}:' if n else '')+type_text(k,known) for n,k in zip(names,kids[:-1])] if names and names!=[''] else [type_text(k,known) for k in kids[:-1]]
        return '('+', '.join(args)+') -> '+ret if len(args)!=1 or ':' in (args[0] if args else '') else f'{args[0]} -> {ret}'
    if tag=='a':
        return '{'+', '.join(f'{c.tag}:{type_text(list(c)[0],known)}' for c in node if len(c))+'}'
    return node.tag

TAG=re.compile(r'^\s*@(param|return|returns|throws|exception|see|since|deprecated)\s+(.*)$')

def doc_parts(node):
    """A doc comment as (summary, remarks, tags): the first paragraph, the paragraphs after it (fenced code kept as written, prose
    joined), and the Javadoc-style tags at the end, each (name, value, text); value is the parameter's name for param and throws."""
    d=node.find('haxe_doc')
    if d is None or not (d.text or '').strip():return '','',[]
    lines=[l.strip() for l in d.text.strip().split('\n')]
    tags=[];body=[]
    for line in lines:
        m=TAG.match(line)
        if m:
            name,text=m.groups();value=None
            if name in ('param','throws','exception'):
                value,_,text=text.partition(' ');text=text.strip()
            tags.append((name,value,text))
        elif tags and line:tags[-1]=(tags[-1][0],tags[-1][1],tags[-1][2]+' '+line)
        else:body.append(line)
    # Paragraphs: blank lines apart; a fenced block is one paragraph, its lines kept.
    paragraphs=[];fence=False
    for line in body:
        if line.startswith('```'):
            fence=not fence
            if fence:paragraphs.append([line])
            else:paragraphs[-1].append(line)
        elif fence:paragraphs[-1].append(line)
        elif not line:
            if paragraphs and paragraphs[-1]:paragraphs.append([])
        else:
            if not paragraphs:paragraphs.append([])
            paragraphs[-1].append(line)
    paragraphs=['\n'.join(p) if p and p[0].startswith('```') else ' '.join(p) for p in paragraphs if p]
    return (paragraphs[0] if paragraphs else ''),'\n\n'.join(paragraphs[1:]),tags

def doc_text(node):
    """A doc comment's summary, one paragraph."""
    return doc_parts(node)[0]

def tag_lines(tags):
    """The tags as Markdown list items: a parameter by name, the return as 'returns'."""
    return [f'- `{v}`: {t}' if n in ('param','throws','exception') else f'- {"returns" if n in ("return","returns") else n}: {t}' for n,v,t in tags]

def doc_lines(node,indent=''):
    """A doc comment as Markdown lines after its summary: the tags as a list, then the remarks, each line indented."""
    _,remarks,tags=doc_parts(node)
    lines=tag_lines(tags)
    if remarks:lines+=(['']+remarks.split('\n') if lines else remarks.split('\n'))
    return [indent+l if l else '' for l in lines]

def member_lines(member,known,instance=()):
    """A public member as a Haxe signature and its doc, or None for a private one or the meta; instance names an abstract's properties,
    statics of its implementation whose accessors take the value."""
    if member.tag in ('haxe_doc','meta') or member.get('public')!='1' or hidden(member):return None
    name=member.tag;static='static ' if member.get('static')=='1' else ''
    kids=[c for c in member if c.tag not in ('haxe_doc','meta')]
    if not kids:return None
    t=kids[0]
    if name in instance:static=''
    # An inline method is a variable of a function type: written as the method it is.
    if (member.get('set')=='method' or member.get('get')=='inline') and t.tag=='f':
        names=t.get('a','').split(':') if t.get('a') else [];values=(t.get('v') or '').split(':') if t.get('v') else []
        parts=list(t);ret=type_text(parts[-1],known) if parts else 'Void'
        # An abstract's method is a static of its implementation taking the value first, as this: written as the game calls it.
        if names[:1]==['this']:names,parts,values,static=names[1:],parts[1:],values[1:],''
        args=[]
        for i,(n,k) in enumerate(zip(names,parts[:-1])):
            v=values[i] if i<len(values) else ''
            ty=type_text(k,known)
            # An optional argument is nullable as written; the compiler's XML wraps a typedef's in Null<> on Windows and not elsewhere.
            if n.startswith('?') and ty.startswith('Null<') and ty.endswith('>'):ty=ty[5:-1]
            args.append(f'{n}:{ty}'+(f' = {v}' if v else ''))
        sig=f'{static}function {name}({", ".join(args)})'+('' if name=='new' else f':{ret}')
    else:
        # A property's access as its source declares it: accessor is get or set, and a read-only one with a getter (null or never alike
        # from outside) reads (get, never).
        get=member.get('get','default');setter=member.get('set','default')
        get={'accessor':'get'}.get(get,get);setter={'accessor':'set'}.get(setter,setter)
        if get=='get' and setter=='null':setter='never'
        access='' if (get,setter)==('default','default') else f'({get}, {setter})'
        final_='final ' if member.get('final')=='1' else 'var '
        # A constant: inline, read-only.
        if (get,setter)==('inline','null'):final_,access='inline var ',''
        sig=f'{static}{final_}{name}{access}:{type_text(t,known)}'
    return sig,doc_text(member),member

def markdown(xml):
    """The Markdown files from a target's XML description: {relative path: text}."""
    types=public_types(xml)
    known=set(types)
    files={};index={}
    for path in sorted(types):
        node=types[path];name=short(path);params=node.get('params','')
        header=name+(f'<{params.replace(":",", ")}>' if params else '')
        kind={'class':'class','enum':'enum','typedef':'typedef','abstract':'abstract'}[node.tag]
        # Its source, relative to docs/api: a link on GitHub and in a checkout alike.
        source=node.get('file','')
        # The import that names it: its own path, as each shown type is its own file (checked above).
        lines=[f'## {header}','',f'*{kind}* in [`{source}`](../../{source})'+f', `import {path};`','']
        doc=doc_text(node)
        if doc:
            lines+=[doc,'']
            more=doc_lines(node)
            if more:lines+=more+['']
        file=package_file(path)
        # An abstract's values and members are its implementation class's statics: an enum abstract's values (:enum) listed by name, the
        # rest as a class's members.
        impl=node.find('impl') if node.tag=='abstract' else None
        body=impl[0] if impl is not None and len(impl) else node
        if node.tag=='abstract':
            values=[c for c in body if c.find('meta') is not None and any(m.get('n')==':enum' for m in c.find('meta'))]
            if values:
                documented=[c for c in values if doc_text(c)]
                if documented:
                    for c in values:lines.append(f'- `{name}.{c.tag}`'+(f': {doc_text(c)}' if doc_text(c) else ''))
                else:lines.append('Values: '+', '.join(f'`{c.tag}`' for c in values)+'.')
                lines.append('')
        if node.tag=='class' or node.tag=='abstract' and body is not node:
            # A property's accessors (get_x, set_x; an interface's are public) are the property, listed once.
            properties={c.tag for c in body if c.get('set')!='method' and c.get('get') is not None}
            enum={c.tag for c in body if c.find('meta') is not None and any(m.get('n')==':enum' for m in c.find('meta'))} if node.tag=='abstract' else set()
            # An abstract's property is the value's when its accessor takes the value (this).
            instance={c.tag for c in body if c.tag in properties and any((a.tag==f'get_{c.tag}' or a.tag==f'set_{c.tag}') and len(a) and (a[0].get('a') or '').split(':')[0]=='this' for a in body)} if node.tag=='abstract' else set()
            members=[m for m in (member_lines(c,known,instance) for c in body if c.tag not in enum and not (c.tag[:4] in ('get_','set_') and c.tag[4:] in properties)) if m]
            members.sort(key=lambda m:0 if m[0].split('(')[0].endswith(' new') else 1)
            if members:
                lines.append('```haxe')
                for sig,_,_ in members:lines.append(sig)
                lines.append('```');lines.append('')
                for sig,d,node_ in members:
                    if d:
                        lines.append(f'- `{sig.split("(")[0].split(":")[0].split()[-1]}`: {d}')
                        lines+=doc_lines(node_,'  ')
                lines.append('')
        elif node.tag=='enum':
            for c in node:
                if c.tag in ('haxe_doc','meta'):continue
                args=c.get('a','');lines.append(f'- `{c.tag}'+(f'({", ".join(a+":"+type_text(k,known) for a,k in zip(args.split(":"),c))})' if args else '')+'`'+(f': {doc_text(c)}' if doc_text(c) else ''))
            lines.append('')
        elif node.tag=='typedef':
            inner=[c for c in node if c.tag not in ('haxe_doc','meta')]
            if inner:
                if inner[0].tag=='a':
                    for f in inner[0]:
                        if len(f):lines.append(f'- `{f.tag}:{type_text(list(f)[0],known)}`'+(f': {doc_text(f)}' if doc_text(f) else ''))
                else:lines.append(f'An alias of `{type_text(inner[0],known)}`.')
                lines.append('')
        index.setdefault(file,[]).append((path,doc));files.setdefault(file,[]).append('\n'.join(lines))
    out={}
    readme=['# HeliX API reference','','New to HeliX? [The guide](../GUIDE.md) makes a game piece by piece; this is every type it uses, and the rest.','','Generated from the code\'s doc comments by `tools/gen_apidoc.py` (the same source as the HTML at https://whirlinggizmo.github.io/helix/api/); `python3 tools/gen_apidoc.py --check` fails when it\'s stale. A file a package, each type with its public members. '+TARGETS,'']
    for file in sorted(files):
        package='helix'+('' if file=='helix.md' else '.'+file[:-3].replace('-','.'))
        readme.append(f'- [`{package}`]({file}): '+', '.join(short(p) for p,_ in index[file]))
        out[file]='\n'.join([f'# {package}','']+(['[Back to the index](README.md)','']) + files[file]).rstrip('\n')+'\n'
    out['README.md']='\n'.join(readme)+'\n'
    return out

def main():
    import cli
    p=cli.parser(__doc__);p.add_argument('--check',action='store_true',help="write nothing; fail when docs/api isn't what the sources give")
    generate(check=p.parse_args().check)

def generate(check=False):
    """docs/api and the HTML in build/api from the doc comments; with check, writes nothing and fails when docs/api isn't what they give.
    What another tool calls (tools/pages.py): main reads the command line, this doesn't."""
    version=json.loads((ROOT/'dependencies.json').read_text(encoding='utf-8'))['dox']
    env=dict(os.environ,HAXELIB_PATH=str(ROOT/'build/haxelib'));(ROOT/'build/haxelib').mkdir(parents=True,exist_ok=True)
    # dox makes the HTML alone: a check (the Markdown, from Haxe's own description) needs no install.
    if not check and not (ROOT/'build/haxelib/dox'/version.replace('.',',')).is_dir():subprocess.run(['haxelib','--always','install','dox',version],env=env,check=True,stdout=subprocess.DEVNULL)
    if OUT.exists() and not check:shutil.rmtree(OUT)
    describe('js');describe('cpp')
    same_on_both(OUT/'xml/js.xml',OUT/'xml/cpp.xml')
    # A shown type is its own file, so it's imported by its own path (import helix.scene.transition.Fade): one in another type's module is
    # imported through that module's (helix.scene.Transition.Fade), which no one guesses.
    lodgers=sorted(f'{p} (in {n.get("file")})' for p,n in public_types(OUT/'xml/js.xml').items() if n.get('module') and n.get('module')!=p)
    if lodgers:sys.exit('gen_apidoc: shown types in another type\'s file; give each its own file, or hide it:\n  '+'\n  '.join(lodgers))
    leaked=leaks(OUT/'xml/js.xml')
    if leaked:sys.exit('gen_apidoc: shown members name hidden (@:noCompletion) types; hide or privatize the member, or show the type:\n  '+'\n  '.join(leaked))
    pages=markdown(OUT/'xml/js.xml')
    if check:
        stale=[name for name,text in pages.items() if not (DOCS/name).is_file() or (DOCS/name).read_text(encoding='utf-8')!=text]
        extra=[p.name for p in DOCS.glob('*.md') if p.name not in pages] if DOCS.is_dir() else []
        if stale or extra:
            # The first differing lines of each stale page, so a check failing on another system says what differs there.
            import difflib
            for name in stale:
                if (DOCS/name).is_file():
                    diff=list(difflib.unified_diff((DOCS/name).read_text(encoding='utf-8').splitlines(),pages[name].splitlines(),'committed '+name,'generated '+name,lineterm='',n=1))
                    print('\n'.join(diff[:40]),flush=True)
            sys.exit('gen_apidoc: docs/api is stale ('+', '.join(stale+extra)+'); run python3 tools/gen_apidoc.py and commit it')
        print('gen_apidoc: docs/api is current');return
    DOCS.mkdir(parents=True,exist_ok=True)
    for p in DOCS.glob('*.md'):
        if p.name not in pages:p.unlink()
    for name,text in pages.items():(DOCS/name).write_text(text,encoding='utf-8')
    # One target's description, both being the same (same_on_both): dox marks nothing as one target's and offers no filter by one. It
    # leaves out what's @:noCompletion itself.
    # Each type's View Source on GitHub, at the commit described, so the code linked is the code documented.
    commit=subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
    subprocess.run(['haxelib','run','dox','-i',str(OUT/'xml/js.xml'),'-o',str(OUT),'-in','^helix','-D','source-path',f'https://github.com/whirlinggizmo/helix-legacy/blob/{commit}/src/',
        '--title','HeliX API','-D','description','HeliX: a Haxe game framework. '+TARGETS],cwd=ROOT,env=env,check=True)
    print('API reference:',OUT/'index.html','and',DOCS)

if __name__=='__main__':main()
