from typing import Annotated
from urllib.parse import urlsplit
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request, status
from fastapi.responses import RedirectResponse
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert

from app.dependencies import CurrentUserDependency, SessionDependency
from app.models import MediaAsset, MediaKind, User, UserFriend
from app.object_storage import get_object_storage_client
from app.schemas import (
    DisplayNameUpdate,
    FriendSearchRead,
    ProfileUpdate,
    PasswordChangeRequest,
    UserRead,
)
from app.passwords import hash_password, verify_password


router = APIRouter(
    prefix="/users",
    tags=["users"],
)


@router.get(
    "/me",
    response_model=UserRead,
)
async def read_current_user(
    current_user: CurrentUserDependency,
) -> User:
    return current_user


@router.patch(
    "/me/display-name",
    response_model=UserRead,
)
async def update_display_name(
    display_name_data: DisplayNameUpdate,
    current_user: CurrentUserDependency,
    session: SessionDependency,
) -> User:
    current_user.display_name = display_name_data.display_name

    await session.commit()
    await session.refresh(current_user)

    return current_user


@router.patch(
    "/me/password",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def change_password(
    password_data: PasswordChangeRequest,
    current_user: CurrentUserDependency,
    session: SessionDependency,
) -> None:
    if not verify_password(
        password_data.current_password,
        current_user.password_hash,
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )

    if verify_password(
        password_data.new_password,
        current_user.password_hash,
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from current password",
        )

    current_user.password_hash = hash_password(
        password_data.new_password
    )

    # 비밀번호를 바꾸면 이전에 발급한 모든 액세스 토큰을 무효화해요.
    current_user.token_version += 1

    await session.commit()


@router.get(
    "",
    response_model=list[UserRead],
)
async def list_users(
    session: SessionDependency,
    current_user: CurrentUserDependency,
) -> list[UserRead]:
    result = await session.scalars(
        select(User).join(UserFriend, UserFriend.friend_id == User.id).where(
            UserFriend.user_id == current_user.id,
            User.disabled_at.is_(None),
        ).order_by(User.id)
    )

    return [UserRead.model_validate(user) for user in result]


@router.patch("/me", response_model=UserRead)
async def update_profile(
    profile: ProfileUpdate,
    request: Request,
    current_user: CurrentUserDependency,
    session: SessionDependency,
) -> User:
    if profile.photo_asset_id is not None:
        await _profile_photo(session, current_user.id, profile.photo_asset_id)
        # 서명 주소는 만료되므로, 현재 프로필 사진을 조회하는 고정 주소를 저장해요.
        current_user.profile_image_url = str(request.url_for(
            "read_profile_photo", user_id=current_user.id, media_asset_id=profile.photo_asset_id,
        ))
    current_user.display_name = profile.display_name
    current_user.preferred_language = profile.preferred_language
    await session.commit()
    await session.refresh(current_user)
    return current_user


@router.get("/search", response_model=FriendSearchRead | None)
async def search_user(
    username: Annotated[str, Query(min_length=1, max_length=50)],
    current_user: CurrentUserDependency,
    session: SessionDependency,
) -> FriendSearchRead | None:
    user = await session.scalar(select(User).where(
        User.username == username.strip(),
        User.id != current_user.id,
        User.disabled_at.is_(None),
    ))
    if user is None:
        return None
    friendship = await session.get(UserFriend, (current_user.id, user.id))
    return FriendSearchRead(user=UserRead.model_validate(user), is_friend=friendship is not None)


@router.post("/friends/{friend_id}", response_model=UserRead)
async def add_friend(
    friend_id: UUID,
    current_user: CurrentUserDependency,
    session: SessionDependency,
) -> User:
    if friend_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot add yourself")
    friend = await _active_user(session, friend_id)
    # 중복 탭이나 재시도에도 같은 친구 관계를 하나만 저장해요.
    await session.execute(insert(UserFriend).values(
        user_id=current_user.id, friend_id=friend.id,
    ).on_conflict_do_nothing())
    await session.commit()
    return friend


async def _active_user(session: SessionDependency, user_id: UUID) -> User:
    user = await session.get(User, user_id)
    if user is None or user.disabled_at is not None:
        raise HTTPException(status_code=404, detail="User not found")
    return user


async def _profile_photo(
    session: SessionDependency, user_id: UUID, media_asset_id: UUID,
) -> MediaAsset:
    asset = await session.get(MediaAsset, media_asset_id)
    if (asset is None or asset.owner_user_id != user_id or asset.kind != MediaKind.PHOTO
            or asset.upload_status != "complete" or not asset.storage_key):
        raise HTTPException(status_code=404, detail="Profile photo not found")
    return asset


@router.get("/{user_id}/photo/{media_asset_id}", name="read_profile_photo")
async def read_profile_photo(
    user_id: UUID, media_asset_id: UUID, session: SessionDependency,
) -> RedirectResponse:
    user = await _active_user(session, user_id)
    expected_path = f"/users/{user_id}/photo/{media_asset_id}"
    # 알림도 인증 헤더 없이 사진을 읽어요. 현재 프로필로 지정한 사진만 공개해요.
    if not user.profile_image_url or urlsplit(user.profile_image_url).path != expected_path:
        raise HTTPException(status_code=404, detail="Profile photo not found")
    asset = await _profile_photo(session, user_id, media_asset_id)
    try:
        url = get_object_storage_client().presigned_get_url(storage_key=asset.storage_key)
    except RuntimeError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    return RedirectResponse(url, headers={"Cache-Control": "no-store"})


@router.get("/{user_id}", response_model=UserRead)
async def read_user(
    user_id: UUID, current_user: CurrentUserDependency, session: SessionDependency,
) -> User:
    # 친구 목록에 없어도 받은 메시지 알림에서 대화를 열 수 있어요.
    return await _active_user(session, user_id)
