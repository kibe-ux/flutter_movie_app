const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const root=path.resolve(__dirname,'..');
const logPath=path.join(root,'reports/account-forum-debug-build.log');
const output=fs.createWriteStream(logPath);
const java=path.join(process.env.JAVA_HOME||'C:/Program Files/Eclipse Adoptium/jdk-17.0.17.10-hotspot','bin/java.exe');
const child=spawn(java,['-Xmx128m','-classpath','gradle/wrapper/gradle-wrapper.jar',
  'org.gradle.wrapper.GradleWrapperMain','--no-daemon','--max-workers=1',
  '-Dorg.gradle.jvmargs=-Xmx768m -XX:MaxMetaspaceSize=256m -XX:ReservedCodeCacheSize=96m -XX:ActiveProcessorCount=2',
  '-I','../tools/android_local_debug.init.gradle','-Ptarget-platform=android-arm64',
  '-Pandroid.injected.build.abi=arm64-v8a',':app:assembleDebug'],{
  cwd:path.join(root,'android'),windowsHide:true,env:{...process.env,CMAKE_BUILD_PARALLEL_LEVEL:'1',
    JAVA_TOOL_OPTIONS:'-XX:ActiveProcessorCount=2'},stdio:['ignore','pipe','pipe']});
child.stdout.pipe(output);child.stderr.pipe(output);
child.on('error',()=>{console.error('Debug build could not start.');process.exitCode=1;output.end()});
child.on('exit',code=>{console.log(JSON.stringify({success:code===0,exitCode:code,log:'reports/account-forum-debug-build.log',
  apk:code===0?'build/app/outputs/flutter-apk/app-debug.apk':undefined}));process.exitCode=code||0;output.end()});
