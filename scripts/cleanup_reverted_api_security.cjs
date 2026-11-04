// Remove only resources introduced by the reverted API-security rollout.
// Run after the replacement API and deletion-only worker are verified live.
const fs = require('node:fs');
const path = require('node:path');
const { googleRequest, project, email, root } = require('./provision_deletion_runtime.cjs');
async function main() {
  const file=path.join(root,'reports/api-security/configuration.json');
  const original=JSON.parse(fs.readFileSync(file));
  if(original.notificationEmail!=='hezra664@gmail.com'||original.billingChanged)throw Error('Unexpected original rollout record');
  const request=await googleRequest();
  const monitoring=`https://monitoring.googleapis.com/v3/projects/${project}`;
  const removed=[];
  const expectedTitles=new Set(['Movie Hub daily API usage warning','Movie Hub API abuse warning','Movie Hub security monitor missing']);
  for(const policy of original.policies){
    if(!policy.name.startsWith(`projects/${project}/alertPolicies/`)||!expectedTitles.has(policy.displayName))throw Error('Unexpected policy identifier');
    const found=await request('https://monitoring.googleapis.com/v3/'+policy.name);
    if(found.status!==404){
      if(found.data.displayName!==policy.displayName)throw Error('Policy changed; refusing removal');
      await request('https://monitoring.googleapis.com/v3/'+policy.name,'DELETE');
    }
    removed.push(policy.name);
  }
  const remaining=(await request(monitoring+'/alertPolicies')).data.alertPolicies||[];
  if(!remaining.some(p=>p.notificationChannels?.includes(original.channel))){
    const channel=await request('https://monitoring.googleapis.com/v3/'+original.channel);
    if(channel.status!==404){
      if(channel.data.type!=='email'||channel.data.labels?.email_address!==original.notificationEmail)throw Error('Unexpected notification channel');
      await request('https://monitoring.googleapis.com/v3/'+original.channel,'DELETE');
    }
    removed.push(original.channel);
  }
  for(const metric of original.metrics){
    if(!/^api_daily_(admitted|limited|missing_attestation|invalid_attestation)$|^security_heartbeat$/.test(metric))throw Error('Unexpected metric');
    const type='custom.googleapis.com/moviehub/'+metric;
    if(remaining.some(policy=>JSON.stringify(policy.conditions).includes(type)))continue;
    const found=await request(monitoring+'/metricDescriptors/'+type);
    if(found.status!==404)await request(monitoring+'/metricDescriptors/'+type,'DELETE');
    removed.push(type);
  }
  const roleName=`projects/${project}/roles/movieHubSecurityMetrics`;
  const policyUrl=`https://cloudresourcemanager.googleapis.com/v1/projects/${project}`;
  const policy=(await request(policyUrl+':getIamPolicy','POST',{options:{requestedPolicyVersion:3}})).data;
  const before=JSON.stringify(policy.bindings);
  policy.bindings=(policy.bindings||[]).map(b=>b.role===roleName&&!b.condition
    ?{...b,members:b.members.filter(m=>m!=='serviceAccount:'+email)}:b).filter(b=>b.members.length);
  if(JSON.stringify(policy.bindings)!==before)await request(policyUrl+':setIamPolicy','POST',{policy});
  const role=await request('https://iam.googleapis.com/v1/'+roleName);
  if(role.status!==404&&!role.data.deleted&&!policy.bindings.some(b=>b.role===roleName)){
    if(JSON.stringify(role.data.includedPermissions)!==JSON.stringify(['monitoring.timeSeries.create']))throw Error('Custom role changed; refusing removal');
    await request('https://iam.googleapis.com/v1/'+roleName,'DELETE');removed.push(roleName);
  }
  require('../backend/node_modules/dotenv').config({path:path.join(root,'backend/.env'),quiet:true});
  const {database}=require('../backend/neon_database');
  const tables=await database.query("SELECT table_name FROM information_schema.tables WHERE table_schema='moviehub_security'");
  if(tables.some(t=>!['rate_windows','daily_usage'].includes(t.table_name)))throw Error('Unexpected table in security schema; refusing removal');
  // RESTRICT is intentional: never cascade into another feature's objects.
  await database.query('DROP FUNCTION IF EXISTS moviehub_security.consume(text,text,integer,bigint,text) RESTRICT');
  await database.query('DROP TABLE IF EXISTS moviehub_security.rate_windows RESTRICT');
  await database.query('DROP TABLE IF EXISTS moviehub_security.daily_usage RESTRICT');
  await database.query('DROP SCHEMA IF EXISTS moviehub_security RESTRICT');
  const report={completedAtUtc:new Date().toISOString(),removed,securitySqlSchemaRemoved:true,
    accountDeletionPreserved:true,forumPreserved:true,billingChanged:false,
    appCheckClientAndBackendRemoved:true,appCheckProviderMetadataRetained:true,
    note:'Existing Firebase app registrations are preserved. App Check enforcement was never enabled by this rollout.'};
  fs.writeFileSync(path.join(root,'reports/api-security/rollback.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}
main().catch(error=>{console.error(error.message);process.exitCode=1});
