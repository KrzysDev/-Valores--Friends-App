from uuid import UUID
from typing import List, Dict, Any, Optional

from supabase import Client

from ..models.schemas import LikeResponse, MatchResponse


class LikeService:
    """Service for managing likes and match detection."""

    def __init__(self, client: Client) -> None:
        self._client = client

    async def like_user(self, liker_id: UUID, liked_id: UUID) -> LikeResponse:
        """
        Create a like and check for mutual match.
        Calls the database function create_like_and_check_match.
        """
        if liker_id == liked_id:
            raise ValueError("Cannot like yourself")

        result = self._client.rpc(
            "create_like_and_check_match",
            {"p_liker_id": str(liker_id), "p_liked_id": str(liked_id)}
        ).execute()

        if not result.data:
            raise RuntimeError("Failed to process like")

        data = result.data[0]
        return LikeResponse(
            is_match=data["is_match"],
            conversation_id=data["conversation_id"] if data["conversation_id"] else None
        )

    async def unlike_user(self, liker_id: UUID, liked_id: UUID) -> bool:
        """Remove a like (unlike)."""
        result = self._client.table("likes").delete().eq(
            "liker_id", str(liker_id)
        ).eq("liked_id", str(liked_id)).execute()

        return True

    async def get_user_matches(self, user_id: UUID) -> List[MatchResponse]:
        """Get all matches (conversations) for a user."""
        result = self._client.rpc(
            "get_user_matches",
            {"p_user_id": str(user_id)}
        ).execute()

        matches = []
        if result.data:
            for row in result.data:
                matches.append(MatchResponse(
                    conversation_id=row["conversation_id"] if "conversation_id" in row else row["id"],
                    other_user_id=row["other_user_id"],
                    created_at=row["created_at"]
                ))
        return matches

    async def has_liked(self, liker_id: UUID, liked_id: UUID) -> bool:
        """Check if user has already liked another user."""
        result = self._client.table("likes").select("id").eq(
            "liker_id", str(liker_id)
        ).eq("liked_id", str(liked_id)).execute()

        return bool(result.data)

    async def get_likes_received(self, user_id: UUID) -> List[Dict[str, Any]]:
        """Get all likes received by a user."""
        result = self._client.table("likes").select(
            "id, liker_id, created_at"
        ).eq("liked_id", str(user_id)).execute()

        return result.data if result.data else []

    async def get_likes_given(self, user_id: UUID) -> List[Dict[str, Any]]:
        """Get all likes given by a user."""
        result = self._client.table("likes").select(
            "id, liked_id, created_at"
        ).eq("liker_id", str(user_id)).execute()

        return result.data if result.data else []