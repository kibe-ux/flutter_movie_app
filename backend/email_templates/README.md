# Movie Hub account emails

## Status

`password_reset.html` is a prepared email-message template. It is not automatically loaded by the backend or Flutter app. Saving this file does not change emails sent by Firebase. No live Firebase settings, credentials, authentication methods, or reset links have been changed.

## Email verification branding

An email with the subject `Verify your email for project-609797109604` and a project-number team signature indicates that the message was sent with Firebase's generic app branding. The Flutter verification-status refresh does not change that branding. Existing inbox messages will not change after updating settings.

1. Open [the existing project's settings](https://console.firebase.google.com/project/my-flutter-app-hezra-202-12dc9/settings/general) and set **Public-facing name** to **Movie Hub**. This supplies Firebase's `%APP_NAME%` placeholder; keep the project ID and app registrations unchanged.
2. Open **Authentication > Templates > Email address verification** and edit the template.
3. Set **Sender name** to **Movie Hub** and **Subject** to **Verify your email for Movie Hub**.
4. Save the settings. Firebase's built-in verification message body has editing restrictions; its documented message customization is for password-reset emails. Changing the public-facing name supplies the app name in the default verification body. The prepared password-reset HTML is not a verification template.
5. In the app's Profile screen, choose **Send verification** and inspect the newly delivered email. Confirm its subject, sender display name, and team signature use Movie Hub. Follow the fresh link, return to Profile, and confirm **Email verified** appears; **Check status** also refreshes it manually.

The default `noreply@...firebaseapp.com` address and Firebase action-link domain remain until a custom domain is configured. A branded subject and app name do not replace them. Custom verification-message HTML requires generating verification links server-side and sending them through an email provider, rather than the current `user.sendEmailVerification()` call.

Local widget tests in `test/screens/profile_verification_test.dart` cover refreshing stale verification status, refreshing when the app resumes, and keeping an account unverified after merely sending an email. They do not verify live Firebase templates, delivery, or action-link completion. Confirm those with a fresh message; do not store real verification codes in templates or test fixtures.

## Password reset: apply in Firebase Console

1. Open the existing Movie Hub Firebase project.
2. In Project settings, change the **Public-facing name** to **Movie Hub**. Keep the existing project ID and app registrations.
3. Open **Authentication > Templates > Password reset** and edit the template.
4. Set **Sender name** to **Movie Hub**.
5. Set **Subject** to **Reset your Movie Hub password**.
6. Replace the message body with `password_reset.html` using the template editor's HTML/source editing capability where available. Retain `%LINK%` exactly; Firebase replaces it with the recipient's reset link. If the editor limits styling, keep the branded wording and `<a href="%LINK%">Reset password</a>` action, then preview the saved result. Do not paste HTML into a plain-text-only editor.
7. Keep the current sender address and action URL unless you have already configured a verified custom sender domain or a working custom action handler.
8. Save the template. Request a fresh reset email for your own test account from the app, and check the subject, sender name, button rendering, and password-reset flow. An email already in an inbox will not change.

Use Firebase's preview and a real test message to confirm how the template editor and email client preserve the HTML. The app's existing Firebase reset-email call can remain unchanged.

## Expected result

- Subject: **Reset your Movie Hub password**
- Sender display name: **Movie Hub**
- Branded black, burgundy, and gold message
- A **Reset password** button instead of a long URL displayed as message text
- No project-number branding or recipient address repeated in the message body

The underlying button still contains Firebase's generated URL and one-time reset code. Recipients and email clients can inspect its destination. Styling does not remove those parameters or make the link secret. No real reset URLs, account email addresses, API values, or tokens belong in this template.

## Optional custom domain

A branded sender address and branded link domain require a domain you control and Firebase's domain-verification setup. This is separate from changing the sender display name and message. Use **Customize domain** in Authentication templates and complete the DNS verification before applying it. Do not invent a sender address or replace the action URL with an unimplemented page.

For complete control beyond the built-in template editor, Firebase also supports generating action links with the Admin SDK and delivering custom mail through your own email service. That requires separate server-side email delivery setup; it is not needed for the basic branding change above.

## References

- [Firebase: customize account management emails](https://support.google.com/firebase/answer/7000714?hl=en)
- [Firebase: custom email domains](https://firebase.google.com/docs/auth/email-custom-domain)
- [Firebase: generating email action links](https://firebase.google.com/docs/auth/admin/email-action-links)
