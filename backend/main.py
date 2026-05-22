"""
CLIP Image Search Server - FastAPI backend for visual product search.
Uses CLIP model (via sentence-transformers) to find similar products/pets by image.

Run: uvicorn main:app --host 0.0.0.0 --port 3002 --reload
"""
import os
import sys
import io
import json
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from embedding_service import EmbeddingService
from product_service import ProductService
from search_service import SearchService


# ── Global services ──────────────────────────────────────────────────────
embedder: Optional[EmbeddingService] = None
product_svc: Optional[ProductService] = None
search_svc: Optional[SearchService] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize services on startup and clean up on shutdown."""
    global embedder, product_svc, search_svc

    print("=" * 60)
    print("CLIP Image Search Server starting...")
    print("=" * 60)

    # Initialize services
    embedder = EmbeddingService(model_name="clip-ViT-B-32")
    
    # Try to get Firebase config from environment or use default
    firebase_cred_path = os.environ.get("FIREBASE_CRED_PATH", "firebase-key.json")
    project_id = os.environ.get("FIRESTORE_PROJECT_ID", "pet-shop-7eee2")
    
    product_svc = ProductService(
        firebase_cred_path=firebase_cred_path,
        firestore_project_id=project_id,
    )
    
    search_svc = SearchService(
        embedding_service=embedder,
        product_service=product_svc,
        cache_dir=os.path.join(os.path.dirname(__file__), "cache"),
    )

    # Build index on startup (load from cache if available)
    print("[Main] Building/loading embedding index...")
    search_svc.build_index(force_rebuild=False)
    stats = search_svc.get_index_stats()
    print(f"[Main] Index ready: {stats['total_items']} items "
          f"(products: {stats['products']}, pets: {stats['pets']})")

    yield

    # Cleanup
    print("[Main] Server shutting down.")


app = FastAPI(
    title="CLIP Image Search API",
    description="Tìm kiếm sản phẩm/thú cưng bằng hình ảnh sử dụng CLIP model",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS - allow all origins for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── API Models ────────────────────────────────────────────────────────────

class SearchByImageURLRequest(BaseModel):
    image_url: str
    top_k: int = 20

class SearchByTextRequest(BaseModel):
    text: str
    top_k: int = 20

class SearchResult(BaseModel):
    id: int
    name: str
    imageUrl: str
    price: float
    type: str
    description: str = ""
    category: str = ""
    similarity: float


# ── API Endpoints ────────────────────────────────────────────────────────

@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "service": "CLIP Image Search",
        "status": "running",
        "version": "1.0.0",
    }


@app.get("/api/v1/stats")
async def get_stats():
    """Get index statistics."""
    if search_svc is None:
        raise HTTPException(status_code=503, detail="Service not initialized")
    return search_svc.get_index_stats()


@app.post("/api/v1/search/image", response_model=list[SearchResult])
async def search_by_image(
    file: UploadFile = File(...),
    top_k: int = Form(20),
):
    """
    Search for similar products/pets by uploading an image file.
    
    Upload an image (JPEG, PNG, etc.) and get visually similar items.
    """
    if search_svc is None:
        raise HTTPException(status_code=503, detail="Service not initialized")

    # Validate file
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    # Read image bytes
    image_bytes = await file.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
    
    if len(image_bytes) > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(status_code=400, detail="Image too large (max 10MB)")

    try:
        results = search_svc.search_by_image(image_bytes, top_k=top_k)
        return results
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"[Main] Search error: {e}")
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")


@app.post("/api/v1/search/image-url", response_model=list[SearchResult])
async def search_by_image_url(request: SearchByImageURLRequest):
    """
    Search for similar products/pets by providing an image URL.
    The server will download the image and search for visually similar items.
    """
    if search_svc is None:
        raise HTTPException(status_code=503, detail="Service not initialized")

    if not request.image_url:
        raise HTTPException(status_code=400, detail="image_url is required")

    # Download image from URL
    try:
        image_bytes = product_svc.download_image(request.image_url)
        if image_bytes is None:
            raise HTTPException(status_code=400, detail="Could not download image from URL")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to download image: {str(e)}")

    try:
        results = search_svc.search_by_image(image_bytes, top_k=request.top_k)
        return results
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"[Main] Search error: {e}")
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")


@app.post("/api/v1/search/text", response_model=list[SearchResult])
async def search_by_text(request: SearchByTextRequest):
    """
    Search for products/pets by text description.
    Uses CLIP text encoder to find items matching the description.
    
    Example queries: "a brown dog", "cat food", "small white puppy"
    """
    if search_svc is None:
        raise HTTPException(status_code=503, detail="Service not initialized")

    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="text is required")

    try:
        results = search_svc.search_by_text(request.text.strip(), top_k=request.top_k)
        return results
    except Exception as e:
        print(f"[Main] Text search error: {e}")
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")


@app.post("/api/v1/index/rebuild")
async def rebuild_index():
    """Force rebuild the embedding index from scratch."""
    if search_svc is None:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    try:
        search_svc.build_index(force_rebuild=True)
        stats = search_svc.get_index_stats()
        return {"message": "Index rebuilt successfully", "stats": stats}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Rebuild failed: {str(e)}")


# ── Main entry point ─────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("PORT", 3002))
    host = os.environ.get("HOST", "0.0.0.0")
    
    print(f"Starting CLIP Search Server on {host}:{port}")
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=False,
        log_level="info",
    )
