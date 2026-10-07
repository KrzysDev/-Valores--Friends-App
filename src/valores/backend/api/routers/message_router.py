from fastapi import APIRouter, Depends, HTTPException, status, Query
from uuid import UUID
from typing import List, Dict, Any, Optional
from datetime import datetime

from ...models.schemas import MessageCreate, MessageResponse
from ...services.auth_service import AuthService
from ...services.message_service import MessageService
from ...services.conversation_service import ConversationService

router = APIRouter(prefix="/conversations/{conversation_id}/messages", tags=["messages"])


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


async def get_message_service(
    access_token: str = Query(..., alias="access_token"),
    auth_service: AuthService = Depends(AuthService),
) -> MessageService:
    """Create a MessageService with the user's authenticated client."""
    return MessageService(await auth_service._client())


async def get_conversation_service(
    access_token: str = Query(..., alias="access_token"),
    auth_service: AuthService = Depends(AuthService),
) -> ConversationService:
    """Create a ConversationService with the user's authenticated client."""
    return ConversationService(await auth_service._client())


@router.post("", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def send_message(
    conversation_id: UUID,
    request: MessageCreate,
    user_id: UUID = Depends(get_user_id_from_token),
    message_service: MessageService = Depends(get_message_service),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    """Send a message in a conversation."""
    try:
        # Verify user is participant
        is_participant = await conversation_service.verify_participant(conversation_id, user_id)
        if not is_participant:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a participant in this conversation")

        message = await message_service.send_message(conversation_id, user_id, request.content)
        
        return MessageResponse(
            id=message["id"],
            conversation_id=message["conversation_id"],
            sender_id=message["id_user_1"],
            content=message["content"],
            sent_at=message["sent_at"],
            status=message["status"]
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.get("", response_model=List[MessageResponse], status_code=status.HTTP_200_OK)
async def get_messages(
    conversation_id: UUID,
    limit: int = Query(50, ge=1, le=100),
    before: Optional[str] = Query(None, description="ISO timestamp to fetch messages before"),
    user_id: UUID = Depends(get_user_id_from_token),
    message_service: MessageService = Depends(get_message_service),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    """Get messages for a conversation with pagination."""
    try:
        # Verify user is participant
        is_participant = await conversation_service.verify_participant(conversation_id, user_id)
        if not is_participant:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a participant in this conversation")

        messages = await message_service.get_messages(
            conversation_id=conversation_id,
            user_id=user_id,
            limit=limit,
            before=before
        )

        return [
            MessageResponse(
                id=msg["id"],
                conversation_id=msg["conversation_id"],
                sender_id=msg["id_user_1"],
                content=msg["content"],
                sent_at=msg["sent_at"],
                status=msg["status"]
            )
            for msg in messages
        ]
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.patch("/read", status_code=status.HTTP_200_OK)
async def mark_messages_read(
    conversation_id: UUID,
    user_id: UUID = Depends(get_user_id_from_token),
    message_service: MessageService = Depends(get_message_service),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    """Mark all unread messages in a conversation as read for the current user."""
    try:
        # Verify user is participant
        is_participant = await conversation_service.verify_participant(conversation_id, user_id)
        if not is_participant:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a participant in this conversation")

        count = await message_service.mark_as_read(conversation_id, user_id)
        return {"marked_as_read": count}
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.get("/unread-count", status_code=status.HTTP_200_OK)
async def get_unread_count(
    conversation_id: UUID,
    user_id: UUID = Depends(get_user_id_from_token),
    message_service: MessageService = Depends(get_message_service),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    """Get unread message count for a specific conversation."""
    try:
        # Verify user is participant
        is_participant = await conversation_service.verify_participant(conversation_id, user_id)
        if not is_participant:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a participant in this conversation")

        count = await message_service.get_conversation_unread_count(conversation_id, user_id)
        return {"unread_count": count}
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))