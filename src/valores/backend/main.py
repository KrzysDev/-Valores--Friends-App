from fastapi import FastAPI

app = FastAPI()

# Include API routers
from .api.routers.auth_router import router as auth_router
from .api.routers.board_router import router as board_router
from .api.routers.discover_router import router as discover_router
from .api.routers.like_router import router as like_router
from .api.routers.conversation_router import router as conversation_router
from .api.routers.message_router import router as message_router
app.include_router(auth_router)
app.include_router(board_router)
app.include_router(discover_router)
app.include_router(like_router)
app.include_router(conversation_router)
app.include_router(message_router)

@app.get("/")
def root():
    return {
        "i will add something later here" : "fr tho"
    }

