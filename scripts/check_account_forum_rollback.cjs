// Test only a newly created disposable account; never use existing users.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {config}=require('../backend/deletion_page');
const base='https://br-empty-forest-b4htkwt9-moviehub.compute.c-6.us-east-2.aws.neon.tech';
async function main(){
  let token,uid;
  const result={checkedAtUtc:new Date().toISOString(),providerCalls:0};
  try{
    const signup=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${encodeURIComponent(config.apiKey)}`,{
      method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({
        email:`rollback-check-${crypto.randomBytes(8).toString('hex')}@example.invalid`,
        password:crypto.randomBytes(32).toString('base64url'),returnSecureToken:true})});
    if(!signup.ok)throw Error('Could not create disposable rollback test account.');
    const account=await signup.json();token=account.idToken;uid=account.localId;
    const responses=await Promise.all(Array.from({length:31},()=>fetch(base+'/api/mobile/search',{
      headers:{Authorization:'Bearer '+token,'X-Firebase-AppCheck':'invalid-rollback-test'},signal:AbortSignal.timeout(30000)})));
    result.methodValidationResponses=responses.filter(r=>r.status===405).length;
    result.noRateLimitResponses=responses.every(r=>r.status!==429);
    result.noAppCheckHeader=responses.every(r=>!r.headers.has('x-moviehub-app-check'));
    if(result.methodValidationResponses!==31||!result.noRateLimitResponses||!result.noAppCheckHeader)throw Error('Rollback is not reflected by the live API.');
  }finally{
    if(token){
      const deleted=await fetch(base+'/api/account',{method:'DELETE',headers:{Authorization:'Bearer '+token},signal:AbortSignal.timeout(90000)});
      const data=await deleted.json();
      result.deletionStillWorks=deleted.status===200&&data.status==='complete';
      if(result.deletionStillWorks){
        const lookup=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(config.apiKey)}`,{
          method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({idToken:token})});
        result.deletedLoginRejected=lookup.status===400;
      }else result.disposableAccountForRecovery=uid;
    }
    result.passed=result.methodValidationResponses===31&&result.noRateLimitResponses&&result.noAppCheckHeader&&result.deletionStillWorks&&result.deletedLoginRejected;
    const dir=path.resolve(__dirname,'../reports/account-forum-rollback');fs.mkdirSync(dir,{recursive:true});
    fs.writeFileSync(path.join(dir,'production-check.json'),JSON.stringify(result,null,2)+'\n');
    console.log(JSON.stringify(result,null,2));
    if(!result.passed)process.exitCode=1;
  }
}
main().catch(error=>{console.error(error.message);process.exitCode=1});
