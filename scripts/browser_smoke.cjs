const { chromium } = require('playwright');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const output = 'build/browser-smoke';
fs.mkdirSync(output, {recursive:true});
const server = spawn('python3',['-m','http.server','8137','--bind','127.0.0.1','--directory','build/web'],{stdio:'ignore'});
(async()=>{
  let browser;
  const errors=[];
  try {
    for(let i=0;i<40;i++){
      try { if((await fetch('http://127.0.0.1:8137/index.html')).ok) break; } catch {}
      await new Promise(r=>setTimeout(r,250));
    }
    browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
    const page=await browser.newPage({viewport:{width:800,height:450},deviceScaleFactor:1});
    page.on('pageerror', e=>errors.push(e.message));
    page.on('console', m=>{if(/SCRIPT ERROR|Failed to load|WebGL 2 not available/i.test(m.text()))errors.push(m.text());});
    page.on('response', r=>{if(r.status()>=400 && /\.(pck|wasm|js)(\?|$)/.test(r.url()))errors.push(r.status()+' '+r.url());});
    await page.goto('http://127.0.0.1:8137/index.html',{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>{const c=document.querySelector('canvas');return c && c.width>0 && c.height>0 && (!document.querySelector('#status') || getComputedStyle(document.querySelector('#status')).display==='none');},{},{timeout:90000});
    await page.waitForTimeout(3000);
    await page.screenshot({path:output+'/title.png',timeout:120000});
    const dims=await page.locator('canvas').evaluate(c=>({width:c.width,height:c.height}));
    assert.ok(dims.width>0 && dims.height>0);
    await page.setViewportSize({width:640,height:360});
    await page.waitForTimeout(1200);
    await page.screenshot({path:output+'/resized.png',timeout:120000});
    assert.equal(errors.length,0,errors.join('\n'));
    fs.writeFileSync(output+'/report.json',JSON.stringify({passed:true,canvas:dims,renderer:'Chromium software WebGL',errors},null,2));
    console.log('BROWSER SMOKE PASS');
  }catch(e){
    fs.writeFileSync(output+'/report.json',JSON.stringify({passed:false,error:String(e),errors},null,2));
    throw e;
  }finally{if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
