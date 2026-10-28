import os
import unittest
from types import SimpleNamespace
from uuid import uuid4

os.environ.setdefault('DATABASE_URL', 'postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test')
os.environ.setdefault('JWT_SECRET', 'test-jwt-secret-with-at-least-32-bytes')
os.environ.setdefault('OPENAI_API_KEY', 'test-openai-api-key')

from app.models import MessageKind, CallOutcome
from app.routes.messages import build_reply_reference


class ReplyLocalizationTests(unittest.TestCase):
    def test_reply_reference_preserves_user_text_and_exposes_media_kind(self):
        for kind in (MessageKind.TEXT, MessageKind.PHOTO, MessageKind.CALL):
            message = SimpleNamespace(id=uuid4(), sender_id=uuid4(), kind=kind, body='Photo')
            event = SimpleNamespace(outcome=CallOutcome.CANCELLED) if kind == MessageKind.CALL else None
            reply = build_reply_reference(message, [(None, None)] * 3, event)
            self.assertEqual(reply.content, 'Photo')
            self.assertEqual(reply.message_type, kind.value)
            self.assertEqual(reply.photo_count, 3 if kind == MessageKind.PHOTO else 0)
            self.assertEqual(reply.call_outcome, 'cancelled' if event else None)
        self.assertIsNone(build_reply_reference(None, [], None))
