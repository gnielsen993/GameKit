const fs=require('fs'),path=require('path'),crypto=require('crypto'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=__dirname;
(async()=>{
 const counts={};for(const [field,limit] of Object.entries({name:30,subtitle:30,'promotional-text':170,keywords:100,description:4000,'whats-new':4000})){
  const value=fs.readFileSync(path.join(root,'metadata',field+'.txt'),'utf8').trim();counts[field]=[...value].length;if(counts[field]>limit)throw Error(field+' exceeds limit');
 }
 const archiveRoot=path.join(root,'concepts/previous-ten-slide-set');
 const archive=JSON.parse(fs.readFileSync(path.join(archiveRoot,'manifest.json')));
 for(const item of archive.exports){const hash=crypto.createHash('sha256').update(fs.readFileSync(path.join(archiveRoot,item.path))).digest('hex');if(hash!==item.sha256)throw Error('Archived concept changed: '+item.path)}
 const manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
 for(const item of manifest.exports){const png=fs.readFileSync(path.join(root,item.path));if(png.readUInt32BE(16)!==item.width||png.readUInt32BE(20)!==item.height||png[25]!==2)throw Error('Invalid RGB PNG '+item.path)}
 const browser=await chromium.launch({channel:'chrome',headless:true}),checks=[];
 try{for(const width of [375,768,1440]){
  const page=await browser.newPage({viewport:{width,height:1000}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(pathToFileURL(path.join(root,'index.html')).href);
  for(const device of ['iphone','ipad']){
   await page.locator(`[data-device=${device}]`).click();
   await page.evaluate(async()=>{document.querySelectorAll('img').forEach(i=>i.loading='eager');await Promise.all([...document.images].map(i=>i.decode()))});
   if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Gallery overflow');
   const links=await page.locator('article a').evaluateAll(a=>a.map(x=>x.getAttribute('href')));
   if(links.length!==10||links.some(x=>!x.startsWith(`exports/${device}/`)||!fs.existsSync(path.join(root,x))))throw Error('Gallery links invalid');
   const pair=await page.locator('.store-preview a').evaluateAll(as=>as.map(a=>a.getAttribute('href')));if(pair.length!==2||!pair[0].endsWith('02-video-off.png')||!pair[1].endsWith('03-video-on.png'))throw Error('Store preview order incorrect');
   if(width===1440)await page.locator('.store-preview').screenshot({path:path.join(root,'review',device+'-store-pair.png')});
   if(errors.length)throw Error(errors.join('\n'));
   checks.push({width,device,images:links.length,overflow:false,errors});
   if(width===1440)await page.screenshot({path:path.join(root,'review',device+'-gallery.png'),fullPage:true});
  }await page.close();
 }}finally{await browser.close()}
 fs.writeFileSync(path.join(root,'review','verification.json'),JSON.stringify({counts,exports:manifest.exports.length,preservedArchivedExports:archive.exports.length,checks},null,2)+'\n');
 console.log('Verified metadata, 20 RGB exports, gallery at 3 widths and both device tabs.');
})().catch(e=>{console.error(e);process.exit(1)});
