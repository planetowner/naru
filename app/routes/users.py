from typing import Annotated
from urllib.parse import urlsplit
from uuid import UUID, uuid4

from fastapi import APIRouter, BackgroundTasks, HTTPException, Query, Request, status
from fastapi.responses import RedirectResponse
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert

from app.dependencies import CurrentUserDependency, SessionDependency
from app.models import FriendRequest, MediaAsset, MediaKind, User, UserFriend
from app.notifications import send_friend_request_notification
from app.websocket_manager import connection_manager
from app.object_storage import get_object_storage_client
from app.schemas import (
    DisplayNameUpdate,
    FriendSearchRead,
    FriendRequestRead,
    FriendRequestResponse,
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
    return await _friend_search_result(session, current_user.id, user)


@router.post("/friends/{friend_id}", response_model=FriendSearchRead)
async def send_friend_request(
    friend_id: UUID,
    current_user: CurrentUserDependency,
    session: SessionDependency,
    background_tasks: BackgroundTasks,
) -> FriendSearchRead:
    if friend_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot add yourself")
    friend = await _active_user(session, friend_id)
    existing = await _friend_search_result(session, current_user.id, friend)
    if existing.is_friend:
        return existing
    # 중복·반대 방향 요청은 유지하고, 거절된 요청만 새 ID로 다시 보내요.
    # 수락과 전송이 겹쳐도 accepted 상태를 pending으로 되돌리지 않아요.
    request_id = await session.scalar(insert(FriendRequest).values(
        id=uuid4(), sender_id=current_user.id, recipient_id=friend.id, status="pending",
    ).on_conflict_do_update(
        index_elements=[func.least(FriendRequest.sender_id, FriendRequest.recipient_id),
                        func.greatest(FriendRequest.sender_id, FriendRequest.recipient_id)],
        set_={"id": uuid4(), "sender_id": current_user.id, "recipient_id": friend.id,
              "status": "pending", "created_at": func.now()},
        where=FriendRequest.status == "declined",
    ).returning(FriendRequest.id))
    await session.commit()
    if request_id is not None:
        await _publish_friends_changed(current_user.id, friend.id)
        background_tasks.add_task(send_friend_request_notification, request_id)
    return await _friend_search_result(session, current_user.id, friend)


@router.get("/friend-requests", response_model=list[FriendRequestRead])
async def list_friend_requests(
    current_user: CurrentUserDependency, session: SessionDependency,
) -> list[FriendRequestRead]:
    rows = await session.execute(select(FriendRequest.id, User).join(
        User, User.id == FriendRequest.sender_id,
    ).where(
        FriendRequest.recipient_id == current_user.id,
        FriendRequest.status == "pending", User.disabled_at.is_(None),
    ).order_by(FriendRequest.created_at, FriendRequest.id))
    return [FriendRequestRead(id=request_id, sender=UserRead.model_validate(sender))
            for request_id, sender in rows]


@router.post("/friend-requests/{request_id}/respond", status_code=status.HTTP_204_NO_CONTENT)
async def respond_to_friend_request(
    request_id: UUID, response: FriendRequestResponse,
    current_user: CurrentUserDependency, session: SessionDependency,
) -> None:
    request = await session.scalar(select(FriendRequest).where(
        FriendRequest.id == request_id,
        FriendRequest.recipient_id == current_user.id,
    ).with_for_update())
    if request is None:
        raise HTTPException(status_code=404, detail="Friend request not found")
    if request.status != "pending":
        raise HTTPException(status_code=409, detail="Friend request already resolved")
    await _active_user(session, request.sender_id)
    if response.decision == "accept":
        await session.execute(insert(UserFriend).values([
            {"user_id": request.sender_id, "friend_id": request.recipient_id},
            {"user_id": request.recipient_id, "friend_id": request.sender_id},
        ]).on_conflict_do_nothing())
    request.status = "accepted" if response.decision == "accept" else "declined"
    await session.commit()
    await _publish_friends_changed(request.sender_id, request.recipient_id)


async def _friend_search_result(
    session: SessionDependency, user_id: UUID, other: User,
) -> FriendSearchRead:
    friendship = await session.get(UserFriend, (user_id, other.id))
    result = FriendSearchRead(user=UserRead.model_validate(other), is_friend=friendship is not None)
    if result.is_friend:
        return result
    request = await session.scalar(select(FriendRequest).where(
        func.least(FriendRequest.sender_id, FriendRequest.recipient_id) == min(user_id, other.id),
        func.greatest(FriendRequest.sender_id, FriendRequest.recipient_id) == max(user_id, other.id),
        FriendRequest.status == "pending",
    ))
    if request is not None:
        if request.sender_id == user_id:
            result.outgoing_request_id = request.id
        else:
            result.incoming_request_id = request.id
    return result


async def _publish_friends_changed(*user_ids: UUID) -> None:
    for user_id in user_ids:
        await connection_manager.send_to_user(user_id, {"type": "friends.changed"})


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
