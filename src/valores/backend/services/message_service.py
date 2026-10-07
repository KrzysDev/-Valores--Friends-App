from uuid import UUID
from typing import List, Dict, Any, Optional
from datetime import datetime

from supabase import AsyncClient


class MessageService:
    """Service for managing messages in conversations."""

    def __init__(self, client: AsyncClient) -> None:
        self._client = client

    async def send_message(
        self,
        conversation_id: UUID,
        sender_id: UUID,
        content: str
    ) -> Dict[str, Any]:
        """
        Send a message in a conversation.

        Determines the recipient based on conversation participants.
        """
        # Get conversation to find recipient
        conv_result = await (
            self._client.table("conversations")
            .select("id_user_1, id_user_2")
            .eq("id", str(conversation_id))
            .single()
            .execute()
        )

        if not conv_result.data:
            raise ValueError("Conversation not found")

        conversation = conv_result.data
        recipient_id = (
            conversation["id_user_2"]
            if conversation["id_user_1"] == str(sender_id)
            else conversation["id_user_1"]
        )

        # Insert message
        message_data = {
            "conversation_id": str(conversation_id),
            "id_user_1": str(sender_id),
            "id_user_2": recipient_id,
            "content": content,
            "status": "unread"
        }

        result = await self._client.table("messages").insert(message_data).execute()

        if not result.data:
            raise RuntimeError("Failed to send message")

        message = result.data[0]

        # Update conversation's updated_at timestamp
        await (
            self._client.table("conversations")
            .update({"updated_at": "now()"})
            .eq("id", str(conversation_id))
            .execute()
        )

        return message

    async def get_messages(
        self,
        conversation_id: UUID,
        user_id: UUID,
        limit: int = 50,
        before: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get messages for a conversation with pagination.

        Args:
            conversation_id: The conversation ID
            user_id: The requesting user (for verification)
            limit: Maximum number of messages to return
            before: ISO timestamp to fetch messages before (for pagination)
        """
        # Verify user is participant
        conv_result = await (
            self._client.table("conversations")
            .select("id_user_1, id_user_2")
            .eq("id", str(conversation_id))
            .single()
            .execute()
        )

        if not conv_result.data:
            raise ValueError("Conversation not found")

        conversation = conv_result.data
        if conversation["id_user_1"] != str(user_id) and conversation["id_user_2"] != str(user_id):
            raise ValueError("Not a participant in this conversation")

        query = (
            self._client.table("messages")
            .select("*")
            .eq("conversation_id", str(conversation_id))
            .order("sent_at", desc=True)
            .limit(limit)
        )

        if before:
            query = query.lt("sent_at", before)

        result = await query.execute()

        messages = result.data if result.data else []
        # Return in chronological order (oldest first)
        return list(reversed(messages))

    async def mark_as_read(
        self,
        conversation_id: UUID,
        user_id: UUID
    ) -> int:
        """
        Mark all unread messages in a conversation as read for the given user.

        Returns the number of messages marked as read.
        """
        # Verify user is participant
        conv_result = await (
            self._client.table("conversations")
            .select("id_user_1, id_user_2")
            .eq("id", str(conversation_id))
            .single()
            .execute()
        )

        if not conv_result.data:
            raise ValueError("Conversation not found")

        # Update messages where user is the recipient (id_user_2) and status is unread
        result = await (
            self._client.table("messages")
            .update({"status": "read"})
            .eq("conversation_id", str(conversation_id))
            .eq("id_user_2", str(user_id))
            .eq("status", "unread")
            .execute()
        )

        return len(result.data) if result.data else 0

    async def get_unread_count(self, user_id: UUID) -> int:
        """Get total unread message count for a user across all conversations."""
        result = await self._client.rpc(
            "get_unread_message_count",
            {"p_user_id": str(user_id)}
        ).execute()

        return result.data if result.data else 0

    async def get_conversation_unread_count(
        self,
        conversation_id: UUID,
        user_id: UUID
    ) -> int:
        """Get unread message count for a specific conversation."""
        result = await (
            self._client.table("messages")
            .select("id", count="exact")
            .eq("conversation_id", str(conversation_id))
            .eq("id_user_2", str(user_id))
            .eq("status", "unread")
            .execute()
        )

        return result.count if result.count else 0
