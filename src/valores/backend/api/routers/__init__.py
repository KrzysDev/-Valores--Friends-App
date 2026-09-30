from .auth_router import router as auth_router
from .board_router import router as board_router
from .discover_router import router as discover_router
from .like_router import router as like_router
from .conversation_router import router as conversation_router
from .message_router import router as message_router

__all__ = [
    "auth_router",
    "board_router",
    "discover_router",
    "like_router",
    "conversation_router",
    "message_router",
]