from fastapi import FastAPI

app = FastAPI()

# Include API routers
from .api.routers.auth_router import router as auth_router
from .api.routers.board_router import router as board_router
app.include_router(auth_router)
app.include_router(board_router)

@app.get("/")
def root():
    return {
        "i will add something later here" : "fr tho"
    }

