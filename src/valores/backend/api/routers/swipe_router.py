from fastapi import APIRouter, Depends, HTTPException, status, Query
from uuid import UUID
from typing import List

from ...models.schemas import SwipeRequest, LikeResponse
from ...services.auth_service import AuthService
from ...services.like_service import LikeService
from ...services.swipe_service import SwipeService

router = APIRouter(prefix="/swipes", tags=["swipes"])


async def get_user_id_from_token(
    access_token: str = Query(..., alias="access_token"),
    auth_service: AuthService = Depends(AuthService),
) -> UUID:
    """Extract user_id from the access token passed as query parameter."""
    try:
        client = await auth_service._client()
        response = await client.auth.get_user(access_token)
        if response is None or response.user is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
        return UUID(response.user.id)
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc))


async def get_swipe_service(
    access_token: str = Query(..., alias="access_token"),
    auth_service: AuthService = Depends(AuthService),
) -> SwipeService:
    """Create a SwipeService with the user's authenticated client."""
    return SwipeService(await auth_service._client())


async def get_like_service(
    access_token: str = Query(..., alias="access_token"),
    auth_service: AuthService = Depends(AuthService),
) -> LikeService:
    """Create a LikeService with the user's authenticated client."""
    return LikeService(await auth_service._client())


@router.post("", response_model=LikeResponse, status_code=status.HTTP_200_OK)
async def create_swipe(
    request: SwipeRequest,
    user_id: UUID = Depends(get_user_id_from_token),
    swipe_service: SwipeService = Depends(get_swipe_service),
    like_service: LikeService = Depends(get_like_service),
):
    """
    Record a swipe on another user's board.

    A ``right`` swipe also creates a like and checks for a mutual match,
    returning ``is_match`` and the ``conversation_id`` when matched.
    A ``left`` swipe only records that the user was skipped.
    """
    try:
        await swipe_service.record_swipe(user_id, request.swiped_id, request.direction)

        if request.direction == "right":
            result = await like_service.like_user(user_id, request.swiped_id)
            return result

        return LikeResponse(is_match=False, conversation_id=None)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.get("", response_model=List[str], status_code=status.HTTP_200_OK)
async def get_swiped_ids(
    user_id: UUID = Depends(get_user_id_from_token),
    swipe_service: SwipeService = Depends(get_swipe_service),
):
    """Return the IDs of all users the current user has already swiped."""
    try:
        return await swipe_service.get_swiped_ids(user_id)
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
