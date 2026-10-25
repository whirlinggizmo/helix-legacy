# {title}

A game on [HeliX](https://github.com/whirlinggizmo/helix) (`-lib helix`). `src/Game.hx` is the game, `src/Main.hx` starts it.

- How to make one, piece by piece: [the guide](https://github.com/whirlinggizmo/helix/blob/main/docs/GUIDE.md) (`docs/GUIDE.md` in HeliX;
  with the game's own libraries, `.haxelib/helix/git/docs/GUIDE.md`).
- Every type: [the API reference](https://whirlinggizmo.github.io/helix/api/) (`docs/api/` beside the guide).
- In VS Code with the Haxe extension, completion and errors come from the browser build (`.vscode/settings.json` names
  `hxml/build.web.hxml`), with the game's own libraries.

The builds are in `hxml/`, each run from this directory:

```console
haxe hxml/dev.hxml                # the dev loop: open http://localhost:8064/, edit, save; the page takes the new code as it runs (a change to init after a refresh), and shaders/<name>.glsl as they change
haxe hxml/build.web.hxml          # the browser build alone, out/web/, without assets/ (the dev loop builds its own, in out/dev/)
haxe hxml/build.dist.hxml         # the release build for hosting: out/dist/, zipped as out/{name}-web.zip (itch.io)
haxe hxml/serve.dist.hxml         # out/dist/ served at http://localhost:8095/, to try before uploading
haxe hxml/serve.dist.https.hxml   # out/dist/ served at https://<this machine>:8495/, to try on a phone (see "On a phone")
haxe hxml/build.native.hxml       # the native build (hxcpp), out/native/Main; it reads assets/ beside itself: copy (or link) the directory to out/native/assets
```

`assets/` holds the game's files, each loaded by its path from there (`Textures.load("player.png", Nearest, ...)`, `Audio.loadClip("coin.wav", ...)`);
the release build copies it beside the page. `common.hxml` holds what every build shares, `web.hxml` the browser build's settings (the
dev loop and `build.web` each add where it's written); the build steps are macros in `helix.tool` (`Build`, `Watchers`, `WebServer`). `favicon.svg` is the page's icon: put
the game's own there. A shader of the game's own goes in `shaders/<name>.glsl` (make the directory): every build packs it into `assets/shaders/<name>.hxshader`,
the dev loop again as it changes, and the game loads it with `new Shaders().load("shaders/<name>.hxshader", ...)`; HeliX's
`docs/SHADERS.md` says how one is written. The shader compiler is fetched the first time a shader is packed; `haxelib run helix setup` fetches it ahead,
before going offline say.

## On a phone

A phone (or any other device on the network) needs HTTPS for tilt, fullscreen and the gamepad, and a page over plain HTTP from
another machine isn't secure. Here HTTPS is nginx in Docker in front of the dev loop and the release build (`docker-compose.yml`,
`tls/`), with a certificate of your own that the phone trusts. Once:

1. Install [mkcert](https://github.com/FiloSottile/mkcert) and Docker, then run `mkcert -install` (a certificate authority of your own).
2. Make this machine's certificate, naming it as the phone will (its address on the network, and its name):
   `mkcert -cert-file tls/cert.pem -key-file tls/key.pem <this machine's address> <this machine's name> localhost`.
   They're kept out of git (`.gitignore`). `TLS_CERT` and `TLS_KEY` name another pair.
3. Have the phone trust the authority: `mkcert -CAROOT` says where `rootCA.pem` is. Copy it to the phone and install it (Android:
   Settings, Security, Encryption and credentials, Install a certificate, CA certificate; iOS: open it to install its profile, then
   Settings, General, About, Certificate Trust Settings, and turn it on).

Then:

- **The dev loop:** in `hxml/dev.hxml`, use the commented serve line (it adds the sidecar) in place of the one above it. `haxe
  hxml/dev.hxml` then says the addresses it serves (`https://<this machine>:8443/`), and Ctrl+C stops both.
- **The release build:** `haxe hxml/build.dist.hxml`, then `haxe hxml/serve.dist.https.hxml` and open `https://<this machine>:8495/`.

Chrome on a phone may still have motion sensors off for a site (or all of them): the address bar's icon, Permissions, Motion sensors.

## The libraries, the game's own

A game can keep the libraries it builds with to itself, so another game or a newer HeliX on the machine can't change its build. In this
directory:

```console
haxelib newrepo                                                            # .haxelib/, used only by builds run from here
haxelib git helix https://github.com/whirlinggizmo/helix                   # a clone as it is now
haxelib git hotreload-hx https://github.com/whirlinggizmo/hotreload-hx     # the dev loop's
```

The hxml files don't change (`-lib helix` finds the game's own). A local repository doesn't fall back to the machine's, so every library the
game uses goes in it (hxcpp too, for a native build: `haxelib install hxcpp`). `.haxelib/` isn't committed (.gitignore): these commands
remake it, and `git -C .haxelib/helix/git log -1` says which HeliX it holds. `haxelib deleterepo` goes back to the machine's.

To keep the game on one HeliX (a tag or a commit), say so in `hxml/common.hxml`, where it stays with the game, rather than on the
command line: `haxelib update` moves a library installed with `haxelib git ... <tag>` back to the branch's latest.

```hxml
-lib helix:git:https://github.com/whirlinggizmo/helix#jam-2026-10-23        # in hxml/common.hxml, for -lib helix
```

```console
haxelib install hxml/common.hxml                                           # fetches what the hxml names, and puts a moved one back
```

Then don't run `haxelib update` for it; change the tag in the hxml and install again to move to another HeliX.

