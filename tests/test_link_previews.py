import io
import os
import unittest
from email.message import Message
from unittest.mock import AsyncMock, Mock, patch
from types import SimpleNamespace
from uuid import uuid4

from fastapi import BackgroundTasks, HTTPException
from sqlalchemy.dialects import postgresql
from urllib.error import HTTPError
from urllib.request import Request


os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test",
)
os.environ.setdefault("OPENAI_API_KEY", "test-openai-api-key")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret")

from app.routes import messages as message_routes
from app.languages import SUPPORTED_LANGUAGE_NAMES
from app.models import DirectConversation, Message as ChatMessage, MessageKind, User
from app.schemas import MessageCreate, MessageUpdate


class FakeHTTPResponse:
    def __init__(
        self,
        body: bytes,
        *,
        url: str,
        content_type: str = "text/html; charset=UTF-8",
    ) -> None:
        self._stream = io.BytesIO(body)
        self._url = url
        self.bytes_read = 0
        self.headers = Message()
        self.headers["Content-Type"] = content_type

    def __enter__(self) -> "FakeHTTPResponse":
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def geturl(self) -> str:
        return self._url

    def read(self, size: int = -1) -> bytes:
        chunk = self._stream.read(size)
        self.bytes_read += len(chunk)
        return chunk


