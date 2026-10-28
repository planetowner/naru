import os
import unittest
from types import SimpleNamespace
from uuid import UUID


os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test",
)

from app.models import CallOutcome, MessageKind
from app.notifications import (
    APNS_MAX_PAYLOAD_BYTES,
    _bounded_alert_payload,
    _encoded_payload_size,
    localized_message_body,
)
from app.schemas import DeviceRegistrationUpdate
from app.unread_counts import build_unread_counts_snapshot


class NotificationLocalizationTests(unittest.TestCase):
    def test_media_summaries_match_supported_languages(self) -> None:
        expected = {
            MessageKind.PHOTO: ("사진을 보냈습니다.", "照片"),
            MessageKind.VIDEO: ("동영상을 보냈습니다.", "视频"),
            MessageKind.VOICE_MEMO: ("음성메시지를 보냈습니다.", "语音备忘录"),
        }

        for message_kind, (korean, chinese) in expected.items():
            message = SimpleNamespace(kind=message_kind, body="")
            with self.subTest(message_kind=message_kind):
                self.assertEqual(
                    localized_message_body(
                        message,
                        recipient_language="ko",
                        call_event=None,
                    ),
                    korean,
                )
                self.assertEqual(
                    localized_message_body(
                        message,
                        recipient_language="zh-CN",
                        call_event=None,
                    ),
                    chinese,
                )

    def test_file_summary_includes_file_name(self) -> None:
        message = SimpleNamespace(kind=MessageKind.FILE, body="")

        self.assertEqual(
            localized_message_body(
                message,
                recipient_language="ko",
                call_event=None,
                file_name="Day 01 관계.pdf",
            ),
            "파일: Day 01 관계.pdf",
        )
        self.assertEqual(
            localized_message_body(
                message,
                recipient_language="zh-CN",
                call_event=None,
                file_name="Day 01 관계.pdf",
            ),
            "文件: Day 01 관계.pdf",
        )

    def test_missed_call_summary_is_localized(self) -> None:
        message = SimpleNamespace(kind=MessageKind.CALL, body="")
        call_event = SimpleNamespace(outcome=CallOutcome.MISSED)

        self.assertEqual(
            localized_message_body(
                message,
                recipient_language="ko",
                call_event=call_event,
            ),
            "부재중 음성 통화",
        )
        self.assertEqual(
            localized_message_body(
                message,
                recipient_language="zh-CN",
                call_event=call_event,
            ),
            "未接语音通话",
        )

    def test_all_eight_languages_use_recipient_notification_copy(self) -> None:
        expected = {
            "ko": ("사진을 보냈습니다.", "동영상을 보냈습니다.", "음성메시지를 보냈습니다.", "파일을 보냈습니다.", "부재중 음성 통화"),
            "zh-CN": ("照片", "视频", "语音备忘录", "文件", "未接语音通话"),
            "en": ("Sent a photo.", "Sent a video.", "Sent a voice message.", "Sent a file.", "Missed voice call"),
            "ja": ("写真を送信しました。", "動画を送信しました。", "ボイスメッセージを送信しました。", "ファイルを送信しました。", "音声通話の不在着信"),
            "es": ("Ha enviado una foto.", "Ha enviado un vídeo.", "Ha enviado un mensaje de voz.", "Ha enviado un archivo.", "Llamada de voz perdida"),
            "fr": ("A envoyé une photo.", "A envoyé une vidéo.", "A envoyé un message vocal.", "A envoyé un fichier.", "Appel vocal manqué"),
            "de": ("Hat ein Foto gesendet.", "Hat ein Video gesendet.", "Hat eine Sprachnachricht gesendet.", "Hat eine Datei gesendet.", "Verpasster Sprachanruf"),
            "it": ("Ha inviato una foto.", "Ha inviato un video.", "Ha inviato un messaggio vocale.", "Ha inviato un file.", "Chiamata vocale persa"),
        }
        kinds = [MessageKind.PHOTO, MessageKind.VIDEO, MessageKind.VOICE_MEMO, MessageKind.FILE, MessageKind.CALL]
        for language, labels in expected.items():
            for kind, label in zip(kinds, labels):
                with self.subTest(language=language, kind=kind):
                    self.assertEqual(localized_message_body(
                        SimpleNamespace(kind=kind, body=""), recipient_language=language,
                        call_event=SimpleNamespace(outcome=CallOutcome.MISSED),
                    ), label)
            self.assertEqual(localized_message_body(
                SimpleNamespace(kind=MessageKind.CALL, body=""), recipient_language=language,
                call_event=SimpleNamespace(outcome=CallOutcome.NO_ANSWER),
            ), labels[-1])

    def test_notification_keeps_user_text_and_file_names_intact(self) -> None:
        for kind in (MessageKind.TEXT, MessageKind.LINK):
            self.assertEqual(localized_message_body(
                SimpleNamespace(kind=kind, body="Photo {name}"),
                recipient_language="es", call_event=None,
            ), "Photo {name}")
        self.assertEqual(localized_message_body(
            SimpleNamespace(kind=MessageKind.FILE, body=""), recipient_language="de",
            call_event=None, file_name="문서 {name}.pdf",
        ), "Datei: 문서 {name}.pdf")

    def test_catalogs_share_keys_and_notification_placeholders(self) -> None:
        import json
        from pathlib import Path
        from string import Formatter
        files = list((Path(__file__).parents[1] / "app" / "locales").glob("*.arb"))
        self.assertEqual(len(files), 8)
        catalogs = [json.loads(path.read_text()) for path in files]
        reference = {key for key in catalogs[0] if not key.startswith("@")}
        for catalog in catalogs:
            self.assertEqual({key for key in catalog if not key.startswith("@")}, reference)
            fields = {name for _, name, _, _ in Formatter().parse(catalog["notificationNamedFile"]) if name}
            self.assertEqual(fields, {"name"})


