import os
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, Mock, patch
from uuid import uuid4

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test")
os.environ.setdefault("OPENAI_API_KEY", "test-openai-api-key")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret")

from fastapi import BackgroundTasks, HTTPException
from app import transcription
from app.models import DirectConversation, MediaAsset, MediaKind, Message, MessageKind, MessageTranslation, TranslationStatus, User
from app.object_storage import ObjectStorageClient
from app.routes import messages as routes
from app.schemas import MessageCreate
from app.translation import TranslationResult


class TranscriptionClientTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.asset = MediaAsset(
            id=uuid4(), storage_key="voice/recording.m4a", upload_status="complete",
            file_name="recording.m4a", mime_type="audio/mp4", size_bytes=4,
        )
        self.storage = SimpleNamespace(read_object=Mock(return_value=b"test"))
        self.enterContext(patch.object(transcription, "get_object_storage_client", return_value=self.storage))
        self.create = self.enterContext(patch.object(
            transcription.openai_client.audio.transcriptions, "create",
            AsyncMock(return_value=SimpleNamespace(text="  你好  ")),
        ))

    async def test_transcribes_original_audio_with_filename_and_content_type(self):
        self.assertEqual(await transcription.transcribe_voice_memo(self.asset), "你好")
        self.create.assert_awaited_once_with(
            model=transcription.TRANSCRIPTION_MODEL,
            file=("recording.m4a", b"test", "audio/mp4"),
        )
        self.storage.read_object.assert_called_once_with(
            storage_key=self.asset.storage_key, max_bytes=transcription.MAX_TRANSCRIPTION_BYTES,
        )

    async def test_empty_speech_is_a_failure(self):
        self.create.return_value.text = "  "
        with self.assertRaisesRegex(ValueError, "No speech"):
            await transcription.transcribe_voice_memo(self.asset)

    async def test_oversized_audio_is_not_downloaded_or_sent(self):
        self.asset.size_bytes = transcription.MAX_TRANSCRIPTION_BYTES + 1
        with self.assertRaisesRegex(ValueError, "25 MB"):
            await transcription.transcribe_voice_memo(self.asset)
        self.storage.read_object.assert_not_called()
        self.create.assert_not_awaited()

    def test_storage_checks_actual_bytes_and_always_closes_stream(self):
        storage = ObjectStorageClient.__new__(ObjectStorageClient)
        storage._settings = SimpleNamespace(bucket="test")
        body = Mock(read=Mock(return_value=b"12345"))
        storage._client = Mock(get_object=Mock(return_value={"Body": body}))
        with self.assertRaisesRegex(ValueError, "size limit"):
            storage.read_object(storage_key="voice", max_bytes=4)
        body.read.assert_called_once_with(5)
        body.close.assert_called_once()


class VoiceTranscriptionFlowTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.sender = User(id=uuid4(), preferred_language="zh-CN", display_name="Sender")
        self.recipient = User(id=uuid4(), preferred_language="ko", display_name="Recipient")
        self.direct = DirectConversation(
            conversation_id=uuid4(), user_one_id=self.sender.id, user_two_id=self.recipient.id,
        )
        self.message = Message(
            id=uuid4(), conversation_id=self.direct.conversation_id, sender_id=self.sender.id,
            kind=MessageKind.VOICE_MEMO, body="", source_language="zh-CN",
            metadata_json={"transcription_status": "pending", "waveform_samples": [0.2, 0.8]},
            created_at=datetime.now(timezone.utc),
        )
        self.asset = MediaAsset(
            id=uuid4(), kind=MediaKind.VOICE_MEMO, storage_key="voice.m4a",
            upload_status="complete", metadata_json={},
        )
        async def get(model, key, **kwargs):
            return {Message: self.message, DirectConversation: self.direct, User: self.recipient}.get(model)
        self.session = SimpleNamespace(
            get=AsyncMock(side_effect=get), scalar=AsyncMock(return_value=self.asset),
            scalars=AsyncMock(return_value=[]), execute=AsyncMock(return_value=[]),
            add=Mock(), flush=AsyncMock(), commit=AsyncMock(), refresh=AsyncMock(),
        )
        context = MagicMock()
        context.__aenter__ = AsyncMock(return_value=self.session)
        context.__aexit__ = AsyncMock(return_value=False)
        self.enterContext(patch.object(routes, "SessionLocal", return_value=context))
        self.enterContext(patch.object(routes, "load_direct_users", AsyncMock(return_value={
            self.sender.id: self.sender, self.recipient.id: self.recipient,
        })))
        self.transcribe = self.enterContext(patch.object(routes, "transcribe_voice_memo", AsyncMock(return_value="你好")))
        self.translate = self.enterContext(patch.object(routes, "translate_message", AsyncMock(return_value=TranslationResult(
            translated_text="안녕하세요", source_language="zh-CN", target_language="ko", provider="openai", model="test-model",
        ))))
        self.send = self.enterContext(patch.object(routes, "send_to_direct_participants", AsyncMock()))

    async def test_transcript_preserves_sender_language_before_shared_translation(self):
        cases = (
            ("ko", "你好"),
            ("ja", "今日は晴れです"),
            ("zh-CN", "안녕하세요"),
            ("en", "안녕하세요"),
            ("es", "你好"),
            ("fr", "안녕하세요"),
            ("de", "你好"),
            ("it", "안녕하세요"),
        )
        for source_language, transcript in cases:
            with self.subTest(source_language=source_language, transcript=transcript):
                self.sender.preferred_language = source_language
                self.recipient.preferred_language = "es"
                self.message.source_language = source_language
                self.message.metadata_json = {
                    "transcription_status": "pending", "waveform_samples": [0.2, 0.8],
                }
                self.transcribe.return_value = transcript
                self.translate.reset_mock()
                self.translate.return_value = TranslationResult(
                    translated_text="Hola", source_language=source_language,
                    target_language="es", provider="openai", model="test-model",
                )
                self.send.reset_mock()
                stored_translations = []
                def add(record):
                    if isinstance(record, MessageTranslation):
                        stored_translations.append(record)
                async def scalar(statement):
                    table = statement.column_descriptions[0]["entity"]
                    if table is MediaAsset:
                        return self.asset
                    if table is DirectConversation:
                        return self.direct
                    return stored_translations[0] if stored_translations else None
                async def scalars(statement):
                    table = statement.column_descriptions[0]["entity"]
                    return stored_translations if table is MessageTranslation else []
                self.session.add.side_effect = add
                self.session.scalar.side_effect = scalar
                self.session.scalars.side_effect = scalars

                await routes.transcribe_and_publish_message(self.message.id)

                self.assertEqual(self.message.body, transcript)
                self.assertEqual(self.message.source_language, source_language)
                self.assertEqual(self.message.metadata_json["waveform_samples"], [0.2, 0.8])
                self.assertEqual(stored_translations[0].source_language, source_language)
                self.assertEqual(stored_translations[0].target_language, "es")
                events = [call.args[1] for call in self.send.await_args_list]
                self.assertEqual([event["type"] for event in events], ["message.updated", "message.translation.updated"])
                self.assertEqual(events[0]["message"]["transcription_status"], "completed")
                self.assertEqual(events[0]["message"]["translation_status"], "none")
                self.assertEqual(events[1]["message"]["translated_content"], "Hola")
                self.assertEqual(events[1]["message"]["translation_status"], "completed")
                for event in events:
                    self.assertEqual(event["message"]["source_language"], source_language)
                self.translate.assert_awaited_once_with(
                    text=transcript, source_language=source_language,
                    target_language="es", context_messages=[],
                )
                self.session.get.assert_any_await(Message, self.message.id, with_for_update=True)

    async def test_recipient_language_transcript_skips_translation(self):
        self.transcribe.return_value = "안녕하세요"

        async def scalar(statement):
            entity = statement.column_descriptions[0]["entity"]
            return {MediaAsset: self.asset, DirectConversation: self.direct}.get(entity)

        self.session.scalar.side_effect = scalar
        await routes.transcribe_and_publish_message(self.message.id)

        self.translate.assert_not_awaited()
        self.session.add.assert_not_called()
        self.send.assert_awaited_once()
        event = self.send.await_args.args[1]
        self.assertEqual(event["type"], "message.updated")
        self.assertEqual(event["message"]["transcription_status"], "completed")
        self.assertEqual(event["message"]["translation_status"], "completed")
        self.assertEqual(event["message"]["content"], "안녕하세요")
        self.assertEqual(event["message"]["translated_content"], "안녕하세요")

    async def test_transcription_failure_keeps_recording_and_does_not_translate(self):
        self.transcribe.side_effect = RuntimeError("provider unavailable")
        with self.assertLogs(routes.logger, level="ERROR"):
            await routes.transcribe_and_publish_message(self.message.id)
        self.assertEqual(self.message.metadata_json["transcription_status"], "failed")
        self.assertEqual(self.message.body, "")
        self.assertEqual(self.message.kind, MessageKind.VOICE_MEMO)
        self.translate.assert_not_awaited()
        self.assertEqual(self.send.await_args.args[1]["message"]["transcription_status"], "failed")

    async def test_completed_or_deleted_voice_is_not_transcribed_again(self):
        for state, deleted in [("completed", None), ("pending", datetime.now(timezone.utc))]:
            self.message.metadata_json["transcription_status"] = state
            self.message.deleted_at = deleted
            await routes.transcribe_and_publish_message(self.message.id)
        self.transcribe.assert_not_awaited()
        self.send.assert_not_awaited()

    async def test_retry_checks_participant_and_deduplicates_pending_and_completed(self):
        self.message.metadata_json["transcription_status"] = "failed"
        with self.assertRaises(HTTPException) as error:
            await routes.retry_message_transcription(self.message.id, BackgroundTasks(), SimpleNamespace(id=uuid4()), self.session)
        self.assertEqual(error.exception.status_code, 403)
        for user in [self.sender, self.recipient]:
            self.message.metadata_json["transcription_status"] = "failed"
            tasks = BackgroundTasks()
            result = await routes.retry_message_transcription(self.message.id, tasks, user, self.session)
            self.assertEqual(result.transcription_status, "pending")
            self.assertEqual(len(tasks.tasks), 1)
        for state in ["pending", "completed"]:
            self.message.metadata_json["transcription_status"] = state
            tasks = BackgroundTasks()
            await routes.retry_message_transcription(self.message.id, tasks, self.sender, self.session)
            self.assertEqual(tasks.tasks, [])

    async def test_translation_retry_preserves_transcript_when_provider_fails(self):
        self.message.metadata_json["transcription_status"] = "completed"
        self.message.body = "你好"
        stored = MessageTranslation(message_id=self.message.id, source_language="zh-CN", target_language="ko", status=TranslationStatus.FAILED)
        self.session.scalar.side_effect = [self.direct, stored]
        self.translate.side_effect = RuntimeError("provider unavailable")
        with self.assertLogs(routes.logger, level="ERROR"):
            result = await routes.retry_message_translation(self.message.id, self.recipient, self.session)
        self.assertEqual(stored.status, TranslationStatus.FAILED)
        self.assertEqual(result.content, "你好")
        self.assertEqual(result.transcription_status, "completed")
        self.transcribe.assert_not_awaited()

    async def test_read_exposes_voice_translation_and_preserves_same_language_result(self):
        self.message.body = "你好"
        self.message.metadata_json["transcription_status"] = "completed"
        stored = MessageTranslation(message_id=self.message.id, source_language="zh-CN", target_language="ko", status=TranslationStatus.COMPLETED, translated_body="안녕하세요")
        self.session.scalars.side_effect = [[], [stored], []]
        result = await routes.build_single_message_read(self.session, self.message, direct_conversation=self.direct)
        self.assertEqual(result.translated_content, "안녕하세요")
        self.message.body = "안녕하세요"
        self.session.scalars.side_effect = [[], [stored], []]
        result = await routes.build_single_message_read(self.session, self.message, direct_conversation=self.direct)
        self.assertEqual(result.translated_content, "안녕하세요")
        self.assertEqual(result.translation_status, "completed")

    async def test_new_voice_schedules_transcription_and_ignores_client_transcript(self):
        self.sender.preferred_language = "ja"
        created = []
        def add(record):
            if isinstance(record, Message):
                record.id = uuid4()
                record.created_at = datetime.now(timezone.utc)
                created.append(record)
        self.session.add.side_effect = add
        with (
            patch.object(routes, "get_direct_conversation", AsyncMock(return_value=self.direct)),
            patch.object(routes, "add_message_payload_records", AsyncMock()),
            patch.object(routes.connection_manager, "send_to_user", AsyncMock()) as send_created,
            patch.object(routes.unread_counts_event_publisher, "send_event", AsyncMock()),
        ):
            tasks = BackgroundTasks()
            result = await routes.create_message(
                MessageCreate(recipient_id=self.recipient.id, message_type="voice_memo", content="untrusted transcript", metadata={"media_asset_ids": [str(self.asset.id)], "transcription_status": "completed"}),
                tasks, self.sender, self.session,
            )
        self.assertEqual(result.content, "")
        self.assertEqual(created[0].source_language, self.sender.preferred_language)
        self.assertEqual(result.source_language, self.sender.preferred_language)
        self.assertEqual(result.transcription_status, "pending")
        created_event = send_created.await_args.kwargs["data"]
        self.assertEqual(created_event["type"], "message.created")
        self.assertEqual(created_event["message"]["transcription_status"], "pending")
        self.assertEqual([task.func for task in tasks.tasks], [routes.send_message_notification, routes.transcribe_and_publish_message])
        self.transcribe.assert_not_awaited()


if __name__ == "__main__":
    unittest.main()