class LinkPreviewMetadataTests(unittest.TestCase):
    def test_kakao_scraper_headers_receive_page_specific_open_graph(self) -> None:
        url = "https://rent.heykorean.com/rent/view/1090440"
        page_image_url = (
            "https://data.heykorean.com/housing_thumbnail/origin/housing/"
            "rent/2026/08/01/6a6e067b1be76c54339313.webp"
        )
        html = (
            "<html><head>"
            f'<meta property="og:url" content="{url}">'
            '<meta property="og:title" '
            'content="StuyTown 거실룸 룸메이트 구해요 !">'
            '<meta property="og:description" '
            'content="StuyTown 거실룸 룸메이트 구해요 !">'
            f'<meta property="og:image" content="{page_image_url}">'
            '<meta property="og:site_name" '
            'content="StuyTown 거실룸 룸메이트 구해요 !">'
            "</head><body></body></html>"
        ).encode()
        response = FakeHTTPResponse(html, url=url)

        def fake_urlopen(
            request: Request,
            *,
            timeout: int,
        ) -> FakeHTTPResponse:
            headers = {
                key.lower(): value
                for key, value in request.header_items()
            }
            self.assertEqual(
                headers["user-agent"],
                "facebookexternalhit/1.1; kakaotalk-scrap/1.0; "
                "+https://devtalk.kakao.com/t/scrap/33984",
            )
            self.assertEqual(headers["accept"], "*/*")
            self.assertEqual(
                headers["accept-language"],
                "ko",
            )
            self.assertEqual(
                timeout,
                message_routes.LINK_PREVIEW_FETCH_TIMEOUT_SECONDS,
            )
            return response

        with patch.object(
            message_routes,
            "urlopen",
            side_effect=fake_urlopen,
        ):
            preview = message_routes.build_link_preview_metadata(url, None, language="ko")

        self.assertIsNotNone(preview)
        assert preview is not None
        self.assertEqual(preview["url"], url)
        self.assertEqual(preview["canonical_url"], url)
        self.assertEqual(preview["domain"], "rent.heykorean.com")
        self.assertEqual(
            preview["title"],
            "StuyTown 거실룸 룸메이트 구해요 !",
        )
        self.assertEqual(
            preview["description"],
            "StuyTown 거실룸 룸메이트 구해요 !",
        )
        self.assertEqual(
            preview["image_url"],
            page_image_url,
        )
        self.assertEqual(
            preview["site_name"],
            "StuyTown 거실룸 룸메이트 구해요 !",
        )

    def test_open_graph_after_legacy_256_kib_limit_is_parsed(self) -> None:
        requested_url = "https://youtu.be/CS0zz7WlnV0"
        canonical_url = "https://www.youtube.com/watch?v=CS0zz7WlnV0"
        thumbnail_url = (
            "https://i.ytimg.com/vi/CS0zz7WlnV0/maxresdefault.jpg"
        )
        padding = "x" * (700 * 1024)
        html = (
            "<html><head><script>"
            + padding
            + "</script>"
            + f'<meta property="og:url" content="{canonical_url}">'
            + '<meta property="og:title" content="Gold Farm">'
            + f'<meta property="og:image" content="{thumbnail_url}">'
            + "</head><body></body></html>"
        ).encode()
        response = FakeHTTPResponse(html, url=canonical_url)

        with patch.object(
            message_routes,
            "urlopen",
            return_value=response,
        ):
            preview = message_routes.build_link_preview_metadata(
                requested_url,
                None,
                language="ko",
            )

        self.assertIsNotNone(preview)
        assert preview is not None
        self.assertGreater(
            html.find(b"og:title"),
            256 * 1024,
        )
        self.assertEqual(preview["title"], "Gold Farm")
        self.assertEqual(preview["canonical_url"], canonical_url)
        self.assertEqual(preview["domain"], "youtu.be")
        self.assertEqual(
            preview["image_url"],
            thumbnail_url,
        )

    def test_reader_stops_after_html_head(self) -> None:
        url = "https://example.com/article"
        head = (
            "<html><head>"
            '<meta property="og:title" content="Preview title">'
            "</head>"
        ).encode()
        body = head + b"<body>" + (b"x" * (3 * 1024 * 1024)) + b"</body>"
        response = FakeHTTPResponse(body, url=url)

        with patch.object(
            message_routes,
            "urlopen",
            return_value=response,
        ):
            preview = message_routes.build_link_preview_metadata(url, None, language="ko")

        self.assertIsNotNone(preview)
        assert preview is not None
        self.assertEqual(preview["title"], "Preview title")
        self.assertLess(response.bytes_read, len(body))
        self.assertLessEqual(
            response.bytes_read,
            message_routes.LINK_PREVIEW_READ_CHUNK_BYTES,
        )

    def test_http_error_logs_warning_and_returns_domain_fallback(self) -> None:
        url = "https://m.fmkorea.com/10166678809"
        error = HTTPError(url, 430, "Unknown", hdrs=None, fp=None)

        with (
            patch.object(message_routes, "urlopen", side_effect=error),
            self.assertLogs(message_routes.logger, level="WARNING") as logs,
        ):
            preview = message_routes.build_link_preview_metadata(url, None, language="ko")

        self.assertIsNotNone(preview)
        assert preview is not None
        self.assertEqual(preview["domain"], "m.fmkorea.com")
        self.assertNotIn("title", preview)
        self.assertTrue(any("HTTPError" in message for message in logs.output))
        self.assertTrue(any("430" in message for message in logs.output))

    def test_http_error_preserves_device_fetched_metadata(self) -> None:
        url = "https://m.fmkorea.com/10166678809"
        image_url = "https://image.fmkorea.com/files/preview.jpg"
        metadata = {
            "language": "ko",
            "url": url,
            "canonical_url": "https://www.fmkorea.com/10166678809",
            "domain": "m.fmkorea.com",
            "title": "우리는 모르는 잘생긴 남자의 삶",
            "description": "Tap here to open the link.",
            "site_name": "에펨코리아",
            "image_url": image_url,
        }
        error = HTTPError(url, 429, "Too Many Requests", hdrs=None, fp=None)

        with (
            patch.object(message_routes, "urlopen", side_effect=error),
            patch.object(message_routes.logger, "warning"),
        ):
            preview = message_routes.build_link_preview_metadata(url, metadata, language="ko")

        self.assertIsNotNone(preview)
        assert preview is not None
        self.assertEqual(preview["canonical_url"], metadata["canonical_url"])
        self.assertEqual(preview["title"], metadata["title"])
        self.assertEqual(preview["description"], metadata["description"])
        self.assertEqual(preview["site_name"], metadata["site_name"])
        self.assertEqual(preview["image_url"], image_url)


    def test_all_supported_languages_are_requested_and_tagged(self) -> None:
        url = "https://example.com/article"
        for language in SUPPORTED_LANGUAGE_NAMES:
            with self.subTest(language=language):
                response = FakeHTTPResponse(
                    f'<head><title>Title {language}</title></head>'.encode(), url=url,
                )
                with patch.object(message_routes, "urlopen", return_value=response) as fetch:
                    preview = message_routes.build_link_preview_metadata(url, None, language=language)
                headers = dict((key.lower(), value) for key, value in fetch.call_args.args[0].header_items())
                self.assertEqual(headers["accept-language"], language)
                self.assertEqual(preview["language"], language)
                self.assertEqual(preview["title"], f"Title {language}")

    def test_failure_does_not_reuse_a_different_or_unknown_language(self) -> None:
        url = "https://example.com/article"
        for old_language in (None, "ko"):
            metadata = {"title": "한국어 제목", "description": "한국어 설명", "language": old_language}
            with patch.object(message_routes, "urlopen", side_effect=OSError("offline")), \
                    patch.object(message_routes.logger, "warning"):
                preview = message_routes.build_link_preview_metadata(url, metadata, language="es")
            self.assertEqual(preview["language"], "es")
            self.assertEqual(preview["url"], url)
            self.assertNotIn("title", preview)
            self.assertNotIn("description", preview)

    def test_client_metadata_cannot_supply_other_viewers_cached_cards(self) -> None:
        metadata = {"language": "ko", "title": "제목", "previews_by_language": {"es": {"title": "wrong"}}}
        with patch.object(message_routes, "urlopen", side_effect=OSError("offline")), \
                patch.object(message_routes.logger, "warning"):
            result = message_routes.build_link_preview_metadata("https://example.com", metadata, language="ko")
        self.assertNotIn("previews_by_language", result)
        self.assertEqual(result["title"], "제목")


class ViewerLinkPreviewTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.sender_id, self.viewer_id = uuid4(), uuid4()
        self.direct = DirectConversation(conversation_id=uuid4(), user_one_id=self.sender_id, user_two_id=self.viewer_id)
        self.message = ChatMessage(id=uuid4(), conversation_id=self.direct.conversation_id,
                                   sender_id=self.sender_id, kind=MessageKind.LINK,
                                   body="https://example.com/article", version=3, deleted_at=None,
                                   metadata_json={"url": "https://example.com/article", "language": "ko", "title": "한국어 제목"})
        self.viewer = SimpleNamespace(id=self.viewer_id, preferred_language="es")
        self.session = SimpleNamespace(
            get=AsyncMock(side_effect=lambda model, _: self.message if model is ChatMessage else self.direct),
            scalar=AsyncMock(return_value=self.message), execute=AsyncMock(), commit=AsyncMock(),
        )

    async def read_preview(self):
        return await message_routes.get_message_link_preview(self.message.id, self.viewer, self.session)

    async def test_each_viewers_language_is_fetched_and_cached_separately(self):
        for language in SUPPORTED_LANGUAGE_NAMES:
            with self.subTest(language=language):
                self.viewer.preferred_language = language
                response = FakeHTTPResponse(f'<head><title>Title {language}</title></head>'.encode(), url=self.message.body)
                with patch.object(message_routes, "urlopen", return_value=response) as fetch:
                    preview = await self.read_preview()
                    if language == "ko":
                        fetch.assert_not_called()
                        self.assertEqual(preview["title"], "한국어 제목")
                    else:
                        self.assertEqual(preview["title"], f"Title {language}")
                        headers = {key.lower(): value for key, value in fetch.call_args.args[0].header_items()}
                        self.assertEqual(headers["accept-language"], language)
                        statement = self.session.execute.call_args.args[0].compile(dialect=postgresql.dialect())
                        # 원래 메타데이터에 해당 언어만 합치고 메시지 버전도 검사해요.
                        self.assertIn("jsonb_set(messages.metadata", str(statement))
                        self.assertIn("||", str(statement))
                        self.assertIn("messages.version =", str(statement))
                        self.assertIn({language: preview}, list(statement.params.values()))
                    self.message.metadata_json.setdefault("previews_by_language", {})[language] = preview
                    fetch.reset_mock()
                    self.assertEqual(await self.read_preview(), preview)
                    fetch.assert_not_called()
                self.assertEqual(preview["language"], language)

    async def test_create_and_edit_collect_the_authors_language_not_the_receivers(self):
        self.viewer.id = self.sender_id
        self.viewer.preferred_language = "fr"
        receiver = SimpleNamespace(id=self.viewer_id, preferred_language="de")
        self.session.get.side_effect = lambda model, _: receiver if model is User else self.message
        self.session.scalar.return_value = self.direct
        self.session.add = Mock()
        self.session.flush = AsyncMock()
        self.session.refresh = AsyncMock()
        result = SimpleNamespace(model_dump=lambda **_: {})
        # 라우트의 실제 수집 경로를 확인하고 DB·실시간 전송만 대신해요.
        with patch.object(message_routes, "get_direct_conversation", AsyncMock(return_value=self.direct)), \
                patch.object(message_routes, "add_message_payload_records", AsyncMock()), \
                patch.object(message_routes, "update_conversation_latest_message", AsyncMock()), \
                patch.object(message_routes, "build_single_message_read", AsyncMock(return_value=result)), \
                patch.object(message_routes, "publish_created_message", AsyncMock()), \
                patch.object(message_routes, "send_to_direct_participants", AsyncMock()):
            for editing in (False, True):
                response = FakeHTTPResponse(b'<head><title>Bonjour</title></head>', url=self.message.body)
                with patch.object(message_routes, "urlopen", return_value=response) as fetch:
                    if editing:
                        await message_routes.update_message(self.message.id, MessageUpdate(content=self.message.body),
                            BackgroundTasks(), self.viewer, self.session)
                        metadata = self.message.metadata_json
                    else:
                        await message_routes.create_message(MessageCreate(recipient_id=self.viewer_id, content=self.message.body),
                            BackgroundTasks(), self.viewer, self.session)
                        metadata = self.session.add.call_args.args[0].metadata_json
                    headers = {key.lower(): value for key, value in fetch.call_args.args[0].header_items()}
                    self.assertEqual(headers["accept-language"], "fr")
                    self.assertEqual(metadata["language"], "fr")
                    self.assertEqual(metadata["title"], "Bonjour")

    async def test_unknown_legacy_language_is_refetched_for_the_viewer(self):
        self.message.metadata_json.pop("language")
        response = FakeHTTPResponse(b'<head><title>Hola</title></head>', url=self.message.body)
        with patch.object(message_routes, "urlopen", return_value=response):
            preview = await self.read_preview()
        self.assertEqual(preview["title"], "Hola")
        self.assertEqual(preview["language"], "es")

    async def test_nonparticipant_cannot_fetch_or_read_a_cached_preview(self):
        self.viewer.id = uuid4()
        with patch.object(message_routes, "urlopen") as fetch, self.assertRaises(HTTPException) as error:
            await self.read_preview()
        self.assertEqual(error.exception.status_code, 403)
        fetch.assert_not_called()
        self.session.execute.assert_not_called()

    async def test_hidden_or_deleted_messages_cannot_be_previewed(self):
        for deleted in (False, True):
            self.message.deleted_at = object() if deleted else None
            self.session.scalar.return_value = None
            with patch.object(message_routes, "urlopen") as fetch, self.assertRaises(HTTPException) as error:
                await self.read_preview()
            self.assertEqual(error.exception.status_code, 404)
            fetch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
