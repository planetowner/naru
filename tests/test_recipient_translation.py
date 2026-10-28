import os
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch
from uuid import uuid4

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test")
os.environ.setdefault("OPENAI_API_KEY", "test-openai-api-key")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret-with-at-least-32-bytes")

from app.models import DirectConversation, Message, MessageKind, MessageTranslation, TranslationStatus, User
from app.routes import messages as routes
from app.translation import TranslationResult


class RecipientTranslationTests(unittest.IsolatedAsyncioTestCase):
    async def test_same_spanish_receiver_gets_korean_and_chinese_in_spanish(self):
        spanish = User(id=uuid4(), preferred_language="es", display_name="Spanish speaker")
        for source, body in (("ko", "안녕하세요"), ("zh-CN", "你好")):
            sender = User(id=uuid4(), preferred_language=source, display_name=source)
            await self.assert_delivery(sender, spanish, body, "Hola")

    async def test_spanish_sender_uses_each_receivers_language(self):
        spanish = User(id=uuid4(), preferred_language="es", display_name="Spanish speaker")
        for target, translated in (("ko", "안녕하세요"), ("zh-CN", "你好"), ("ja", "こんにちは"),
                                   ("en", "Hello"), ("fr", "Bonjour"), ("de", "Hallo"), ("it", "Ciao")):
            receiver = User(id=uuid4(), preferred_language=target, display_name=target)
            await self.assert_delivery(spanish, receiver, "Hola", translated)

    async def assert_delivery(self, sender, receiver, body, translated):
        direct = DirectConversation(conversation_id=uuid4(), user_one_id=sender.id, user_two_id=receiver.id)
        message = Message(id=uuid4(), conversation_id=direct.conversation_id, sender_id=sender.id,
                          kind=MessageKind.TEXT, body=body, source_language=sender.preferred_language,
                          metadata_json={}, created_at=datetime.now(timezone.utc))
        stored = []
        session = SimpleNamespace(scalar=AsyncMock(return_value=None), scalars=AsyncMock(return_value=[]),
                                  execute=AsyncMock(return_value=[]), add=Mock(side_effect=stored.append), flush=AsyncMock())
        translator = AsyncMock(return_value=TranslationResult(translated, sender.preferred_language,
                               receiver.preferred_language, "openai", "test-model"))
        with patch.object(routes, "load_direct_users", AsyncMock(return_value={sender.id: sender, receiver.id: receiver})), \
                patch.object(routes, "translate_message", translator):
            untranslated = await routes.build_single_message_read(session, message, direct_conversation=direct)
            self.assertEqual(untranslated.translation_status, "none")
            self.assertIsNone(untranslated.translated_content)
            self.assertTrue(await routes.execute_message_translation(session, message, direct_conversation=direct))
            translator.assert_awaited_once_with(text=body, source_language=sender.preferred_language,
                                               target_language=receiver.preferred_language, context_messages=[])
            self.assertEqual(len(stored), 1)
            self.assertIsInstance(stored[0], MessageTranslation)
            self.assertEqual(stored[0].target_language, receiver.preferred_language)
            self.assertEqual(stored[0].status, TranslationStatus.COMPLETED)
            # 다른 대상 언어의 번역이 함께 있어도 수신자의 번역만 읽어요.
            wrong = MessageTranslation(message_id=message.id, source_language=sender.preferred_language,
                                       target_language="es" if receiver.preferred_language != "es" else "en",
                                       status=TranslationStatus.COMPLETED, translated_body="wrong language")
            session.scalars.side_effect = [[], [wrong, *stored], []]
            result = await routes.build_single_message_read(session, message, direct_conversation=direct)
            self.assertEqual(result.recipient_id, receiver.id)
            self.assertEqual(result.translated_language, receiver.preferred_language)
            self.assertEqual(result.translated_content, translated)
            self.assertEqual(result.content, body)
