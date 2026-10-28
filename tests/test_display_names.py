import os
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch
from uuid import uuid4

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret-with-at-least-32-bytes")

from app import notifications
from app.models import CallKind, CallOutcome, ConversationMember, DirectConversation, Message, MessageCallEvent, MessageKind, User
from app.routes.users import list_users


class DisplayNameTests(unittest.IsolatedAsyncioTestCase):
    async def test_every_viewer_receives_the_same_saved_display_names(self):
        users = [
            User(id=uuid4(), username=username, display_name=name, preferred_language="en")
            for username, name in (("junebabo", "Alex"), ("liababo", "Sam"), ("yunjung5437", "Taylor"))
        ]
        session = SimpleNamespace(scalars=AsyncMock(return_value=users))
        for viewer in users:
            result = await list_users(session, viewer)
            self.assertEqual([user.display_name for user in result], ["Alex", "Sam", "Taylor"])
            for user in result:
                self.assertNotIn("viewer_display_name", user.model_dump())

    async def test_message_and_call_notifications_use_the_current_saved_name(self):
        sender_id, recipient_id, conversation_id, message_id = [uuid4() for _ in range(4)]
        sender = User(id=sender_id, username="junebabo", display_name="Alex", preferred_language="en")
        recipient = User(id=recipient_id, username="liababo", display_name="Sam", preferred_language="ko")
        message = SimpleNamespace(id=message_id, sender_id=sender_id, conversation_id=conversation_id,
                                  kind=MessageKind.TEXT, body="Hello", deleted_at=None, metadata_json={})
        records = {
            (Message, message_id): message,
            (DirectConversation, conversation_id): SimpleNamespace(user_one_id=sender_id, user_two_id=recipient_id),
            (User, sender_id): sender,
            (User, recipient_id): recipient,
            (ConversationMember, (conversation_id, recipient_id)): SimpleNamespace(left_at=None, muted_until=None),
            (MessageCallEvent, message_id): None,
        }
        session = AsyncMock()
        session.get.side_effect = lambda model, key: records.get((model, key))
        session.scalars.return_value = [SimpleNamespace(push_token="test-alert", voip_push_token="test-call",
                                                       apns_environment="development")]
        context = AsyncMock()
        context.__aenter__.return_value = session
        client = Mock(voip_topic="com.test.naru.voip")
        client.send = AsyncMock(return_value=notifications.APNSResult(succeeded=True, status_code=200))
        # DB와 APNs 전송을 대신하고 실제 알림 조립 경로를 검사해요.
        with patch.object(notifications, "load_apns_settings", return_value=SimpleNamespace(bundle_id="com.test.naru")), \
                patch.object(notifications, "SessionLocal", return_value=context), \
                patch.object(notifications, "APNSClient", return_value=client), \
                patch.object(notifications, "load_unread_counts_by_sender", AsyncMock(return_value={sender_id: 1})):
            for name in ("Alex", "새 표시 이름 🌿"):
                sender.display_name = name
                for kind in (MessageKind.TEXT, MessageKind.CALL):
                    with self.subTest(name=name, kind=kind):
                        message.kind = kind
                        records[(MessageCallEvent, message_id)] = (
                            SimpleNamespace(kind=CallKind.VOICE, outcome=CallOutcome.STARTED)
                            if kind == MessageKind.CALL else None
                        )
                        client.send.reset_mock()
                        await notifications.send_message_notification(message_id)
                        client.send.assert_awaited_once()
                        payload = client.send.call_args.kwargs["payload"]
                        if kind == MessageKind.CALL:
                            self.assertEqual(payload["naru_call"]["caller_name"], name)
                        else:
                            self.assertEqual(payload["aps"]["alert"]["title"], name)
                            self.assertEqual(payload["naru"]["sender_name"], name)


if __name__ == "__main__":
    unittest.main()
