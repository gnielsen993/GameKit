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
   const headerFits=await page.evaluate(()=>{const h=document.querySelector('h1'),header=document.querySelector('header').getBoundingClientRect(),device=document.querySelector('.device').getBoundingClientRect();return h.getBoundingClientRect().height<=parseFloat(getComputedStyle(h).lineHeight)*2+1&&header.bottom+24<device.top});
   if(!headerFits)throw Error(`${family}/${slide.id} heading wraps or crowds the device`);
   const videoFits=await page.evaluate(()=>{const v=document.querySelector('.video-window');if(!v)return true;const r=v.getBoundingClientRect(),d=v.parentElement.getBoundingClientRect();return r.left>d.left&&r.right<d.right&&r.top>d.top&&r.bottom<d.top+d.height*(document.body.classList.contains("ipad")?.33:.40)});
   if(!videoFits)throw Error(`${family}/${slide.id} video crosses reserved band`);
   if(problems.length)throw Error(`${family}/${slide.id} overflow: ${problems}`);
   const relative=`exports/${family}/${slide.id}.png`;await page.screenshot({path:path.join(root,relative),omitBackground:false});
   manifest.exports.push({path:relative,width,height,title:slide.title.replaceAll('\n',' '),source:`raw/${family}/${slide.source}.png`,illustrativeVideoOverlay:!!slide.video,sha256:sha(path.join(root,relative))});
  }
  await page.close();
 }
 for(const source of manifest.sources)if(source.sha256!==sha(path.join(root,source.path)))throw Error('Source changed: '+source.path);
 for(const family of ['iphone','ipad']){for(const file of fs.readdirSync(path.join(root,'exports',family))){const relative=`exports/${family}/${file}`;if(/^\d{2}-[a-z-]+\.png$/.test(file)&&!manifest.exports.some(x=>x.path===relative))fs.unlinkSync(path.join(root,relative))}}
 fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 console.log(`Rendered ${manifest.exports.length} images; ${manifest.sources.length} native sources preserved.`);
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
