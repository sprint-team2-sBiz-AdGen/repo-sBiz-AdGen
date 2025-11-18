
import os, uuid, datetime, random
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from PIL import Image, ImageOps, ImageFilter, ImageDraw, ImageFont

ASSETS_DIR = os.getenv("ASSETS_DIR", "/var/www/assets")
PORT = int(os.getenv("PORT", "8010"))
app = FastAPI(title="app-ye (Generator/LLaVA stub)")

@app.get("/healthz")
def health(): return {"ok": True, "service":"app-ye"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT)
