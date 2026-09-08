const fs=require('fs'),path=require('path'),crypto=require('crypto'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=__dirname,campaign=path.resolve(root,'../..'),hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
(async()=>{
 const current=JSON.parse(fs.readFileSync(path.join(campaign,'manifest.json')));
 for(const item of current.exports)if(hash(path.join(campaign,item.path))!==item.sha256)throw Error('Existing concept changed: '+item.path);
 const alternate=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
 for(const item of alternate.exports){const png=fs.readFileSync(path.join(root,item.path));if(hash(path.join(root,item.path))!==item.sha256||png.readUInt32BE(16)!==item.width||png.readUInt32BE(20)!==item.height||png[25]!==2)throw Error('Invalid comparison export')}
 const browser=await chromium.launch({channel:'chrome',headless:true}),checks=[];
 try{for(const width of [375,768,1440]){
  const page=await browser.newPage({viewport:{width,height:1000}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(pathToFileURL(path.join(campaign,'index.html')).href);
  if(await page.locator('article a').count()!==10)throw Error('Current ten-image gallery changed');
  await page.locator('a[href="concepts/sudoku-comparison/index.html"]').click();
  await page.evaluate(async()=>Promise.all([...document.images].map(i=>i.decode())));
  if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Alternate gallery overflows');
  for(const href of await page.locator('a').evaluateAll(as=>as.map(a=>a.getAttribute('href'))))if(!fs.existsSync(path.resolve(root,href)))throw Error('Broken link: '+href);
  if(errors.length)throw Error(errors.join('\n'));
  if(width===375||width===1440)await page.screenshot({path:path.join(root,'review',`gallery-${width}.png`),fullPage:true});
  await page.getByRole('link',{name:'Current App Store selection and preserved concepts'}).click();
  if(await page.locator('article a').count()!==10)throw Error('Return link failed');
  checks.push({width,overflow:false,errors:0,roundTripNavigation:true});await page.close();
 }}finally{await browser.close()}
 fs.writeFileSync(path.join(root,'review/verification.json'),JSON.stringify({preservedExistingExports:current.exports.length,comparisonExports:alternate.exports.length,checks},null,2)+'\n');
 console.log('All 20 existing exports preserved; two new comparison PNGs and gallery navigation verified at three widths.');
})().catch(e=>{console.error(e);process.exit(1)});
