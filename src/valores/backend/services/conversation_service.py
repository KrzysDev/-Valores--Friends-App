import asyncio
from uuid import UUID
from typing import List, Dict, Any, Optional

from supabase import AsyncClient


class ConversationService:
    """Service for managing conversations."""

    def __init__(self, client: AsyncClient) -> None:
        self._client = client

    async def _get_display_name(self, other_user_id: str) -> Optional[str]:
        """Look up the other user's display name from user_profiles.

        The profile stores the first name in the ``name`` column. Falls back to
        ``nickname`` for older rows, and to ``None`` when neither is available.
        """
        for column in ("name", "nickname"):
            try:
                profile_result = await (
                    self._client.table("user_profiles")
                    .select(column)
                    .eq("user_id", other_user_id)
                    .limit(1)
                    .execute()
                )
                if profile_result.data:
                    value = profile_result.data[0].get(column)
                    if value:
                        return value
            except Exception:
                # column doesn't exist yet, try the next one
                continue
        return None

    async def get_user_conversations(self, user_id: UUID) -> List[Dict[str, Any]]:
        """
        Get all conversations for a user with last message and unread count.
        """
        # Get matches from the database function
        result = await self._client.rpc(
            "get_user_matches",
            {"p_user_id": str(user_id)}
        ).execute()

        if not result.data:
            return []

        async def build_conversation(match: Dict[str, Any]) -> Dict[str, Any]:
            conversation_id = match.get("conversation_id") or match.get("id")
            other_user_id = match["other_user_id"]

            # Get last message for this conversation
            last_msg_result = await (
                self._client.table("messages")
                .select("*")
                .eq("conversation_id", conversation_id)
                .order("sent_at", desc=True)
                .limit(1)
                .execute()
            )
            last_message = last_msg_result.data[0] if last_msg_result.data else None

            # Get unread count for this conversation
            unread_result = await (
                self._client.table("messages")
                .select("id", count="exact")
                .eq("conversation_id", conversation_id)
                .eq("id_user_2", str(user_id))
                .eq("status", "unread")
                .execute()
            )
            unread_count = unread_result.count if unread_result.count else 0

            # Get other user's display name from user_profiles
            nickname = await self._get_display_name(other_user_id)

            return {
                "id": conversation_id,
                "other_user_id": other_user_id,
                "other_user_nickname": nickname,
                "last_message": last_message,
                "unread_count": unread_count,
                "updated_at": match.get("updated_at") or match.get("created_at"),
            }

        # Run the per-conversation queries concurrently instead of one by one.
        conversations = list(
            await asyncio.gather(*(build_conversation(m) for m in result.data))
        )

        # Sort by updated_at descending (most recent first)
        conversations.sort(key=lambda x: x["updated_at"], reverse=True)

        return conversations

    async def get_conversation(self, conversation_id: UUID, user_id: UUID) -> Optional[Dict[str, Any]]:
        """Get a specific conversation with details."""
        # Verify user is part of this conversation
        result = await (
            self._client.table("conversations")
            .select("*")
            .eq("id", str(conversation_id))
            .execute()
        )

        if not result.data:
            return None

        conversation = result.data[0]
        if conversation["id_user_1"] != str(user_id) and conversation["id_user_2"] != str(user_id):
            return None

        other_user_id = conversation["id_user_2"] if conversation["id_user_1"] == str(user_id) else conversation["id_user_1"]

        # Get other user's display name
        nickname = await self._get_display_name(other_user_id)

        # Get unread count
        unread_result = await (
            self._client.table("messages")
            .select("id", count="exact")
            .eq("conversation_id", str(conversation_id))
            .eq("id_user_2", str(user_id))
            .eq("status", "unread")
            .execute()
        )

        unread_count = unread_result.count if unread_result.count else 0

        return {
            "id": conversation["id"],
            "other_user_id": other_user_id,
            "other_user_nickname": nickname,
            "unread_count": unread_count,
            "created_at": conversation["created_at"],
            "updated_at": conversation["updated_at"]
        }

    async def verify_participant(self, conversation_id: UUID, user_id: UUID) -> bool:
        """Verify that a user is a participant in a conversation."""
        result = await (
            self._client.table("conversations")
            .select("id_user_1, id_user_2")
            .eq("id", str(conversation_id))
            .execute()
        )

        if not result.data:
            return False

        conversation = result.data[0]
        return conversation["id_user_1"] == str(user_id) or conversation["id_user_2"] == str(user_id)

    async def update_conversation_timestamp(self, conversation_id: UUID) -> None:
        """Update the conversation's updated_at timestamp."""
        # The trigger on the conversations table handles this automatically
        # when a message is inserted, but we can also manually trigger it
        await (
            self._client.table("conversations")
            .update({"updated_at": "now()"})
            .eq("id", str(conversation_id))
            .execute()
        )
