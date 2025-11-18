
import os, uuid, datetime
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
from PIL import Image, ImageFilter, ImageOps

ASSETS_DIR = os.getenv("ASSETS_DIR", "/var/www/assets")
PORT = int(os.getenv("PORT", "8013"))
app = FastAPI(title="app-sh (Enhance/RemoveBG)")

@app.get("/healthz")
def health(): return {"ok": True, "service":"app-sh"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT)
