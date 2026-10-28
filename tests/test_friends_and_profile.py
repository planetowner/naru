import os
import unittest
from unittest.mock import AsyncMock, Mock, patch
from uuid import uuid4

os.environ.setdefault('DATABASE_URL', 'postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test')
os.environ.setdefault('JWT_SECRET', 'test-jwt-secret-with-at-least-32-bytes')

import httpx
from fastapi import FastAPI
from sqlalchemy.dialects import postgresql
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.dependencies import get_current_user
from app.models import MediaAsset, MediaKind, User, UserFriend
from app.routes.users import router


class FriendsAndProfileTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.me = User(id=uuid4(), username='june', display_name='June', preferred_language='en')
        self.friend = User(id=uuid4(), username='Maya', display_name='Maya 🌿', preferred_language='es')
        self.session = AsyncMock(spec=AsyncSession)
        self.app = FastAPI()
        self.app.include_router(router)
        # 실제 DB, 스키마 변경, 사진 저장소 호출 없이 요청과 권한을 확인해요.
        self.app.dependency_overrides[get_session] = lambda: self.session
        self.app.dependency_overrides[get_current_user] = lambda: self.me
        self.client = httpx.AsyncClient(transport=httpx.ASGITransport(app=self.app), base_url='https://api.test')

    async def asyncTearDown(self):
        await self.client.aclose()

    async def test_list_filters_directed_friendships_and_disabled_users(self):
        self.session.scalars.return_value = [self.friend]
        response = await self.client.get('/users')
        self.assertEqual(response.status_code, 200)
        self.assertEqual([x['id'] for x in response.json()], [str(self.friend.id)])
        statement = self.session.scalars.call_args.args[0].compile(dialect=postgresql.dialect())
        self.assertIn('JOIN user_friends ON user_friends.friend_id = users.id', str(statement))
        self.assertIn('user_friends.user_id =', str(statement))
        self.assertIn(self.me.id, statement.params.values())
        self.assertIn('users.disabled_at IS NULL', str(statement))

    async def test_search_exact_username_and_added_state(self):
        self.session.scalar.return_value = self.friend
        for added in (False, True):
            self.session.get.return_value = UserFriend() if added else None
            response = await self.client.get('/users/search', params={'username': ' Maya '})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()['is_friend'], added)
            self.assertEqual(response.json()['user']['display_name'], 'Maya 🌿')
            statement = self.session.scalar.call_args.args[0].compile(dialect=postgresql.dialect())
            self.assertIn('users.username =', str(statement))  # CITEXT가 대소문자 비교를 맡아요.
            self.assertIn('Maya', statement.params.values())
            self.assertIn('users.id !=', str(statement))
            self.session.get.assert_awaited_with(UserFriend, (self.me.id, self.friend.id))
        self.session.scalar.return_value = None
        response = await self.client.get('/users/search', params={'username': 'missing'})
        self.assertIsNone(response.json())

    async def test_add_is_idempotent_and_does_not_add_reverse_relationship(self):
        self.session.get.return_value = self.friend
        for _ in range(2):
            response = await self.client.post(f'/users/friends/{self.friend.id}')
            self.assertEqual(response.status_code, 200)
            statement = self.session.execute.call_args.args[0].compile(dialect=postgresql.dialect())
            self.assertIn('ON CONFLICT DO NOTHING', str(statement))
            self.assertEqual(statement.params, {'user_id': self.me.id, 'friend_id': self.friend.id})
        self.assertEqual([c.name for c in UserFriend.__table__.primary_key.columns], ['user_id', 'friend_id'])

    async def test_rejects_self_missing_and_disabled_friend(self):
        response = await self.client.post(f'/users/friends/{self.me.id}')
        self.assertEqual(response.status_code, 400)
        for user in (None, User(id=self.friend.id, disabled_at='disabled')):
            self.session.get.return_value = user
            response = await self.client.post(f'/users/friends/{self.friend.id}')
            self.assertEqual(response.status_code, 404)
        self.session.execute.assert_not_awaited()

    async def test_profile_reuses_name_validation_and_all_eight_languages(self):
        self.me.profile_image_url = 'https://existing/photo.jpg'
        for language in ('ko', 'ja', 'zh-CN', 'en', 'es', 'fr', 'de', 'it'):
            response = await self.client.patch('/users/me', json={'display_name': ' New Name 🌿 ', 'preferred_language': language})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()['display_name'], 'New Name 🌿')
            self.assertEqual(response.json()['preferred_language'], language)
            self.assertEqual(response.json()['profile_image_url'], 'https://existing/photo.jpg')
        for name, language in [(' ', 'en'), ('x' * 101, 'en'), ('Name', 'xx')]:
            response = await self.client.patch('/users/me', json={'display_name': name, 'preferred_language': language})
            self.assertEqual(response.status_code, 422)

    async def test_only_owned_complete_photo_can_be_saved(self):
        asset = MediaAsset(id=uuid4(), owner_user_id=self.me.id, kind=MediaKind.PHOTO, upload_status='complete', storage_key='photo.jpg')
        self.session.get.return_value = asset
        for field, value in [('owner_user_id', self.friend.id), ('kind', MediaKind.FILE), ('upload_status', 'pending')]:
            original = getattr(asset, field)
            setattr(asset, field, value)
            response = await self.client.patch('/users/me', json={'display_name': 'Updated', 'preferred_language': 'ko', 'photo_asset_id': str(asset.id)})
            self.assertEqual(response.status_code, 404)
            self.assertEqual(self.me.display_name, 'June')
            self.assertEqual(self.me.preferred_language, 'en')
            setattr(asset, field, original)
        self.session.commit.assert_not_awaited()
        response = await self.client.patch('/users/me', json={'display_name': 'Updated', 'preferred_language': 'ko', 'photo_asset_id': str(asset.id)})
        self.assertEqual(response.status_code, 200)
        url = f'https://api.test/users/{self.me.id}/photo/{asset.id}'
        self.assertEqual(response.json()['profile_image_url'], url)

        self.session.get.side_effect = lambda model, key: self.me if model == User else asset
        storage = Mock()
        storage.presigned_get_url.return_value = 'https://storage.test/photo?signature=fresh'
        self.app.dependency_overrides.pop(get_current_user)
        with patch('app.routes.users.get_object_storage_client', return_value=storage):
            response = await self.client.get(url)
            self.assertEqual(response.status_code, 307)
            self.assertEqual(response.headers['location'], storage.presigned_get_url.return_value)
            self.assertEqual(response.headers['cache-control'], 'no-store')
            self.me.profile_image_url = 'https://different/photo.jpg'
            response = await self.client.get(url)
            self.assertEqual(response.status_code, 404)

    async def test_nonfriend_notification_lookup_does_not_add_friend(self):
        self.session.get.return_value = self.friend
        response = await self.client.get(f'/users/{self.friend.id}')
        self.assertEqual(response.json()['display_name'], 'Maya 🌿')
        self.session.execute.assert_not_awaited()

    async def test_friend_and_profile_routes_require_login(self):
        self.app.dependency_overrides.pop(get_current_user)
        for method, path in [('GET', '/users'), ('GET', '/users/search?username=maya'), ('POST', f'/users/friends/{self.friend.id}'), ('PATCH', '/users/me')]:
            response = await self.client.request(method, path, json={'display_name': 'June', 'preferred_language': 'en'})
            self.assertEqual(response.status_code, 401)
