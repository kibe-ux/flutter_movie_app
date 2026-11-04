import hashlib
import json
import pathlib
import zipfile
from datetime import datetime, timezone

root = pathlib.Path(__file__).resolve().parent.parent
apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
with zipfile.ZipFile(apk) as archive:
    kernel = archive.read('assets/flutter_assets/kernel_blob.bin')
checks = {
    'accountDeletionIncluded': b'account_deletion_service.dart' in kernel,
    'forumSafetyIncluded': b'forum_safety_widgets.dart' in kernel,
    'appCheckServiceRemoved': b'app_check_service.dart' not in kernel,
    'appCheckFlutterPackageRemoved': b'package:firebase_app_check/' not in kernel,
}
if not all(checks.values()):
    raise RuntimeError('APK does not match the requested account/forum rollback')
fingerprint = hashlib.sha256()
with apk.open('rb') as stream:
    for chunk in iter(lambda: stream.read(1048576), b''):
        fingerprint.update(chunk)
report = {'built': True, 'checks': checks, 'sha256': fingerprint.hexdigest(),
    'bytes': apk.stat().st_size, 'phoneVerified': False,
    'builtAtUtc': datetime.fromtimestamp(apk.stat().st_mtime, timezone.utc).isoformat()}
directory = root / 'reports/account-forum-rollback'
directory.mkdir(exist_ok=True, parents=True)
(directory / 'android-build.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
print(json.dumps(report, indent=2))
