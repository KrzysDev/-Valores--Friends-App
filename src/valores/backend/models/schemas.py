from pydantic import BaseModel, EmailStr, Field
from typing import Any, Dict, Optional


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
    # Optional extra metadata for the user profile
    data: Optional[Dict[str, Any]] = None


class AuthResponseModel(BaseModel):
    """Standardised response returned by login / register endpoints.

    ``user`` is the raw user object from Supabase (type ``Any`` because we do
    not know the exact structure) and ``access_token`` is the JWT used for
    subsequent authorised calls.
    """

    user: Any
    access_token: Optional[str] = None
