from typing import Literal


LanguageCode = Literal["ko", "ja", "zh-CN", "en", "es", "fr", "de", "it"]
DEFAULT_LANGUAGE_CODE: LanguageCode = "en"

SUPPORTED_LANGUAGE_NAMES: dict[LanguageCode, str] = {
    "ko": "한국어",
    "ja": "일본어",
    "zh-CN": "중국어 간체",
    "en": "영어",
    "es": "스페인어",
    "fr": "프랑스어",
    "de": "독일어",
    "it": "이탈리아어",
}
