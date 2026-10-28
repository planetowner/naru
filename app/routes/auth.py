from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert

from app.dependencies import SessionDependency, get_user_for_token
from app.models import User
from app.schemas import (
    LoginRequest,
    RegisterRequest,
    RefreshTokenRequest,
    TokenResponse,
    UserRead,
)
from app.passwords import hash_password, verify_password
from app.security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
)


router = APIRouter(
    prefix="/auth",
    tags=["auth"],
)


def _token_response(user: User) -> TokenResponse:
    return TokenResponse(
        access_token=create_access_token(
            user_id=user.id,
            token_version=user.token_version,
        ),
        refresh_token=create_refresh_token(
            user_id=user.id,
            token_version=user.token_version,
        ),
        token_type="bearer",
        user=UserRead.model_validate(user),
    )


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    registration: RegisterRequest,
    session: SessionDependency,
) -> TokenResponse:
    if registration.password != registration.password_confirmation:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Passwords do not match",
        )

    # CITEXT의 고유 제약으로 대소문자가 다른 아이디와 동시 가입도 함께 처리해요.
    user = await session.scalar(
        insert(User)
        .values(
            username=registration.username,
            display_name=registration.username,
            password_hash=hash_password(registration.password),
        )
        .on_conflict_do_nothing(index_elements=[User.username])
        .returning(User)
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This username is already taken",
        )

    await session.commit()
    return _token_response(user)


@router.post(
    "/login",
    response_model=TokenResponse,
)
async def login(
    login_data: LoginRequest,
    session: SessionDependency,
) -> TokenResponse:
    user = await session.scalar(
        select(User).where(
            User.username == login_data.username
        )
    )

    if user is None or not verify_password(
        login_data.password,
        user.password_hash,
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
            headers={
                "WWW-Authenticate": "Bearer",
            },
        )

    return _token_response(user)


@router.post(
    "/refresh",
    response_model=TokenResponse,
)
async def refresh_session(
    refresh_data: RefreshTokenRequest,
    session: SessionDependency,
) -> TokenResponse:
    authentication_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not refresh session",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        user_id, token_version = decode_refresh_token(
            refresh_data.refresh_token
        )
    except ValueError:
        raise authentication_error

    user = await get_user_for_token(
        session,
        user_id=user_id,
        token_version=token_version,
    )

    if user is None:
        raise authentication_error

    return _token_response(user)