class NotificationPayloadTests(unittest.TestCase):
    def test_alert_payload_is_bounded_to_apns_limit(self) -> None:
        payload = {
            "aps": {
                "alert": {"title": "june", "body": "긴 메시지" * 3000},
                "mutable-content": 1,
            },
            "naru": {
                "sender_id": "sender-id",
                "sender_image_url": "https://example.com/" + "a" * 5000,
                "photo_url": "https://example.com/" + "b" * 5000,
            },
        }

        bounded = _bounded_alert_payload(payload)

        self.assertLessEqual(
            _encoded_payload_size(bounded),
            APNS_MAX_PAYLOAD_BYTES,
        )

    def test_explicit_null_can_clear_last_voip_token(self) -> None:
        registration = DeviceRegistrationUpdate.model_validate(
            {
                "installation_id": "device-id",
                "platform": "ios",
                "voip_push_token": None,
                "app_bundle_id": "com.planetowner.naru",
                "apns_environment": "development",
            }
        )

        self.assertIsNone(registration.voip_push_token)
        self.assertIn("voip_push_token", registration.model_fields_set)

    def test_unread_snapshot_contains_authoritative_counts(self) -> None:
        user_id = UUID("00000000-0000-0000-0000-000000000001")
        first_sender_id = UUID("00000000-0000-0000-0000-000000000002")
        second_sender_id = UUID("00000000-0000-0000-0000-000000000003")
        message_id = UUID("00000000-0000-0000-0000-000000000004")

        snapshot = build_unread_counts_snapshot(
            user_id=user_id,
            counts_by_sender_id={
                first_sender_id: 2,
                second_sender_id: 3,
            },
            stream_id="test-stream",
            sequence=7,
            cause_message_id=message_id,
        )

        self.assertEqual(snapshot["user_id"], str(user_id))
        self.assertEqual(snapshot["stream_id"], "test-stream")
        self.assertEqual(snapshot["sequence"], 7)
        self.assertEqual(
            snapshot["counts_by_sender_id"],
            {
                str(first_sender_id): 2,
                str(second_sender_id): 3,
            },
        )
        self.assertEqual(snapshot["total_unread_count"], 5)
        self.assertEqual(snapshot["cause_message_id"], str(message_id))


if __name__ == "__main__":
    unittest.main()
