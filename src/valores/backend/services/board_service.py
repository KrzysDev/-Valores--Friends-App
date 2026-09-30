from typing import Any, Dict, List, Optional
from uuid import UUID

from supabase import Client

from ..models.schemas import Board


class BoardService:
    """Service for managing user boards."""

    def __init__(self, client: Client) -> None:
        self._client = client

    def create_board(self, user_id: UUID, board: Board) -> Dict[str, Any]:
        """Create a new board for the given user."""
        board_data = board.model_dump(mode="json")
        response = (
            self._client.table("boards")
            .insert(
                {
                    "user_id": str(user_id),
                    "board": board_data,
                }
            )
            .execute()
        )
        if not response.data:
            raise RuntimeError("Failed to create board")
        return response.data[0]

    def get_board(self, user_id: UUID) -> Optional[Dict[str, Any]]:
        """Get the board for a user (assuming one board per user)."""
        response = (
            self._client.table("boards")
            .select("*")
            .eq("user_id", str(user_id))
            .single()
            .execute()
        )
        return response.data

    def delete_board(self, user_id: UUID) -> None:
        """Delete the board for a user."""
        self._client.table("boards").delete().eq("user_id", str(user_id)).execute()

    def delete_board_by_id(self, board_id: UUID, user_id: UUID) -> None:
        """Delete a specific board by ID (ensuring ownership)."""
        self._client.table("boards").delete().eq("id", str(board_id)).eq("user_id", str(user_id)).execute()

    def get_boards_by_user_ids(self, user_ids: List[str]) -> List[Dict[str, Any]]:
        """Get boards for a list of user IDs."""
        if not user_ids:
            return []
        response = (
            self._client.table("boards")
            .select("*")
            .in_("user_id", user_ids)
            .execute()
        )
        return response.data if response.data else []