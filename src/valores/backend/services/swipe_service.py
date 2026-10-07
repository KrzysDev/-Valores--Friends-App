from uuid import UUID
from typing import List

from supabase import Client


class SwipeService:
    """Service for recording swipes so seen users are not shown again."""

    def __init__(self, client: Client) -> None:
        self._client = client

    async def record_swipe(self, swiper_id: UUID, swiped_id: UUID, direction: str) -> None:
        """Record a swipe (left = skip, right = like) for the given user.

        Uses the ``record_swipe`` database function (SECURITY DEFINER) so the
        write does not depend on the anon client carrying a user session.
        Idempotent: swiping the same user twice simply updates the direction.
        """
        if swiper_id == swiped_id:
            raise ValueError("Cannot swipe yourself")
        if direction not in ("left", "right"):
            raise ValueError("direction must be 'left' or 'right'")

        self._client.rpc(
            "record_swipe",
            {
                "p_swiper_id": str(swiper_id),
                "p_swiped_id": str(swiped_id),
                "p_direction": direction,
            },
        ).execute()

    async def get_swiped_ids(self, user_id: UUID) -> List[str]:
        """Return the IDs of all users the given user has already swiped."""
        result = self._client.rpc(
            "get_swiped_ids",
            {"p_user_id": str(user_id)},
        ).execute()

        if not result.data:
            return []
        return [str(row["swiped_id"]) for row in result.data]
