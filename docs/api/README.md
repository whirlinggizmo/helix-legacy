# HeliX API reference

New to HeliX? [The guide](../GUIDE.md) makes a game piece by piece; this is every type it uses, and the rest.

Generated from the code's doc comments by `tools/gen_apidoc.py` (the same source as the HTML at https://whirlinggizmo.github.io/helix/api/); `python3 tools/gen_apidoc.py --check` fails when it's stale. A file a package, each type with its public members. Every type here is on both of HeliX's Haxe targets, js (the browser) and cpp (native); the engine's own types beneath them (@:noCompletion: the adapters, profiles and services behind the static classes), which a game never names, are left out.

- [`helix.asset`](asset.md): AssetCacheMode, AssetPath, AssetProgress, Assets, EnsureOptions, ExportResult, Failure, Fetch, FetchPart, FetchProgress, FetchRequest, FetchResponse, FetchResult, IReloadable, IRequest, Saves, Storage, StorageResult, StorageSourceResult, StorageWriteResult
- [`helix.audio`](audio.md): Audio, AudioClip, AudioPlayback, AudioResource, AudioStream, Bus, Fade, FadeCurve, PlayState, StreamOpenResult
- [`helix.behavior`](behavior.md): Behavior, BehaviorEntry, BehaviorPass, BehaviorProp, BehaviorPropType, BehaviorRegistry, BehaviorSchema, Behaviors, Phase
- [`helix.collision`](collision.md): Body2D, Collide2D, Hit2D, Move2D, SpatialHash2D
- [`helix.debug`](debug.md): Autopilot, FpsOverlay, PickOverlay2D, PickOverlay3D, TestHarness
- [`helix.font`](font.md): Font, Fonts, Glyph
- [`helix.graphics`](graphics.md): AlphaMode, BlendMode, ClipFlip, Color, DepthTest, Graphics, PostProcess, ScreenEffect, ScreenFrame, ScreenshotResult, Screenshots, Shader, ShaderParameter, ShaderParameters, Shaders, SpriteEffect
- [`helix`](helix.md): App, AppOptions
- [`helix.host`](host.md): Config, Host, Identity, PresentationMode, Screen, ScreenShape, Window, WindowOptions
- [`helix.input`](input.md): Actions, Anchor, Binding, Gamepad, IInput, Input, InputState, Key, MouseButton, PadAxis, PadButton, PointerGestures, StickArea, StickAxis, Touch
- [`helix.math`](math.md): Bounds2D, Bounds3D, Curve, CurveKind, Interpolate, Point2D, Point3D, Random, Trig
- [`helix.particle`](particle.md): Emitter, ParticlePreset
- [`helix.render2d`](render2d.md): Align2D, AnimationDirection2D, Camera2D, CameraFollow2D, Decals2D, Drawing2D, HitArea2D, Node2D, Particles2D, Polygon2D, Shape2D, ShapeForm2D, ShapeShading2D, Sprite2D, SpriteAnimation2D, SpriteAnimator2D, SpriteFrame2D, SpriteSheet2D, Stage, Text2D, View, View2D
- [`helix.render3d`](render3d.md): AnimationClip3D, Animator3D, Attachment3D, Camera3D, CubeMap3D, Decals3D, DirectionalLight3D, Drawing3D, Environment3D, EnvironmentBake3D, EnvironmentMap3D, Environments3D, HitArea3D, ImageSource3D, Light3D, Mat4, Material3D, Mesh3D, MeshShape3D, Model3D, ModelFile3D, ModelPass3D, Models3D, Node3D, Orbit3D, Part3D, Particles3D, PickHit3D, PointLight3D, Projection3D, Ray3D, Skin3D, SpotLight3D, Sprite3D, SpriteFacing3D, Text3D, Tonemap, Track3D, TrackInterpolation3D, TrackPath3D, View3D
- [`helix.scene.transition`](scene-transition.md): Closing, Diamond, Fade, Iris, Noise, Slide, SlideDirection, Transition
- [`helix.scene`](scene.md): Collect2D, Loader, Loading, Node, Pointer, SceneBehavior, SceneEnvironment3D, SceneFile3D, SceneFiles3D, SceneInstance3D, SceneMaterial3D, SceneMesh3D, SceneNode3D, SceneValue, Splash
- [`helix.shader`](shader.md): Bloom, Blur, ChromaticAberration, ColorLut, Crt, Dissolve, Fxaa, HitFlash, LibraryScreenEffect, LibrarySurface, Outline, PaletteSwap, Pixelate, Rim, Silhouette, SpriteDissolve, SpriteFlash, SpriteOutline, SpriteRing, Tonemap, Toon, Unlit, Vignette, Water
- [`helix.texture`](texture.md): Filter, Sampling, Texture2D, TextureFormat, Textures, Wrap
- [`helix.tiled`](tiled.md): TiledFrame2D, TiledInstance2D, TiledLayer2D, TiledLayerKind2D, TiledMap2D, TiledObject2D, TiledProperties2D, TiledShape2D, TiledTerrainKind2D, TiledTerrainSet2D, TiledTileLayer2D, TiledTileset2D
- [`helix.time`](time.md): Clock, Ticker, Time, Timer, Timers
- [`helix.tool`](tool.md): Build, Watchers, WebServer
- [`helix.tween`](tween.md): Ease, Tween, Tweens
- [`helix.ui`](ui.md): Alignment2D, Button, Chevron, ColorFormat, ColorPicker, Dropdown, FullscreenButton2D, Handle, Label, Layout2D, LayoutDirection2D, ListView, Panel, Popup, ProgressBar, ScrollArea, Scrollbar, ScrollbarVisibility, Separator, Sizing2D, Slider, TextField, Theme, Tile, Toggle, TouchStick2D, Ui, Widget, WidgetState
