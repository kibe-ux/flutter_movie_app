// Exercises Google's public popup up to the identity chooser; never signs in.
const { spawn } = require('node:child_process');
const net = require('node:net');
const path = require('node:path');
const fs = require('node:fs');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function main() {
  const reserve = net.createServer();
  await new Promise(resolve => reserve.listen(0, '127.0.0.1', resolve));
  const port = reserve.address().port;
  await new Promise(resolve => reserve.close(resolve));
  const origin = 'https://br-empty-forest-b4htkwt9-moviehub.compute.c-6.us-east-2.aws.neon.tech';
  const browser = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
    '--headless=new', '--disable-gpu', '--disable-extensions', '--no-first-run',
    '--no-default-browser-check', '--disable-sync', '--remote-debugging-address=127.0.0.1',
    `--remote-debugging-port=${port}`, `--user-data-dir=${path.resolve('tools/firestore-tests/.emulator/production-browser-profile')}`,
    'about:blank'], { windowsHide: true, stdio: 'ignore' });
  let socket, counter = 0;
  const pending = new Map();
  const command = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++counter;
    const timeout = setTimeout(() => { pending.delete(id); reject(Error('Browser command timed out')); }, 15000);
    pending.set(id, { resolve, reject, timeout });
    socket.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => (await command('Runtime.evaluate', { expression, returnByValue: true })).result?.value;
  try {
    let target;
    for (let n = 0; n < 100; n++) {
      try { const res = await fetch(`http://127.0.0.1:${port}/json/new?${encodeURIComponent(origin + '/delete-account')}`, { method: 'PUT' });
        if (res.ok) { target = await res.json(); break; } } catch (_) { /* Startup. */ }
      await delay(200);
    }
    if (!target) throw Error('Browser did not start');
    socket = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise(resolve => socket.addEventListener('open', resolve, { once: true }));
    socket.addEventListener('message', event => {
      const data = JSON.parse(event.data), item = pending.get(data.id);
      if (item) { pending.delete(data.id); clearTimeout(item.timeout); data.error ? item.reject(Error('Browser protocol failed')) : item.resolve(data.result); }
    });
    await command('Page.enable');
    await command('Page.addScriptToEvaluateOnNewDocument', { source: `window.cspFailures=[];document.addEventListener('securitypolicyviolation',e=>{let host;try{host=new URL(e.blockedURI).origin}catch(_){host=e.blockedURI};window.cspFailures.push({directive:e.effectiveDirective,origin:host})});` });
    await command('Page.reload', { ignoreCache: true });
    for (let n = 0; n < 100; n++) {
      if (await evaluate(`document.getElementById('status')?.textContent === 'Choose your account sign-in method.'`)) break;
      await delay(200);
    }
    await command('Runtime.evaluate', { expression: `document.getElementById('google').click()`, userGesture: true });
    await delay(30000);
    const diagnostics = await evaluate(`({status:document.getElementById('status')?.textContent,cspFailures:window.cspFailures||[],iframeOrigins:Array.from(document.querySelectorAll('iframe')).map(el=>{try{return new URL(el.src).origin}catch(_){return 'unset'}}),resourceOrigins:Array.from(new Set(performance.getEntriesByType('resource').map(r=>new URL(r.name).origin)))})`);
    const tabs = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    const popupOrigins = tabs.filter(t => t.type === 'page').flatMap(t => {try{return [new URL(t.url).origin]}catch(_){return []}});
    const result = { checkedAtUtc: new Date().toISOString(), ...diagnostics, popupOrigins,
      googleChooserReached: popupOrigins.includes('https://accounts.google.com'), userSignInAttempted: false };
    result.passed = result.googleChooserReached && result.cspFailures.length === 0;
    fs.writeFileSync('reports/account-deletion-rollout/google-browser-diagnostics.json', JSON.stringify(result, null, 2) + '\n');
    console.log(JSON.stringify(result, null, 2));
    if (!result.passed) process.exitCode = 1;
  } finally {
    if (socket?.readyState === WebSocket.OPEN) { try { await command('Browser.close'); } catch (_) {} socket.close(); }
    if (browser.exitCode === null) browser.kill();
    for (const item of pending.values()) { clearTimeout(item.timeout); item.reject(Error('Browser closed')); }
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
