from fastapi import APIRouter, Depends, HTTPException, status, Query
from uuid import UUID
from typing import List, Dict, Any

from ...models.schemas import Board
from ...services.auth_service import AuthService
from ...services.board_service import BoardService

router = APIRouter(prefix="/discover", tags=["discover"])


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


async def get_admin_board_service(
    auth_service: AuthService = Depends(AuthService),
) -> BoardService:
    """Create a BoardService with the admin client (bypasses RLS for discovery)."""
    return BoardService(await auth_service._admin_client())


@router.get("/boards", response_model=List[Dict[str, Any]])
async def discover_boards(
    youngest: int = Query(..., ge=13, le=100, description="Minimum age (inclusive)"),
    oldest: int = Query(..., ge=13, le=100, description="Maximum age (inclusive)"),
    access_token: str = Query(..., alias="access_token"),
    user_id: UUID = Depends(get_user_id_from_token),
    board_service: BoardService = Depends(get_admin_board_service),
    auth_service: AuthService = Depends(AuthService),
):
    """
    Discover boards filtered by age range.
    
    Returns boards of users whose age is between `youngest` and `oldest` (inclusive).
    Excludes the current user's own board.
    """
    if youngest > oldest:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="youngest cannot be greater than oldest"
        )
    
    try:
        # Get user IDs in the age range (excluding current user)
        user_ids = await auth_service.get_user_ids_by_age_range(
            youngest=youngest,
            oldest=oldest,
            exclude_user_id=str(user_id)
        )
        
        boards = await board_service.get_boards_by_user_ids(user_ids)
        
        return boards
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))