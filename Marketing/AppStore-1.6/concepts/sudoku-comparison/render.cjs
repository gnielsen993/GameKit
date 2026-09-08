const fs=require('fs'),path=require('path'),crypto=require('crypto'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=__dirname,sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
(async()=>{
 const manifest={method:'Paired native Sudoku captures. Identical illustrative PiP windows per device. No app pixels altered.',sources:JSON.parse(fs.readFileSync(path.join(root,'capture-manifest.json'))).sources,exports:[]};
 const browser=await chromium.launch({channel:'chrome',headless:true});
 try{
 for(const family of ['iphone','ipad']){
  const [width,height]=family==='iphone'?[1320,2868]:[2064,2752];
  const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:1});
  await page.goto(pathToFileURL(path.join(root,'artboard.html')).href+'?device='+family);
  await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.decode()))});
  const checks=await page.evaluate(()=>{
   const rect=e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,bottom:r.bottom,right:r.right}};
   const devices=[...document.querySelectorAll('.device')].map(rect),videos=[...document.querySelectorAll('.video-window')].map(rect);
   const imageRects=[...document.querySelectorAll('.native')].map(rect);
   const ip=document.body.classList.contains('ipad');
   // Conservative bounds measured on these unchanged native captures:
   // off-board top and first on-screen control with Video Mode on.
   const offBoardTop=ip?.155:.278,onControlsTop=ip?.33:.35;
   const normalized=videos.map((v,i)=>({x:(v.x-imageRects[i].x)/imageRects[i].width,y:(v.y-imageRects[i].y)/imageRects[i].height,width:v.width/imageRects[i].width,height:v.height/imageRects[i].height,bottom:(v.bottom-imageRects[i].y)/imageRects[i].height}));
   return {identicalWindows:Math.abs(videos[0].width-videos[1].width)<1&&Math.abs(videos[0].height-videos[1].height)<1&&Math.abs(normalized[0].x-normalized[1].x)<.001&&Math.abs(normalized[0].y-normalized[1].y)<.001,
    offOverlap:normalized[0].bottom-offBoardTop,onClearance:onControlsTop-normalized[1].bottom,
    normalizedWindows:normalized,
    overflow:[...document.querySelectorAll('header,h1,.column-title,.device,.caption,.takeaway,.note')].some(e=>{const r=rect(e);return r.x<0||r.right>innerWidth||r.y<0||r.bottom>innerHeight||e.scrollWidth>e.clientWidth+1}),
    headerClear:rect(document.querySelector('header')).bottom+30<rect(document.querySelector('.column-title')).y,
    captionsClear:devices.every(d=>d.bottom+20<rect(document.querySelector('.caption')).y)};
  });
  if(!checks.identicalWindows||checks.offOverlap<.03||checks.onClearance<=0||checks.overflow||!checks.headerClear||!checks.captionsClear)throw Error(JSON.stringify({family,checks}));
  const relative=`${family}-sudoku-comparison.png`;
  await page.screenshot({path:path.join(root,relative),omitBackground:false});
  const png=fs.readFileSync(path.join(root,relative));if(png[25]!==2)throw Error('Export is not RGB');
  manifest.exports.push({path:relative,width,height,sha256:sha(path.join(root,relative)),checks});await page.close();
 }
 for(const s of manifest.sources)if(sha(path.join(root,s.path))!==s.sha256)throw Error('Raw screenshot changed');
 fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 console.log('Two comparison exports verified: matched windows, cells covered only on left, controls clear on right, raw captures preserved.');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
