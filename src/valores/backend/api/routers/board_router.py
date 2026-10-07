from fastapi import APIRouter, Depends, HTTPException, status, Query
from uuid import UUID
from typing import Any, Dict, Optional

from ...models.schemas import Board
from ...services.auth_service import AuthService
from ...services.board_service import BoardService

router = APIRouter(prefix="/boards", tags=["boards"])


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


async def get_board_service(
    access_token: str = Query(..., alias="access_token"),
    auth_service: AuthService = Depends(AuthService),
) -> BoardService:
    """Create a BoardService with the user's authenticated client."""
    return BoardService(await auth_service._client())


@router.get("/me", response_model=Optional[Dict[str, Any]], status_code=status.HTTP_200_OK)
async def get_my_board(
    access_token: str = Query(..., alias="access_token"),
    user_id: UUID = Depends(get_user_id_from_token),
    board_service: BoardService = Depends(get_board_service),
):
    """Return the authenticated user's own board (or ``null`` if none exists)."""
    try:
        return await board_service.get_board(user_id)
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_board(
    board: Board,
    access_token: str = Query(..., alias="access_token"),
    user_id: UUID = Depends(get_user_id_from_token),
    board_service: BoardService = Depends(get_board_service),
):
    """Create a new board for the authenticated user."""
    try:
        result = await board_service.create_board(user_id, board)
        return {"board": result}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.delete("/{board_id}", status_code=status.HTTP_200_OK)
async def delete_board_by_id(
    board_id: UUID,
    access_token: str = Query(..., alias="access_token"),
    user_id: UUID = Depends(get_user_id_from_token),
    board_service: BoardService = Depends(get_board_service),
):
    """Delete a specific board by ID (must belong to the authenticated user)."""
    try:
        await board_service.delete_board_by_id(board_id, user_id)
        return {"detail": "board deleted"}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))