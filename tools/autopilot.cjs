// Plays an example's autopilot in a headless browser against its served build and prints what the example published (tools/example.py),
// with the renderer it ran on. First on the GPU (Vulkan on Linux, Metal on macOS, the browser's own choice on Windows), so a driver's bug
// can show; when the page says the platform can't draw (window.graphicsUnavailable: no WebGL2, a context lost; whichever GPU API the page
// uses), once more on SwiftShader, the browser's software renderer: CI's machines have no GPU, and a software Vulkan driver gives ANGLE no
// usable WebGL2. The autopilot compares games, not pixels, so either serves; the output says which ran, and why it fell back. A script that
// fails publishes {failed} (Autopilot.failure): printed as any result, then its message on stderr, exiting 1.
const [browserPath,url]=require('./cli.cjs').args(__filename,['browser','url']);
const path=require('path');
const {chromium}=require(path.join(__dirname,'../build/tools/node_modules/playwright'));
const GPU=process.platform==='linux'?['--use-angle=vulkan']:process.platform==='darwin'?['--use-angle=metal']:[];
const SOFTWARE=['--use-angle=swiftshader','--enable-unsafe-swiftshader'];

// One run in a browser started with args: {result, errors, renderer} once the page publishes, or {unavailable} when it says it can't draw.
async function run(args){
 const browser=await chromium.launch({executablePath:browserPath,headless:true,args:['--no-sandbox',...args]});const errors=[];
 try{const page=await browser.newPage({viewport:{width:800,height:600}});page.on('pageerror',e=>errors.push(e.message));
  // The page's console errors too, and what the page shows, so a run that never publishes says why.
  page.on('console',m=>{if(m.type()==='error')errors.push('console: '+m.text());});
  await page.goto(url);
  try{await page.waitForFunction(()=>window.result||window.graphicsUnavailable,null,{timeout:60000});}
  catch(e){const status=await page.evaluate(()=>document.getElementById('status')?.textContent||'').catch(()=>'');
   throw new Error(`${e.message}\npage errors: ${JSON.stringify(errors)}\npage status: ${JSON.stringify(status)}`);}
  const unavailable=await page.evaluate(()=>window.graphicsUnavailable);
  if(unavailable)return {unavailable};
  // The renderer the browser gives this page, by WebGL's name for it.
  const renderer=await page.evaluate(()=>{const gl=document.createElement('canvas').getContext('webgl2');if(!gl)return null;
   const info=gl.getExtension('WEBGL_debug_renderer_info');return info?gl.getParameter(info.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER);});
  return {result:await page.evaluate(()=>window.result),errors,renderer};}
 finally{await browser.close();}
}

(async()=>{
 let outcome=await run(GPU);
 if(outcome.unavailable){const reason=outcome.unavailable;outcome=await run(SOFTWARE);outcome.fallback=reason;
  if(outcome.unavailable)throw new Error(`No graphics, on the GPU or in software: ${outcome.unavailable}`);}
 console.log(JSON.stringify(outcome));
 if(outcome.result&&outcome.result.failed){console.error(`autopilot failed: ${outcome.result.failed}`);process.exitCode=1;}
})().catch(e=>{console.error(e.stack||e);process.exit(1);});
