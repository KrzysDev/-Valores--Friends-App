from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, EmailStr, Field
from typing import Any, Dict, Optional

from ...models.schemas import LoginRequest, RegisterRequest, AuthResponseModel
from ...services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["auth"])

security = HTTPBearer()


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1)


@router.post("/login", response_model=AuthResponseModel, status_code=status.HTTP_200_OK)
async def login(request: LoginRequest, service: AuthService = Depends(AuthService)):
    """Log a user in and return the session data.

    The Supabase client returns an object containing ``user`` and ``session``.
    We forward those fields (including the access token) to the caller.
    """
    try:
        resp = await service.login(request.email, request.password)
        return {
            "user": resp.user,
            "access_token": getattr(resp.session, "access_token", None),
        }
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.post("/register", response_model=AuthResponseModel, status_code=status.HTTP_201_CREATED)
async def register(request: RegisterRequest, service: AuthService = Depends(AuthService)):
    """Create a new user account.

    ``age`` and ``name`` are required and stored in the user_profiles table
    (age for filtering, name for display).
    """
    try:
        resp = await service.register(request.email, request.password, request.age, request.name)
        return {
            "user": resp.user,
            "access_token": getattr(resp.session, "access_token", None),
        }
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.delete("/account", response_model=Dict[str, str], status_code=status.HTTP_200_OK)
async def delete_account(access_token: str, service: AuthService = Depends(AuthService)):
    """Delete the currently authenticated user's account.

    The caller must provide a valid Bearer token in the Authorization header.
    """
    try:
        await service.delete_account(access_token)
        return {"detail": "account deleted"}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.post("/logout", response_model=Dict[str, str], status_code=status.HTTP_200_OK)
async def logout(credentials: HTTPAuthorizationCredentials = Depends(security), service: AuthService = Depends(AuthService)):
    """Log the current user out and invalidate the session.

    Requires a Bearer token in the Authorization header.
    """
    try:
        await service.logout(credentials.credentials)
        return {"detail": "logged out"}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))