from pydantic import BaseModel, EmailStr, Field
from typing import Any, Dict, List, Optional
from uuid import UUID
from datetime import datetime


class Block(BaseModel):
    """A single block on a user's aesthetic board."""
    name: str
    description: str


class Board(BaseModel):
    """A user's aesthetic board containing multiple blocks."""
    blocks: list[Block]


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1)


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1)
    age: int = Field(..., ge=13, le=100)



class AuthResponseModel(BaseModel):
    """Standardised response returned by login / register endpoints.

    ``user`` is the raw user object from Supabase (type ``Any`` because we do
    not know the exact structure) and ``access_token`` is the JWT used for
    subsequent authorised calls.
    """

    user: Any
    access_token: Optional[str] = None


class LikeRequest(BaseModel):
    liked_id: UUID


class LikeResponse(BaseModel):
    is_match: bool
    conversation_id: Optional[UUID] = None


class MessageCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=5000)


class MessageResponse(BaseModel):
    id: UUID
    conversation_id: UUID
    sender_id: UUID
    content: str
    sent_at: datetime
    status: str  # 'read' | 'unread'


class ConversationResponse(BaseModel):
    id: UUID
    other_user_id: UUID
    other_user_nickname: Optional[str] = None
    last_message: Optional[MessageResponse] = None
    unread_count: int
    updated_at: datetime


class MatchResponse(BaseModel):
    conversation_id: UUID
    other_user_id: UUID
    created_at: datetime
