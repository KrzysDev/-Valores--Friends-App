from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {
        "i will add something later here" : "fr tho"
    }

