from fastapi import APIRouter, Depends, HTTPException, status, Query
from uuid import UUID
from typing import List, Dict, Any

from ...services.auth_service import AuthService
from ...services.conversation_service import ConversationService

router = APIRouter(prefix="/conversations", tags=["conversations"])


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


async def get_conversation_service(
    access_token: str = Query(..., alias="access_token"),
    auth_service: AuthService = Depends(AuthService),
) -> ConversationService:
    """Create a ConversationService with the user's authenticated client."""
    return ConversationService(await auth_service._client())


@router.get("", response_model=List[Dict[str, Any]], status_code=status.HTTP_200_OK)
async def get_conversations(
    user_id: UUID = Depends(get_user_id_from_token),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    """
    Get all conversations for the current user.
    
    Returns list of conversations with last message preview and unread count.
    """
    try:
        conversations = await conversation_service.get_user_conversations(user_id)
        return conversations
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.get("/{conversation_id}", response_model=Dict[str, Any], status_code=status.HTTP_200_OK)
async def get_conversation(
    conversation_id: UUID,
    user_id: UUID = Depends(get_user_id_from_token),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    """Get details of a specific conversation."""
    try:
        conversation = await conversation_service.get_conversation(conversation_id, user_id)
        if not conversation:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
        return conversation
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))