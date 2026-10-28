# naru

naru is a private messaging app with a FastAPI backend and a
Flutter client.

It supports real-time direct messaging and context-aware translation into each
recipient’s selected language: Korean, Japanese, Simplified Chinese, English,
Spanish, French, German, or Italian. Translation is powered by OpenAI.

## Current Features

- Username and password registration and login
- Argon2id password hashing
- JWT access tokens with automatic refresh
- Token invalidation after password changes
- Editable display names
- Persistent direct conversation history
- Real-time WebSocket message delivery
- Read receipts
- Text, photo, file, voice memo, and call-event messages
- Message replies
- Conversation search
- Text message editing
- Message deletion within the 5-minute unsend window
- Text translation into the recipient’s language across all eight supported languages
- Conversation-context-aware translation
- Original text preserved alongside translated text
- Automatic voice memo transcription, followed by translation into the recipient’s language
- Real-time message, read receipt, edit, delete, and translation updates
- Flutter login and chat client
- iOS APNs message notifications with profile images, grouping, media previews,
  localized quick replies, badges, and lock-screen privacy controlled by iOS
- iOS PushKit and CallKit incoming-call presentation

## Technology Stack

- Python 3.11+
- FastAPI
- SQLAlchemy 2
- PostgreSQL
- asyncpg
- WebSockets
- OpenAI Responses API through the OpenAI Python client
- PyJWT
- pwdlib with Argon2
- python-dotenv
- Railway deployment configuration
- Flutter / Dart

## Project Structure

```text
app/
  routes/
    auth.py
    messages.py
    users.py
    websocket.py
  database.py
  dependencies.py
  main.py
  models.py
  passwords.py
  schemas.py
  security.py
  translation.py
  websocket_manager.py
scripts/
  create_user.py
  set_user_password.py
mobile/
  lib/
  test/
  pubspec.yaml
railway.toml
requirements.txt
```

## Deployment

The GitHub repository is the source of truth. Push changes to the branch
connected to the hosted backend, then let the deployment platform build and
restart the service.

The backend is configured for Railway in `railway.toml`:

```text
python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

Railway uses `/health` as the health check endpoint.

On startup, the backend creates the required PostgreSQL extensions and tables
if they do not already exist.

## Required Environment Variables

Configure these in the hosted backend environment:

- `DATABASE_URL`: PostgreSQL connection URL
- `JWT_SECRET`: long random signing secret for access tokens
- `OPENAI_API_KEY`: OpenAI API key
- `OPENAI_TRANSCRIPTION_MODEL`: voice transcription model (defaults to `gpt-transcribe`)
- `OPENAI_MODEL`: OpenAI model name (defaults to `gpt-5.4-mini`)
- `APNS_KEY_ID`: Apple APNs signing key ID
- `APNS_TEAM_ID`: Apple Developer team ID
- `APNS_BUNDLE_ID`: `com.planetowner.naru`
- `APNS_PRIVATE_KEY` or `APNS_PRIVATE_KEY_PATH`: APNs `.p8` private key

`DATABASE_URL` must point to PostgreSQL. `postgresql://` and `postgres://`
URLs are accepted and normalized to SQLAlchemy's asyncpg driver URL
automatically.

### Voice memo transcription

New voice memos are transcribed automatically after sending. The transcript is
stored in the existing message body, and processing status in message metadata;
no database migration is needed. Both participants receive transcript updates,
then the existing translation flow translates for the recipient's language.
The Flutter voice card shows the transcript below its player. Recipients can tap
the text to switch between the original and translation, as with text messages.

