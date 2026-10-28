import os
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch
from uuid import uuid4

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test")
os.environ.setdefault("OPENAI_API_KEY", "test-openai-api-key")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret")

from fastapi import BackgroundTasks, HTTPException
from app.models import CallKind, CallOutcome, Conversation, ConversationMember, DirectConversation, Message, MessageCallEvent, MessageKind, User
from app import notifications
from app.routes import messages as routes
from app.schemas import CallOutcomeUpdate


class CallOutcomeTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.prepare_records()
        async def build_read(session, message, **kwargs):
            metadata = routes.build_metadata(message, [], self.records[(MessageCallEvent, message.id)])
            return SimpleNamespace(
                id=message.id, sender_id=message.sender_id, metadata=metadata,
                created_at=message.created_at,
                model_dump=lambda **_: {
                    "id": str(message.id), "sender_id": str(message.sender_id),
                    "metadata": metadata,
                },
            )
        self.read = self.enterContext(patch.object(routes, "build_single_message_read", AsyncMock(side_effect=build_read)))
        self.send = self.enterContext(patch.object(routes.connection_manager, "send_to_user", AsyncMock()))
        self.unread = self.enterContext(patch.object(routes.unread_counts_event_publisher, "send_event", AsyncMock()))

    def prepare_records(self):
        self.sender = uuid4()
        self.recipient = uuid4()
        self.conversation = Conversation(id=uuid4())
        self.direct = DirectConversation(
            conversation_id=self.conversation.id,
            user_one_id=self.sender,
            user_two_id=self.recipient,
        )
        self.start = Message(
            id=uuid4(), conversation_id=self.conversation.id,
            sender_id=self.sender, kind=MessageKind.CALL, body="",
            metadata_json={}, source_language="ko",
            created_at=datetime(2026, 10, 27, tzinfo=timezone.utc),
        )
        self.start_event = MessageCallEvent(
            message_id=self.start.id, kind=CallKind.VOICE,
            outcome=CallOutcome.STARTED, duration_ms=0,
        )
        self.records = {
            (Message, self.start.id): self.start,
            (MessageCallEvent, self.start.id): self.start_event,
            (Conversation, self.conversation.id): self.conversation,
            (DirectConversation, self.conversation.id): self.direct,
        }
        async def get(model, key, **kwargs):
            return self.records.get((model, key))
        def add(record):
            if isinstance(record, Message):
                record.id = record.id or uuid4()
                key = record.id
            else:
                key = record.message_id
            self.records[(type(record), key)] = record
        self.session = SimpleNamespace(
            get=AsyncMock(side_effect=get), add=Mock(side_effect=add),
            flush=AsyncMock(), commit=AsyncMock(), refresh=AsyncMock(),
        )

    async def finish(self, outcome, *, user_id=None, duration=0, message_id=None):
        tasks = BackgroundTasks()
        result = await routes.update_call_outcome(
            message_id=message_id or self.start.id,
            outcome_data=CallOutcomeUpdate(outcome=outcome, duration_ms=duration),
            background_tasks=tasks,
            current_user=SimpleNamespace(id=user_id or self.sender),
            session=self.session,
        )
        return result, tasks

    async def test_terminal_outcomes_preserve_start_and_publish_separate_result(self):
        for outcome, recipient_finishes in [
            ("cancelled", False), ("no_answer", False), ("ended", False),
            ("ended", True), ("missed", True),
        ]:
            with self.subTest(outcome=outcome, recipient_finishes=recipient_finishes):
                self.prepare_records()
                self.send.reset_mock()
                self.unread.reset_mock()
                duration = 34000 if outcome == "ended" else 0
                original_time = self.start.created_at
                result, tasks = await self.finish(
                    outcome, user_id=self.recipient if recipient_finishes else self.sender,
                    duration=duration,
                )
                self.assertNotEqual(result.id, self.start.id)
                self.assertEqual(self.start_event.outcome, CallOutcome.STARTED)
                self.assertEqual(self.start_event.duration_ms, 0)
                self.assertEqual(self.start.created_at, original_time)
                self.assertGreater(result.created_at, original_time)
                self.assertEqual(result.sender_id, self.sender)
                self.assertEqual(result.metadata["outcome"], outcome)
                self.assertEqual(result.metadata["call_start_message_id"], str(self.start.id))
                self.assertEqual(result.metadata["duration_ms"], duration)
                self.assertEqual(len([k for k in self.records if k[0] is Message]), 2)
                self.assertEqual(self.conversation.last_message_id, result.id)
                self.assertEqual(self.conversation.last_message_at, result.created_at)
                self.assertEqual(self.start.metadata_json["call_result_message_id"], str(result.id))
                self.session.get.assert_any_await(Message, self.start.id, with_for_update=True)
                self.session.commit.assert_awaited_once()
                event = self.send.await_args.kwargs["data"]
                self.assertEqual(event["type"], "message.created")
                self.assertEqual(event["message"]["id"], str(result.id))
                self.assertEqual(self.send.await_args.kwargs["user_id"], self.sender)
                self.unread.assert_awaited_once_with(
                    self.session, user_id=self.recipient, event=event, cause_message_id=result.id,
                )
                self.assertEqual(len(tasks.tasks), int(outcome in {"missed", "no_answer"}))
                if tasks.tasks:
                    self.assertEqual(tasks.tasks[0].args, (result.id,))

    async def test_retry_returns_stored_result_without_duplicate_events_or_notification(self):
        first, _ = await self.finish("no_answer")
        second, tasks = await self.finish("no_answer")
        self.assertEqual(first.id, second.id)
        self.assertEqual(first.created_at, second.created_at)
        self.session.commit.assert_awaited_once()
        self.send.assert_awaited_once()
        self.unread.assert_awaited_once()
        self.assertEqual(tasks.tasks, [])
        self.assertEqual(len([k for k in self.records if k[0] is Message]), 2)

    async def test_retry_cannot_change_final_duration_or_outcome(self):
        result, _ = await self.finish("ended", duration=34000)
        repeated, _ = await self.finish("ended", duration=90000)
        self.assertEqual(repeated.id, result.id)
        self.assertEqual(repeated.metadata["duration_ms"], 34000)
        with self.assertRaises(HTTPException) as error:
            await self.finish("cancelled")
        self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(len([k for k in self.records if k[0] is Message]), 2)

    async def test_participant_permissions_are_preserved(self):
        for user, outcome in [(uuid4(), "ended"), (self.sender, "missed"), (self.recipient, "cancelled"), (self.recipient, "no_answer")]:
            with self.subTest(user=user, outcome=outcome):
                with self.assertRaises(HTTPException) as error:
                    await self.finish(outcome, user_id=user)
                self.assertEqual(error.exception.status_code, 403)
        self.session.add.assert_not_called()

    async def test_missing_and_deleted_calls_are_rejected(self):
        with self.assertRaises(HTTPException) as error:
            await self.finish("ended", message_id=uuid4())
        self.assertEqual(error.exception.status_code, 404)
        self.start.deleted_at = datetime.now(timezone.utc)
        with self.assertRaises(HTTPException) as error:
            await self.finish("ended")
        self.assertEqual(error.exception.status_code, 404)
        self.session.add.assert_not_called()

    async def test_legacy_finished_record_is_not_duplicated(self):
        self.start_event.outcome = CallOutcome.CANCELLED
        result, tasks = await self.finish("cancelled")
        self.assertEqual(result.id, self.start.id)
        self.session.add.assert_not_called()
        self.send.assert_not_awaited()
        self.assertEqual(tasks.tasks, [])

    def test_client_cannot_supply_server_result_reference(self):
        self.assertEqual(routes.message_metadata_for_storage("call", {
            "kind": "voice", "outcome": "started", "duration_ms": 0,
            "call_result_message_id": str(uuid4()),
        }), {})


