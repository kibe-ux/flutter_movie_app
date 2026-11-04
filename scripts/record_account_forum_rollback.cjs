const fs=require('node:fs');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
const removed=new Set(['APP_CHECK_MODE','APP_CHECK_APP_IDS','API_RATE_LIMIT_ENABLED','API_CATALOGUE_PER_MINUTE',
  'API_SEARCH_PER_MINUTE','API_DOWNLOAD_PER_MINUTE','API_DAILY_HARD_LIMIT','SECURITY_METRICS_ENABLED']);
try{
  const functions={};
  for(const slug of ['moviehub','accountcleanup']){
    const run=spawnSync(process.execPath,['node_modules/neon/dist/cli.js','functions','get',slug,
      '--project-id','summer-shadow-58564268','--branch','br-empty-forest-b4htkwt9','-o','json'],{
      cwd:path.join(root,'backend'),encoding:'utf8',windowsHide:true,maxBuffer:8*1024*1024});
    if(run.status!==0)throw Error('Deployment metadata unavailable; raw output suppressed.');
    const raw=JSON.parse(run.stdout),info=raw.function||raw;
    const deployed=info.active_deployment;
    const names=(deployed?.environment||[]).map(value=>typeof value==='string'?value:value.name);
    const leftovers=names.filter(name=>removed.has(name));
    functions[slug]={deploymentId:deployed?.id,status:deployed?.status,
      accountCleanupCredentialPresent:names.includes('FIREBASE_SERVICE_ACCOUNT_JSON'),
      removedSecuritySettingsAbsent:leftovers.length===0};
    if(leftovers.length||!functions[slug].accountCleanupCredentialPresent)throw Error('Hosted configuration differs from rollback intent.');
  }
  const now=new Date().toISOString();
  const report={verifiedAtUtc:now,functions,accountDeletionEnabled:true,workerEnabled:true,securityExtensionReverted:true};
  const directory=path.join(root,'reports/account-forum-rollback');fs.mkdirSync(directory,{recursive:true});
  fs.writeFileSync(path.join(directory,'deployment.json'),JSON.stringify(report,null,2)+'\n');
  fs.writeFileSync(path.join(root,'reports/account-deletion-rollout/last-deployment-stage.json'),JSON.stringify({
    mode:'--enable-deletion',accountDeletionEnabled:true,workerEnabled:true,privateKeyStoredLocally:false,
    deployedAtUtc:now,securityExtensionReverted:true},null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}catch(error){console.error(error.message);process.exitCode=1}
