# Search Service

**File:** `backend/search_service.py`

## Luồng dữ liệu

**Flutter → Backend (Image Search):**
- `ImageSearchService.searchByImageFile(xfile, topK=20)` → POST `/api/v1/search/image` (multipart: file, top_k)
- Backend: validate (image/*, ≤10MB) → SearchService.search_by_image(bytes, top_k)
  - Nếu chưa load index → build_index(): ProductService.fetch_all_items() → download ảnh → EmbeddingService.encode_image() → cache
  - EmbeddingService.encode_image(bytes) → query_emb (512-dim, L2 norm)
  - compute_similarities(query_emb, index) → scores → top-k (argpartition) → filter ≥ 0.1
- Response: `[{id, name, imageUrl, price, type, description, category, similarity}]`

**Flutter → Backend (Text Search):**
- `ImageSearchService.searchByText(text, topK=20)` → POST `/api/v1/search/text` → `{"text": "...", "top_k": 20}`
- Backend: EmbeddingService.encode_text(text) → text_emb (512-dim) → compute_similarities → top-k → filter ≥ 0.1
- Response: `[{id, name, imageUrl, price, type, similarity}]`

**Flutter → Backend (Rebuild Index):**
- Admin → POST `/api/v1/index/rebuild` → build_index(force=True) → xoá cache → fetch_all_items() → encode → save cache
- Response: `{"message": "...", "stats": {total_items, ...}}`

**Flutter → Backend (Stats):**
- GET `/api/v1/stats` → `{total_items, embedding_dimension, is_loaded, products, pets}`
