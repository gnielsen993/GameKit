const fs=require('fs'),path=require('path'),crypto=require('crypto'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=__dirname,sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 try{
 const manifest={generatedAt:new Date().toISOString(),method:'HTML/CSS framing; native PNGs unchanged, uniformly scaled',sources:[],exports:[]};
 for(const family of ['iphone','ipad']){
  for(const file of fs.readdirSync(path.join(root,'raw',family)).filter(x=>x.endsWith('.png'))){const relative=`raw/${family}/${file}`;manifest.sources.push({path:relative,sha256:sha(path.join(root,relative))})}
  const [width,height]=family==='iphone'?[1320,2868]:[2064,2752];
  const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:1});
  await page.goto(pathToFileURL(path.join(root,'artboard.html')).href+'?device='+family);
  const slides=await page.evaluate(()=>window.slides);
  fs.mkdirSync(path.join(root,'exports',family),{recursive:true});
  for(const slide of slides){
   await page.goto(pathToFileURL(path.join(root,'artboard.html')).href+`?device=${family}&slide=${slide.id}`);
   await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.decode()))});
   const problems=await page.evaluate(()=>[...document.querySelectorAll('header,h1,.deck,.device,.note')].flatMap(e=>{const r=e.getBoundingClientRect();return r.left<0||r.right>innerWidth||r.top<0||r.bottom>innerHeight||e.scrollWidth>e.clientWidth+1?[e.className||e.tagName]:[]}));
   if(problems.length)throw Error(`${family}/${slide.id} overflow: ${problems}`);
   const relative=`exports/${family}/${slide.id}.png`;await page.screenshot({path:path.join(root,relative),omitBackground:false});
   manifest.exports.push({path:relative,width,height,title:slide.title.replaceAll('\n',' '),sha256:sha(path.join(root,relative))});
  }
  await page.close();
 }
 for(const source of manifest.sources)if(source.sha256!==sha(path.join(root,source.path)))throw Error('Source changed: '+source.path);
 fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 console.log(`Rendered ${manifest.exports.length} images; ${manifest.sources.length} native sources preserved.`);
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
