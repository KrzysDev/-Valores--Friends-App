import asyncio
import os
from typing import Any, Dict, List, Optional

from dotenv import find_dotenv, load_dotenv
from supabase import AsyncClient, AsyncClientOptions, acreate_client

load_dotenv(find_dotenv())


# Options for one-off auth clients. Session persistence and background token
# refresh are disabled because the client is discarded right after the call.
_AUTH_ONLY_OPTIONS = AsyncClientOptions(
    auto_refresh_token=False, persist_session=False
)


# Cached Supabase async clients, keyed by API key. Reusing them keeps their
# HTTP connection pools alive between requests instead of opening a fresh pool
# (and a fresh TCP/TLS handshake) on every call.
_clients: Dict[str, AsyncClient] = {}
_clients_lock = asyncio.Lock()


async def _get_client(url: str, key: str) -> AsyncClient:
    """Return a cached async client, creating it once on first use."""
    client = _clients.get(key)
    if client is None:
        async with _clients_lock:
            client = _clients.get(key)
            if client is None:
                client = await acreate_client(url, key)
                _clients[key] = client
    return client


async def close_clients() -> None:
    """Close every cached client and release its HTTP connections."""
    for client in list(_clients.values()):
        await client.auth.close()
        postgrest = client._postgrest
        if postgrest is not None:
            await postgrest.aclose()
    _clients.clear()


class AuthService:
    """Stateless Supabase authentication service.

    The service holds only configuration (URL and keys), never a user session,
    so a single instance can safely serve many users concurrently. Shared
    clients are cached per API key; identity is passed in as a JWT access token.
    """

    def __init__(self) -> None:
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_KEY")
        self.service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

        if not url or not key:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set")

        self.url: str = url
        self.key: str = key

    async def _client(self) -> AsyncClient:
        return await _get_client(self.url, self.key)

    async def _admin_client(self) -> AsyncClient:
        service_key = self.service_key
        if not service_key:
            raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY is required for this action")
        return await _get_client(self.url, service_key)

    async def login(self, email: str, password: str) -> Any:
        """Returns AuthResponse; the caller passes the tokens on to the frontend.

        A throwaway client is used because signing in mutates the client's
        session state, which must not leak into the shared client.
        """
        client = await acreate_client(self.url, self.key, _AUTH_ONLY_OPTIONS)
        try:
            return await client.auth.sign_in_with_password(
                {"email": email, "password": password}
            )
        finally:
            await client.auth.close()

    async def register(self, email: str, password: str, age: int, name: str) -> Any:
        """Register a new user and store their name and age in user_profiles."""
        # Sign-up mutates the client session, so use a throwaway client here.
        client = await acreate_client(self.url, self.key, _AUTH_ONLY_OPTIONS)
        try:
            resp = await client.auth.sign_up({"email": email, "password": password})
        finally:
            await client.auth.close()

        if resp.user is None:
            raise RuntimeError("Failed to create user")

        # Store name and age in user_profiles using the shared admin client
        admin = await self._admin_client()
        await (
            admin.table("user_profiles")
            .insert({"user_id": resp.user.id, "age": age, "name": name})
            .execute()
        )

        return resp

    async def get_profiles_by_age_range(
        self, youngest: int, oldest: int, exclude_user_id: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Get user profiles (user_id, name, age) within the specified age range.

        Args:
            youngest: Minimum age (inclusive)
            oldest: Maximum age (inclusive)
            exclude_user_id: Optional user ID to exclude from results

        Returns:
            List of profile dicts with user_id, name and age
        """
        admin = await self._admin_client()
        query = (
            admin.table("user_profiles")
            .select("user_id, name, age")
            .gte("age", youngest)
            .lte("age", oldest)
        )

        if exclude_user_id:
            query = query.neq("user_id", exclude_user_id)

        response = await query.execute()

        return response.data if response.data else []

    async def logout(self, access_token: str) -> None:
        """Invalidate the session belonging to the given access token."""
        admin = await self._admin_client()
        await admin.auth.admin.sign_out(access_token)

    async def delete_account(self, access_token: str) -> None:
        """Delete the user identified by a verified access token.

        Also cascades to delete the user's board(s) and profile using the service role key.
        """
        client = await self._client()

        # Get user from the access token
        response = await client.auth.get_user(access_token)
        if response is None or response.user is None:
            raise RuntimeError("Invalid or expired token")

        user_id = response.user.id

        # First, delete the user's board(s) and profile using admin client
        admin = await self._admin_client()
        await admin.table("boards").delete().eq("user_id", user_id).execute()
        await admin.table("user_profiles").delete().eq("user_id", user_id).execute()

        # Then delete the user account
        await admin.auth.admin.delete_user(user_id)