class CallNotificationTests(unittest.IsolatedAsyncioTestCase):
    async def test_start_notification_only_rings_before_a_result_is_saved(self):
        for finished in [False, True]:
            with self.subTest(finished=finished):
                sender_id, recipient_id, conversation_id, message_id = [uuid4() for _ in range(4)]
                message = SimpleNamespace(
                    id=message_id, sender_id=sender_id,
                    conversation_id=conversation_id, kind=MessageKind.CALL,
                    deleted_at=None,
                    metadata_json={"call_result_message_id": str(uuid4())} if finished else {},
                )
                records = {
                    (Message, message_id): message,
                    (DirectConversation, conversation_id): SimpleNamespace(
                        user_one_id=sender_id, user_two_id=recipient_id,
                    ),
                    (User, sender_id): SimpleNamespace(id=sender_id),
                    (User, recipient_id): SimpleNamespace(id=recipient_id),
                    (ConversationMember, (conversation_id, recipient_id)): SimpleNamespace(
                        left_at=None, muted_until=None,
                    ),
                    (MessageCallEvent, message_id): SimpleNamespace(outcome=CallOutcome.STARTED),
                }
                session = AsyncMock()
                session.get.side_effect = lambda model, key: records.get((model, key))
                context = AsyncMock()
                context.__aenter__.return_value = session
                with (
                    patch.object(notifications, "load_apns_settings", return_value=object()),
                    patch.object(notifications, "SessionLocal", return_value=context),
                    patch.object(notifications, "APNSClient"),
                    patch.object(notifications, "_send_voip_event", AsyncMock()) as ring,
                ):
                    await notifications.send_message_notification(message_id)
                self.assertEqual(ring.await_count, 0 if finished else 1)


if __name__ == "__main__":
    unittest.main()
