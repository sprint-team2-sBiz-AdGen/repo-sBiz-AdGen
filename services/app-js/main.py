
import os, uuid, datetime, hashlib
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi import Body
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional

ASSETS_DIR = os.getenv("ASSETS_DIR", "/var/www/assets")
PORT = int(os.getenv("PORT", "8012"))
app = FastAPI(title="app-js (BFF)")

@app.get("/healthz")
def health():
    return {"ok": True, "service":"app-js"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT)
