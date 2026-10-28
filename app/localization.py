import json
from functools import lru_cache
from pathlib import Path

from app.languages import DEFAULT_LANGUAGE_CODE, SUPPORTED_LANGUAGE_NAMES


@lru_cache(maxsize=8)
def _catalog(language: str) -> dict[str, str]:
    locale = language.split('-')[0]
    path = Path(__file__).parent / 'locales' / f'app_{locale}.arb'
    return json.loads(path.read_text(encoding='utf-8'))


def localized_text(language: str, key: str, **values: str) -> str:
    # 앱과 서버가 같은 원본을 읽어요. 서버 알림은 단순 치환 문구만 사용해요.
    language = language if language in SUPPORTED_LANGUAGE_NAMES else DEFAULT_LANGUAGE_CODE
    return _catalog(language)[key].format(**values)
