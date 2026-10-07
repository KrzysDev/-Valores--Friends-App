from fastapi import APIRouter, Depends, HTTPException, status, Query
from uuid import UUID
from typing import List

from ...models.schemas import LikeRequest, LikeResponse, MatchResponse
from ...services.auth_service import AuthService
from ...services.like_service import LikeService

router = APIRouter(prefix="/likes", tags=["likes"])


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


async def get_like_service(
    access_token: str = Query(..., alias="access_token"),
    auth_service: AuthService = Depends(AuthService),
) -> LikeService:
    """Create a LikeService with the user's authenticated client."""
    return LikeService(await auth_service._client())


@router.post("", response_model=LikeResponse, status_code=status.HTTP_200_OK)
async def like_user(
    request: LikeRequest,
    user_id: UUID = Depends(get_user_id_from_token),
    like_service: LikeService = Depends(get_like_service),
):
    """
    Like another user (press "+").
    
    Returns whether this created a match and the conversation ID if matched.
    """
    try:
        # Check if already liked
        already_liked = await like_service.has_liked(user_id, request.liked_id)
        if already_liked:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Already liked this user"
            )

        result = await like_service.like_user(user_id, request.liked_id)
        return result
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.delete("/{liked_id}", status_code=status.HTTP_200_OK)
async def unlike_user(
    liked_id: UUID,
    user_id: UUID = Depends(get_user_id_from_token),
    like_service: LikeService = Depends(get_like_service),
):
    """Remove a like (unlike)."""
    try:
        await like_service.unlike_user(user_id, liked_id)
        return {"detail": "like removed"}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.get("/matches", response_model=List[MatchResponse], status_code=status.HTTP_200_OK)
async def get_matches(
    user_id: UUID = Depends(get_user_id_from_token),
    like_service: LikeService = Depends(get_like_service),
):
    """
    Get all matches (conversations) for the current user.
    
    Returns list of conversations with the other user's ID.
    """
    try:
        matches = await like_service.get_user_matches(user_id)
        return matches
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))