from __future__ import annotations

import os
import unittest
from unittest.mock import AsyncMock
from uuid import UUID

os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test",
)
os.environ.setdefault("JWT_SECRET", "test-jwt-secret-with-at-least-32-bytes")

import httpx
from fastapi import FastAPI
from sqlalchemy.dialects import postgresql
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models import User
from app.passwords import verify_password
from app.routes.auth import router
from app.security import decode_access_token, decode_refresh_token


class RegistrationTests(unittest.IsolatedAsyncioTestCase):
    user_id = UUID("11111111-1111-4111-8111-111111111111")

    async def asyncSetUp(self) -> None:
        # 운영 DB와 앱 시작 시 스키마 변경을 실행하지 않고 실제 HTTP 경로를 검사해요.
        app = FastAPI()
        app.include_router(router)
        self.session = AsyncMock(spec=AsyncSession)
        app.dependency_overrides[get_session] = lambda: self.session
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test",
        )

    async def asyncTearDown(self) -> None:
        await self.client.aclose()

    async def _register(self, **overrides: str) -> httpx.Response:
        return await self.client.post(
            "/auth/register",
            json={
                "username": "  June  ",
                "password": " secret ",
                "password_confirmation": " secret ",
                **overrides,
            },
        )

    async def test_registration_hashes_password_and_reuses_login_session(self) -> None:
        def inserted_user(statement):
            values = statement.compile(dialect=postgresql.dialect()).params
            self.assertEqual(values["username"], "June")
            self.assertEqual(values["display_name"], "June")
            self.assertNotEqual(values["password_hash"], " secret ")
            self.assertTrue(verify_password(" secret ", values["password_hash"]))
            self.assertFalse(verify_password("secret", values["password_hash"]))
            self.assertNotIn("password_confirmation", values)
            return User(
                id=self.user_id,
                username=values["username"],
                display_name=values["display_name"],
                password_hash=values["password_hash"],
                token_version=0,
                preferred_language="ko",
            )

        self.session.scalar.side_effect = inserted_user
        response = await self._register()
        self.assertEqual(response.status_code, 201, response.text)
        session = response.json()
        self.assertEqual(session["user"]["username"], "June")
        self.assertEqual(session["user"]["display_name"], "June")
        self.assertNotIn("password_hash", session["user"])
        self.assertEqual(decode_access_token(session["access_token"]), (self.user_id, 0))
        self.assertEqual(decode_refresh_token(session["refresh_token"]), (self.user_id, 0))
        self.session.commit.assert_awaited_once()

        user = inserted_user(self.session.scalar.call_args.args[0])
        self.session.scalar.side_effect = None
        self.session.scalar.return_value = user
        logged_in = await self.client.post(
            "/auth/login", json={"username": "June", "password": " secret "}
        )
        self.assertEqual(logged_in.status_code, 200)
        self.assertEqual(logged_in.json()["user"], session["user"])

        incorrect = await self.client.post(
            "/auth/login", json={"username": "June", "password": "secret"}
        )
        self.assertEqual(incorrect.status_code, 401)

    async def test_password_mismatch_does_not_create_a_user(self) -> None:
        response = await self._register(password_confirmation="secret")
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json(), {"detail": "Passwords do not match"})
        self.session.scalar.assert_not_awaited()
        self.session.commit.assert_not_awaited()

    async def test_duplicate_username_uses_database_unique_constraint(self) -> None:
        self.session.scalar.return_value = None
        response = await self._register(username="jUnE")
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()["detail"], "This username is already taken")
        statement = self.session.scalar.call_args.args[0]
        sql = str(statement.compile(dialect=postgresql.dialect()))
        self.assertIn("ON CONFLICT (username) DO NOTHING", sql)
        self.assertIsInstance(User.__table__.c.username.type, postgresql.CITEXT)
        self.assertTrue(User.__table__.c.username.unique)
        self.session.commit.assert_not_awaited()

    async def test_required_fields_and_username_length_are_validated(self) -> None:
        for invalid in [
            {"username": "   "},
            {"username": "x" * 51},
            {"password": ""},
            {"password_confirmation": ""},
        ]:
            with self.subTest(invalid=invalid):
                response = await self._register(**invalid)
                self.assertEqual(response.status_code, 422)
        response = await self.client.post(
            "/auth/register", json={"username": "June", "password": "secret"}
        )
        self.assertEqual(response.status_code, 422)
        self.session.scalar.assert_not_awaited()

    async def test_login_uses_the_same_trimmed_username(self) -> None:
        self.session.scalar.return_value = None
        response = await self.client.post(
            "/auth/login", json={"username": "  June  ", "password": "secret"}
        )
        self.assertEqual(response.status_code, 401)
        statement = self.session.scalar.call_args.args[0]
        self.assertIn("June", statement.compile().params.values())


if __name__ == "__main__":
    unittest.main()
