import os
import unittest
from unittest.mock import AsyncMock, patch

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test")

from app.database import ensure_schema_compatibility
from app.languages import SUPPORTED_LANGUAGE_NAMES
from app.models import User
from scripts.create_user import parse_args


class LanguageDefaultTests(unittest.IsolatedAsyncioTestCase):
    def test_manual_account_creation_defaults_to_english_and_keeps_selection(self):
        argv = ["create_user", "friend", "password", "--display-name", "Friend"]
        with patch("sys.argv", argv):
            self.assertEqual(parse_args().language, "en")
        for language in SUPPORTED_LANGUAGE_NAMES:
            with self.subTest(language=language), patch("sys.argv", [*argv, "--language", language]):
                self.assertEqual(parse_args().language, language)

    async def test_existing_and_new_schema_use_the_same_english_default(self):
        column = User.__table__.c.preferred_language
        self.assertEqual(column.default.arg, "en")
        self.assertEqual(column.server_default.arg, "en")
        connection = AsyncMock()
        await ensure_schema_compatibility(connection)
        language_changes = [str(call.args[0]) for call in connection.execute.await_args_list
                            if "preferred_language" in str(call.args[0])]
        # 기존 사용자의 선택값을 UPDATE하지 않고 컬럼 기본값만 바꿔요.
        self.assertEqual(language_changes, ["ALTER TABLE users ALTER COLUMN preferred_language SET DEFAULT 'en'"])
