import os
from typing import Any

from dotenv import find_dotenv, load_dotenv
from supabase import Client, create_client

load_dotenv(find_dotenv())


class AuthService:
    """Stateless Supabase authentication service.

    The service holds only configuration (URL and keys), never a user session,
    so a single instance can safely serve many users concurrently. Each call
    creates its own client; user identity is passed in as a JWT access token.
    """

    def __init__(self) -> None:
        self.url = os.getenv("SUPABASE_URL")
        self.key = os.getenv("SUPABASE_KEY")  
        self.service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

        if not self.url or not self.key:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set")

    def _client(self) -> Client:
        return create_client(self.url, self.key)

    def _admin_client(self) -> Client:
        if not self.service_key:
            raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY is required for this action")
        return create_client(self.url, self.service_key)

    def login(self, email: str, password: str) -> Any:
        """Returns AuthResponse; the caller passes the tokens on to the frontend."""
        return self._client().auth.sign_in_with_password(
            {"email": email, "password": password}
        )

    def register(self, email: str, password: str) -> Any:
        return self._client().auth.sign_up({"email": email, "password": password})

    def logout(self, access_token: str) -> None:
        """Invalidate the session belonging to the given access token."""
        self._admin_client().auth.admin.sign_out(access_token)

    def delete_account(self, access_token: str) -> None:
        """Delete the user identified by a verified access token.
        
        Also cascades to delete the user's board(s) using the service role key.
        """
        # Get user from the access token
        response = self._client().auth.get_user(access_token)  
        if response is None or response.user is None:
            raise RuntimeError("Invalid or expired token")

        user_id = response.user.id

        # First, delete the user's board(s) using admin client
        admin = self._admin_client()
        admin.table("boards").delete().eq("user_id", user_id).execute()

        # Then delete the user account
        admin.auth.admin.delete_user(user_id)