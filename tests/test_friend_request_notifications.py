import os
import unittest
from unittest.mock import AsyncMock, Mock, patch
from uuid import uuid4

os.environ.setdefault('DATABASE_URL', 'postgresql+asyncpg://postgres:postgres@localhost:5432/naru_test')

from sqlalchemy.ext.asyncio import AsyncSession
from app.models import FriendRequest, User, UserDevice
from app.notifications import APNSResult, APNSSettings, send_friend_request_notification


class FriendRequestNotificationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.sender = User(id=uuid4(), username='june', display_name='June 🌿', preferred_language='ko')
        self.recipient = User(id=uuid4(), username='maya', display_name='Maya', preferred_language='es')
        self.request = FriendRequest(id=uuid4(), sender_id=self.sender.id,
                                     recipient_id=self.recipient.id, status='pending')
        self.device = UserDevice(user_id=self.recipient.id, push_token='test-token', apns_environment='development')
        self.session = AsyncMock(spec=AsyncSession)
        self.session.get.side_effect = lambda model, key: (
            self.request if model is FriendRequest else
            self.sender if key == self.sender.id else self.recipient
        )
        self.session.scalars.return_value = [self.device]
        self.settings = APNSSettings('key', 'team', 'test.naru', 'test-private-key')
        self.client = Mock()
        self.client.send = AsyncMock(return_value=APNSResult(succeeded=True, status_code=200))

    async def send(self):
        with patch('app.notifications.load_apns_settings', return_value=self.settings), \
             patch('app.notifications.SessionLocal') as factory, \
             patch('app.notifications.APNSClient', return_value=self.client):
            factory.return_value.__aenter__.return_value = self.session
            await send_friend_request_notification(self.request.id)

    async def test_notification_uses_recipient_language_and_saved_display_name_in_all_eight_languages(self):
        expected = {
            'ko': '친구 요청을 보냈어요.', 'ja': '友だちリクエストが届きました。',
            'zh-CN': '向你发送了好友请求。', 'en': 'Sent you a friend request.',
            'es': 'Te ha enviado una solicitud de amistad.',
            'fr': 'Vous a envoyé une demande d’amitié.',
            'de': 'Hat dir eine Freundschaftsanfrage gesendet.',
            'it': 'Ti ha inviato una richiesta di amicizia.',
        }
        for language, body in expected.items():
            self.recipient.preferred_language = language
            await self.send()
            args = self.client.send.call_args.kwargs
            payload = args['payload']
            self.assertEqual(payload['aps']['alert'], {'title': 'June 🌿', 'body': body})
            self.assertEqual(payload['naru']['language'], language)
            self.assertEqual(payload['naru']['request_id'], str(self.request.id))
            self.assertEqual(payload['naru']['type'], 'friend_request')
            self.assertNotIn('category', payload['aps'])
            self.assertNotIn('badge', payload['aps'])
            self.assertEqual(args['device_token'], 'test-token')
            self.assertEqual(args['push_type'], 'alert')

    async def test_resolved_requests_and_disabled_accounts_do_not_notify(self):
        for status in ('accepted', 'declined'):
            self.request.status = status
            await self.send()
        self.request.status = 'pending'
        self.recipient.disabled_at = 'disabled'
        await self.send()
        self.client.send.assert_not_awaited()

    async def test_invalid_device_token_uses_shared_cleanup(self):
        self.client.send.return_value = APNSResult(succeeded=False, status_code=410, reason='Unregistered')
        await self.send()
        self.assertIsNone(self.device.push_token)
        self.assertIsNotNone(self.device.revoked_at)
        self.session.commit.assert_awaited_once()
