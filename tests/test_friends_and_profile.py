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
from app.models import MediaAsset, MediaKind, User, UserFriend, FriendRequest
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

    async def test_search_exact_username_and_request_direction(self):
        pending = FriendRequest(id=uuid4(), sender_id=self.me.id,
                                recipient_id=self.friend.id, status="pending")
        for state in ("none", "outgoing", "incoming", "friend"):
            self.session.get.return_value = UserFriend() if state == "friend" else None
            pending.sender_id = self.friend.id if state == "incoming" else self.me.id
            self.session.scalar.side_effect = [self.friend] + ([] if state == "friend" else [
                pending if state in ("outgoing", "incoming") else None])
            response = await self.client.get('/users/search', params={'username': ' Maya '})
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertEqual(data['is_friend'], state == "friend")
            self.assertEqual(data['outgoing_request_id'], str(pending.id) if state == "outgoing" else None)
            self.assertEqual(data['incoming_request_id'], str(pending.id) if state == "incoming" else None)
            query = self.session.scalar.call_args_list[-(1 if state == "friend" else 2)].args[0]
            compiled = query.compile(dialect=postgresql.dialect())
            self.assertIn('users.username =', str(compiled))
            self.assertIn('Maya', compiled.params.values())
        self.session.scalar.side_effect = [None]
        self.assertIsNone((await self.client.get('/users/search?username=missing')).json())

    async def test_send_creates_request_and_notifies_only_once_without_adding_friend(self):
        from app.schemas import FriendSearchRead, UserRead
        request_id = uuid4()
        self.session.get.return_value = self.friend
        before = FriendSearchRead(user=UserRead.model_validate(self.friend), is_friend=False)
        after = before.model_copy(update={'outgoing_request_id': request_id})
        with patch('app.routes.users._friend_search_result', new=AsyncMock(side_effect=[before, after, after, after])), \
             patch('app.routes.users.send_friend_request_notification', new_callable=AsyncMock) as push, \
             patch('app.routes.users.connection_manager.send_to_user', new_callable=AsyncMock) as event:
            self.session.scalar.side_effect = [request_id, None]
            for _ in range(2):
                response = await self.client.post(f'/users/friends/{self.friend.id}')
                self.assertEqual(response.status_code, 200)
                self.assertFalse(response.json()['is_friend'])
                self.assertEqual(response.json()['outgoing_request_id'], str(request_id))
            push.assert_awaited_once_with(request_id)
            self.assertEqual(event.await_count, 2)
            self.assertEqual({call.args[0] for call in event.call_args_list}, {self.me.id, self.friend.id})
        self.session.execute.assert_not_awaited()
        statement = self.session.scalar.call_args.args[0].compile(dialect=postgresql.dialect())
        self.assertIn('INSERT INTO friend_requests', str(statement))
        self.assertIn('ON CONFLICT (least(sender_id, recipient_id), greatest(sender_id, recipient_id))', str(statement))
        self.assertIn('declined', statement.params.values())
        self.assertIn('WHERE friend_requests.status =', str(statement))

    async def test_accept_adds_both_directions_before_one_commit_and_publishes_to_both(self):
        request = FriendRequest(id=uuid4(), sender_id=self.friend.id, recipient_id=self.me.id, status='pending')
        self.session.scalar.return_value = request
        self.session.get.return_value = self.friend
        async def published(user_id, data):
            self.session.commit.assert_awaited_once()
            self.assertEqual(request.status, 'accepted')
            self.assertEqual(data, {'type': 'friends.changed'})
        with patch('app.routes.users.connection_manager.send_to_user', new=AsyncMock(side_effect=published)) as event:
            response = await self.client.post(f'/users/friend-requests/{request.id}/respond', json={'decision': 'accept'})
        self.assertEqual(response.status_code, 204)
        self.assertEqual({call.args[0] for call in event.call_args_list}, {self.me.id, self.friend.id})
        query = self.session.scalar.call_args.args[0].compile(dialect=postgresql.dialect())
        self.assertIn('FOR UPDATE', str(query))
        self.assertIn('friend_requests.recipient_id =', str(query))
        self.assertIn(self.me.id, query.params.values())
        insert = self.session.execute.call_args.args[0].compile(dialect=postgresql.dialect())
        self.assertEqual(insert.params, {'user_id_m0': self.friend.id, 'friend_id_m0': self.me.id,
                                        'user_id_m1': self.me.id, 'friend_id_m1': self.friend.id})
        self.assertIn('ON CONFLICT DO NOTHING', str(insert))
        repeated = await self.client.post(f'/users/friend-requests/{request.id}/respond', json={'decision': 'decline'})
        self.assertEqual(repeated.status_code, 409)
        self.assertEqual(request.status, 'accepted')

    async def test_decline_never_creates_a_friendship(self):
        request = FriendRequest(id=uuid4(), sender_id=self.friend.id, recipient_id=self.me.id, status='pending')
        self.session.scalar.return_value = request
        self.session.get.return_value = self.friend
        with patch('app.routes.users.connection_manager.send_to_user', new_callable=AsyncMock):
            response = await self.client.post(f'/users/friend-requests/{request.id}/respond', json={'decision': 'decline'})
        self.assertEqual(response.status_code, 204)
        self.assertEqual(request.status, 'declined')
        self.session.execute.assert_not_awaited()
        self.session.commit.assert_awaited_once()

    async def test_existing_friend_does_not_send_another_request(self):
        from app.schemas import FriendSearchRead, UserRead
        self.session.get.return_value = self.friend
        result = FriendSearchRead(user=UserRead.model_validate(self.friend), is_friend=True)
        with patch('app.routes.users._friend_search_result', new=AsyncMock(return_value=result)), \
             patch('app.routes.users.send_friend_request_notification', new_callable=AsyncMock) as push:
            response = await self.client.post(f'/users/friends/{self.friend.id}')
        self.assertTrue(response.json()['is_friend'])
        self.session.commit.assert_not_awaited()
        self.session.scalar.assert_not_awaited()
        push.assert_not_awaited()

    async def test_reverse_request_requires_explicit_acceptance(self):
        from app.schemas import FriendSearchRead, UserRead
        self.session.get.return_value = self.friend
        self.session.scalar.return_value = None
        result = FriendSearchRead(user=UserRead.model_validate(self.friend), is_friend=False,
                                  incoming_request_id=uuid4())
        with patch('app.routes.users._friend_search_result', new=AsyncMock(return_value=result)), \
             patch('app.routes.users.send_friend_request_notification', new_callable=AsyncMock) as push:
            response = await self.client.post(f'/users/friends/{self.friend.id}')
        self.assertEqual(response.json()['incoming_request_id'], str(result.incoming_request_id))
        self.assertFalse(response.json()['is_friend'])
        self.session.execute.assert_not_awaited()
        push.assert_not_awaited()

    async def test_only_receiver_can_respond_to_existing_pending_request(self):
        self.session.scalar.return_value = None
        response = await self.client.post(f'/users/friend-requests/{uuid4()}/respond', json={'decision': 'accept'})
        self.assertEqual(response.status_code, 404)
        query = self.session.scalar.call_args.args[0].compile(dialect=postgresql.dialect())
        self.assertIn('friend_requests.recipient_id =', str(query))
        self.assertIn(self.me.id, query.params.values())
        self.session.commit.assert_not_awaited()
        self.session.execute.assert_not_awaited()

    async def test_pending_inbox_filters_receiver_status_and_disabled_senders(self):
        request_id = uuid4()
        self.session.execute.return_value = [(request_id, self.friend)]
        response = await self.client.get('/users/friend-requests')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()[0]['id'], str(request_id))
        self.assertEqual(response.json()[0]['sender']['display_name'], self.friend.display_name)
        query = self.session.execute.call_args.args[0].compile(dialect=postgresql.dialect())
        for expected in ('friend_requests.recipient_id =', 'friend_requests.status =', 'users.disabled_at IS NULL', 'ORDER BY friend_requests.created_at'):
            self.assertIn(expected, str(query))
        self.assertIn(self.me.id, query.params.values())
        self.assertIn('pending', query.params.values())

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
        for method, path in [('GET', '/users'), ('GET', '/users/search?username=maya'), ('POST', f'/users/friends/{self.friend.id}'), ('GET', '/users/friend-requests'), ('POST', f'/users/friend-requests/{uuid4()}/respond'), ('PATCH', '/users/me')]:
            response = await self.client.request(method, path, json={'display_name': 'June', 'preferred_language': 'en'})
            self.assertEqual(response.status_code, 401)
