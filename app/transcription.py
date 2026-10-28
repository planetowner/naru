from __future__ import annotations

import asyncio
import os

from app.models import MediaAsset
from app.object_storage import get_object_storage_client
from app.translation import openai_client


TRANSCRIPTION_MODEL = os.getenv(
    "OPENAI_TRANSCRIPTION_MODEL", "gpt-transcribe"
).strip()
# 파일 전사 API는 25MB까지 받아요. 녹음은 그대로 보관하고 한도를 넘으면 변환만 실패해요.
MAX_TRANSCRIPTION_BYTES = 25_000_000


async def transcribe_voice_memo(asset: MediaAsset) -> str:
    if asset.storage_key is None or asset.upload_status != "complete":
        raise ValueError("Voice memo upload is not complete.")
    if asset.size_bytes is not None and asset.size_bytes > MAX_TRANSCRIPTION_BYTES:
        raise ValueError("Voice memo exceeds the 25 MB transcription limit.")

    storage = get_object_storage_client()
    audio = await asyncio.to_thread(
        storage.read_object,
        storage_key=asset.storage_key,
        max_bytes=MAX_TRANSCRIPTION_BYTES,
    )
    response = await openai_client.audio.transcriptions.create(
        model=TRANSCRIPTION_MODEL,
        file=(
            asset.file_name or "voice-memo.m4a",
            audio,
            asset.mime_type or "audio/mp4",
        ),
    )
    text = response.text.strip()
    if not text:
        raise ValueError("No speech was transcribed from the voice memo.")
    return text
