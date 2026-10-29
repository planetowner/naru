import os
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch


os.environ.setdefault("OPENAI_API_KEY", "test-openai-api-key")
os.environ.setdefault("OPENAI_MODEL", "gpt-6.1-terra")

from app import translation


class TranslationTests(unittest.IsolatedAsyncioTestCase):
    samples = {
        "ko": "오늘 너무 춥지 않아?",
        "ja": "今日は晴れです",
        "zh-CN": "你好，明天见",
        "en": "We can meet tomorrow morning.",
        "es": "Nos vemos mañana por la mañana.",
        "fr": "Je suis content de te voir.",
        "de": "Wir sehen uns morgen früh.",
        "it": "Ci vediamo domani mattina.",
    }

    async def test_translate_message_uses_openai_responses_api(self) -> None:
        create_response = AsyncMock(
            return_value=SimpleNamespace(output_text="안녕하세요")
        )

        with patch.object(
            translation.openai_client.responses,
            "create",
            create_response,
        ):
            result = await translation.translate_message(
                "你好",
                source_language="zh-CN",
                target_language="ko",
                context_messages=("你今天好吗？",),
            )

        self.assertEqual(result.translated_text, "안녕하세요")
        self.assertEqual(result.provider, "openai")
        self.assertEqual(result.model, translation.TRANSLATION_MODEL)

        create_response.assert_awaited_once()
        request = create_response.await_args.kwargs
        self.assertEqual(request["model"], translation.TRANSLATION_MODEL)
        self.assertEqual(request["reasoning"], {"effort": "none"})
        self.assertEqual(request["instructions"], translation.build_system_prompt())
        self.assertIn("你好", request["input"])
        self.assertFalse(request["store"])

    async def test_translate_message_rejects_empty_openai_output(self) -> None:
        create_response = AsyncMock(
            return_value=SimpleNamespace(output_text="   ")
        )

        with patch.object(
            translation.openai_client.responses,
            "create",
            create_response,
        ):
            with self.assertRaisesRegex(
                RuntimeError,
                "OpenAI returned an empty translation",
            ):
                await translation.translate_message(
                    "你好",
                    source_language="zh-CN",
                    target_language="ko",
                )

    async def test_all_languages_use_the_receivers_language(self) -> None:
        samples = self.samples
        for source, text in samples.items():
            for target in samples:
                with self.subTest(source=source, target=target):
                    response = AsyncMock(return_value=SimpleNamespace(output_text=samples[target]))
                    with patch.object(translation.openai_client.responses, "create", response):
                        result = await translation.translate_message(text, source, target)
                    if source == target:
                        response.assert_not_awaited()
                    else:
                        response.assert_awaited_once()
                        request = response.await_args.kwargs
                        self.assertIn(f"발신자 설정 언어: {translation.language_name(source)}", request["input"])
                        self.assertIn(f"번역 언어: {translation.language_name(target)}", request["input"])
                        self.assertIn(text, request["input"])
                    self.assertEqual(result.target_language, target)
                    self.assertEqual(result.translated_text, samples[target])

    async def test_recipient_language_skips_api_regardless_of_sender_setting(self) -> None:
        response = AsyncMock()
        with patch.object(translation.openai_client.responses, "create", response):
            for target, text in self.samples.items():
                with self.subTest(target=target):
                    source = "en" if target != "en" else "ko"
                    result = await translation.translate_message(text, source, target)
                    self.assertEqual(result.translated_text, text)
        response.assert_not_awaited()

    async def test_korean_chat_letters_and_emoji_skip_api_for_korean_recipient(self) -> None:
        response = AsyncMock()
        with patch.object(translation.openai_client.responses, "create", response):
            for text in ("안녕하세요", "ㅋㅋㅋ", "ㅇㅇ", "안녕", "오늘 3시에 만나 😊"):
                with self.subTest(text=text):
                    result = await translation.translate_message(text, "zh-CN", "ko")
                    self.assertEqual(result.translated_text, text)
        response.assert_not_awaited()

    async def test_english_is_translated_even_when_both_users_choose_korean(self) -> None:
        response = AsyncMock(return_value=SimpleNamespace(output_text="안녕하세요"))
        with patch.object(translation.openai_client.responses, "create", response):
            result = await translation.translate_message("Hello", "ko", "ko")
        response.assert_awaited_once()
        self.assertEqual(result.translated_text, "안녕하세요")
        self.assertIn("이미 수신자의 언어라면 원문을 그대로", response.await_args.kwargs["instructions"])

    async def test_numbers_punctuation_and_emoji_skip_translation(self) -> None:
        response = AsyncMock()
        with patch.object(translation.openai_client.responses, "create", response):
            for text in ("123 😊", "?!", "👋🏽❤️"):
                result = await translation.translate_message(text, "en", "es")
                self.assertEqual(result.translated_text, text)
        response.assert_not_awaited()

    def test_mixed_scripts_still_need_translation(self) -> None:
        for language in translation.SUPPORTED_LANGUAGE_NAMES:
            for text in ("Hello 안녕하세요", "안녕하세요 Hello", "Hello 你好", "你好 안녕하세요",
                         "こんにちは 안녕하세요", "今日は good day です"):
                with self.subTest(language=language, text=text):
                    self.assertTrue(translation.should_translate_text(text, target_language=language))

    def test_ambiguous_short_text_is_not_skipped_as_the_wrong_language(self) -> None:
        for target in translation.SUPPORTED_LANGUAGE_NAMES:
            self.assertTrue(translation.should_translate_text("Hello", target_language=target))

    def test_missing_target_language_skips_translation(self) -> None:
        for language in (None, "", "   "):
            self.assertFalse(translation.should_translate_text("Hello", target_language=language))


if __name__ == "__main__":
    unittest.main()