Transcription and translation failures have separate retries. The original audio
remains playable if either step fails. Existing recordings are not backfilled.
The [OpenAI file transcription API](https://developers.openai.com/api/docs/guides/speech-to-text)
accepts files up to 25 MB; larger recordings remain available for playback, but
their transcription fails. The backend needs access to the stored audio and the
configured transcription model through its existing OpenAI API key.

## User Administration

Friends can sign up in the app with a username, display name, password, and
password confirmation, then choose their language. Both the app and `POST /auth/register` check that the passwords
match. Usernames are trimmed, must contain 1–50 characters, and are unique
without regard to case. Passwords must be nonempty; their whitespace is preserved.
Display names are required, trimmed, and contain 1–100 Unicode characters.
Registration and display-name changes share the same validation. The saved
`display_name` is used consistently in chats and message/call notifications;
usernames identify accounts for login and friend lookup, and appear under display
names as `@username` in the shared profile row. No email is required.

Registration returns the same access/refresh-token session as `POST /auth/login`,
so a new account enters the chat immediately. Duplicate usernames return `409`,
and mismatched passwords return `400`. Existing accounts continue to log in with
their current passwords. This uses the existing users table without a migration.

Initial users are not committed to the repository. If an administrator needs to
create an account manually, run the existing scripts from a trusted environment
that has the backend variables loaded and can reach the intended database:

```bash
python -m scripts.create_user julia password123 --display-name "Julia" --language ko
python -m scripts.create_user friend password123 --display-name "Friend" --language zh-CN
```

To change a user's password:

```bash
python -m scripts.set_user_password USERNAME NEW_PASSWORD
```

The chat list (`GET /users`) includes only friends added by the current user.
`GET /users/search?username=...` finds an exact, case-insensitive username;
`POST /users/friends/{friend_id}` adds a one-way, idempotent relationship.
Existing accounts are not automatically added as friends. The `user_friends`
table is created by the existing startup schema initialization on deployment.

Settings saves display name, preferred language, and an optional owned photo
asset through `PATCH /users/me`. Photos use the existing media upload/complete
flow. The saved profile URL resolves the currently selected photo to a fresh
signed storage URL, including for iOS notification images. Previous profile
photo URLs stop resolving after replacement. Saving settings also updates the
stored app session and locale; notifications use the same saved account fields.

## Flutter Client Configuration

The Flutter app talks to the deployed backend. Pass the hosted API origin
through `API_BASE_URL`:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=https://YOUR_BACKEND_DOMAIN
```

Use the same `API_BASE_URL` when building release artifacts:

```bash
flutter build apk --dart-define=API_BASE_URL=https://YOUR_BACKEND_DOMAIN
flutter build ios --dart-define=API_BASE_URL=https://YOUR_BACKEND_DOMAIN
```

`API_BASE_URL` must be an absolute `http` or `https` URL.

See [docs/ios-notifications.md](docs/ios-notifications.md) for Apple Developer
capabilities, APNs configuration, payload behavior, and real-device checks.

## Localization

UI text and push notification templates share the eight `app/locales/app_*.arb`
files. Edit these source files, then run `flutter gen-l10n` from `mobile/`.
Flutter generates the Dart accessors in `mobile/lib/core/l10n/generated/`;
these generated files are excluded from Git. The server reads the same ARB files.

Before onboarding selection, the app follows the device language (English for
unsupported languages). Selection updates the UI immediately; after login, the
account language takes priority. Names, counts, and dates use placeholders and
shared formatters. Message and media timestamps share locale-aware formatting
and the device’s 24-hour setting. Read receipts continue to show elapsed weeks
after 30 days. The server model and manual user-creation script default to
English when no language is supplied; normal signup requires a selected language.
The startup schema compatibility step updates the database default without
changing existing users’ language selections.

iOS permission descriptions live in `mobile/ios/Runner/InfoPlist.xcstrings`,
because iOS reads native bundle resources rather than Flutter’s ARB catalog.
The catalog covers the same eight languages. These system dialogs follow the
iOS app language setting, independently of the onboarding language selection.

Link previews request the viewing account's language through `Accept-Language`.
The server stores language variants in the existing message metadata, and the app
uses the same resolver for REST, live messages, and cached history. Device fetching
for sites that block the server also uses the account language. This requests a
localized page when the site supports it; it does not translate the page itself.

## Tests and Checks

Backend:

```bash
python -m compileall app scripts
python -m unittest discover -s tests -p 'test_*.py'
```

Flutter:

```bash
cd mobile
flutter analyze
flutter test
```

## Files Excluded From Git

The following files are intentionally excluded from Git:

- `.env`
- `.env.*`
- `.jwt_secret`
- `.venv/`
- Python cache files
- Database dumps
- Editor and operating system files

Production database credentials and dumps may contain user accounts, password
hashes, and private message history, so they must not be uploaded to GitHub.

## Message Translation Flow

1. The original text message is saved immediately.
2. A `message.created` WebSocket event is sent to both users.
3. OpenAI translates the message in the background.
4. The translated text and translation metadata are saved.
5. A `message.translation.updated` WebSocket event is sent to both users.

If translation fails, the original message remains stored and available.

## Main WebSocket Events

### Connection established

```json
{
  "type": "connected",
  "user": {
    "id": "11111111-1111-4111-8111-111111111111",
    "username": "example",
    "display_name": "Example"
  }
}
```

### Message created

```json
{
  "type": "message.created",
  "message": {
    "id": "33333333-3333-4333-8333-333333333333",
    "translation_status": "pending"
  }
}
```

### Translation updated

```json
{
  "type": "message.translation.updated",
  "message": {
    "id": "33333333-3333-4333-8333-333333333333",
    "translated_content": "Translated message",
    "translation_status": "completed",
    "translation_provider": "openai"
  }
}
```

### Messages read

```json
{
  "type": "messages.read",
  "reader_id": "11111111-1111-4111-8111-111111111111",
  "sender_id": "22222222-2222-4222-8222-222222222222",
  "message_ids": ["33333333-3333-4333-8333-333333333333"],
  "read_at": "2026-06-29T12:00:00+00:00"
}
```

### Message updated

```json
{
  "type": "message.updated",
  "message": {
    "id": "33333333-3333-4333-8333-333333333333",
    "content": "Edited text",
    "translation_status": "pending"
  }
}
```

### Message deleted

```json
{
  "type": "message.deleted",
  "message_id": "33333333-3333-4333-8333-333333333333"
}
```

## Important Development Note

The repository does not include database dumps or production user accounts.

The database schema is created automatically when the hosted backend starts
with `DATABASE_URL` configured. Users can then create their accounts from the
app's Sign up screen.

## Project Status

The backend authentication, messaging, read receipts, WebSocket delivery,
translation into the recipient’s selected language, and Flutter client login/chat
flows are implemented.
