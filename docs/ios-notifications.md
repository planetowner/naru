# iOS Notifications

naru uses iOS-rendered notification and call interfaces. It does not draw
a look-alike notification view inside Flutter. The implementation is split
between the FastAPI APNs sender, the Runner notification bridge, a Notification
Service Extension, and PushKit/CallKit.

## Implemented behavior

- Each direct message is delivered as its own alert. No APNs collapse ID is
  sent, so a later message does not replace an earlier one.
- Alerts from the same direct conversation share `thread-id`, which lets iOS
  apply its configured stack/list/count grouping.
- The Notification Service Extension converts an alert to an
  `INSendMessageIntent` communication notification and downloads the sender's
  profile image.
- Text and link alerts use the original message body. iOS controls visible
  truncation and expansion.
- Photo alerts show a localized summary and download the first photo or
  thumbnail as a notification attachment. Video and voice-memo alerts use a
  localized summary without playback or a media thumbnail.
- Text, photo, video, file, and voice-memo alerts expose a text-input reply
  action. The native bridge can post the reply even when Flutter was not
  already running.
- The app badge is the recipient's current unread message count.
- Tapping an alert opens the direct conversation for its sender after login.
- Lock-screen preview hiding and Face ID reveal are controlled by the user's
  iOS **Show Previews** setting. naru does not bypass that privacy policy.
- An initial call event is sent with a PushKit token and immediately reported
  to CallKit. After that initial VoIP push, call termination is delivered over
  the authenticated `/ws` connection. A missed or unanswered call is then sent
  as a normal APNs alert.

Notification titles use the sender’s saved display name. Summaries use the
recipient’s `preferred_language` and the shared `app/locales/app_*.arb` catalog
(Korean, Japanese, Simplified Chinese, English, Spanish, French, German, Italian).
Unsupported language values fall back to English.

| Event | Shared translation key |
| --- | --- |
| Photo | `notificationPhoto` |
| Video | `notificationVideo` |
| File | `notificationNamedFile` / `notificationFile` |
| Voice memo | `notificationVoiceMemo` |
| Missed call | `notificationMissedCall` |
| Reply | `reply` |
| Send | `send` |

Reply and Send action titles come from the app’s current localization through
`NotificationBridge`; the server and app reuse the same catalog.

## Apple Developer setup

The repository contains the targets and entitlement files, but the matching
App ID capabilities and provisioning profiles must also exist in the Apple
Developer account for team `57X5XDTF4Q`.

1. For `com.planetowner.naru`, enable **Push Notifications** and
   **Communication Notifications**.
2. Keep the Runner background modes for **Voice over IP** and
   **Remote notifications** enabled.
3. Create or refresh the Runner development and distribution provisioning
   profiles after enabling those capabilities.
4. Create the extension App ID
   `com.planetowner.naru.NotificationService`, enable
   **Communication Notifications**, and create its provisioning profiles.
5. Create an APNs token-signing key (`.p8`) that can send notifications for the
   app. Keep the key out of Git.
6. In Xcode, confirm that both targets resolve to the intended team and that
   automatic signing can select profiles containing the committed
   entitlements.

## Backend configuration

Set the following on the backend:

```text
APNS_KEY_ID=YOUR_KEY_ID
APNS_TEAM_ID=57X5XDTF4Q
APNS_BUNDLE_ID=com.planetowner.naru
APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

`APNS_PRIVATE_KEY_PATH=/secure/path/AuthKey_XXXX.p8` may be used instead of
`APNS_PRIVATE_KEY`. The production service must be able to read that path.
The app registers the `aps-environment` embedded in its provisioning profile.
Locally installed builds commonly use `development`, while TestFlight and App
Store distribution builds use `production`. Distribution builds without an
embedded profile use `production`. A token is always sent to the APNs host
matching the environment stored during registration.

On backend startup, the existing compatibility step adds the new installation,
VoIP-token, bundle-ID, and APNs-environment columns and their indexes to
`user_devices`.

## Call event contract

The existing message API starts an incoming voice call with:

```json
{
  "recipient_id": "RECIPIENT_UUID",
  "content": "",
  "message_type": "call",
  "metadata": {
    "kind": "voice",
    "outcome": "started",
    "duration_ms": 0
  }
}
```

The start message UUID is also the CallKit UUID. The sender may finish it with
`ended`, `cancelled`, or `no_answer`; the recipient may finish it with `ended`
or `missed` through `PATCH /messages/{message_id}/call-outcome`. Conflicting
final outcomes return HTTP 409.

The start record remains `started`. Finishing creates a separate call message
with a new UUID and the result timestamp, and returns that result from the PATCH
request. The result metadata includes `call_start_message_id`, which the native
CallKit handler uses to end the original call when receiving `message.created`.
The same event updates both participants and the recipient's unread count.
Legacy `message.updated` signaling remains supported by the native handler.

The server locks the start record and stores `call_result_message_id` in its
internal message metadata. Retrying the same outcome returns the saved result
without another record, realtime event, or push. An already finished record
from the previous implementation is returned as-is; existing history is not
rewritten. These links use the existing JSON metadata column, so no schema
migration is required. The server and app updates must both be released.

A queued start notification is skipped if the call result is already saved.
Missed/unanswered call notifications use the result message UUID.

The notification layer implements system call presentation and signaling. The
repository does not contain an RTC audio transport, media server, or audio
session that connects two answered callers. A production voice conversation
still requires that separate call-media layer before the CallKit answer action
should be considered connected.

## Commands to run locally

Run these manually from the repository root. They are intentionally listed
here because the project instructions require the developer, not Codex, to
execute terminal commands.

```bash
cd /Users/june/Desktop/projects/naru
python3 -m pip install -r requirements.txt
python3 -m compileall app scripts
python3 -m unittest tests.test_translation tests.test_notifications
git diff --check

cd /Users/june/Desktop/projects/naru/mobile
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build ios --debug --no-codesign \
  --dart-define=API_BASE_URL=https://YOUR_BACKEND_DOMAIN
```

`flutter build ios --debug --no-codesign` verifies compilation but not signing
or entitlement availability. Open `mobile/ios/Runner.xcodeproj` and run the
Runner scheme on a physical iPhone to verify APNs, PushKit, CallKit, Focus,
Face ID preview reveal, notification grouping, sounds, and badge behavior.
PushKit/CallKit delivery must be validated on a real device.

## Real-device matrix

Verify each item with the app in foreground, background, force-quit where iOS
permits delivery, and on the locked screen:

1. Text in all eight supported languages, including a long message and mixed-language text.
2. Photo, video, and voice memo summaries; only photo has a right-side and
   expanded attachment.
3. Reply from a temporary banner and from the expanded lock-screen alert.
4. Three sequential messages remain separate and expand from one iOS group.
5. **Show Previews: When Unlocked** hides content before Face ID and reveals it
   after authentication.
6. Incoming voice call while locked and unlocked, answer, reject, caller
   cancel, and caller timeout.
7. Missed-call alerts in each recipient’s selected language across all eight languages.
8. Notification-disabled, banner-disabled, sound-disabled, and badge-disabled
   system settings.
