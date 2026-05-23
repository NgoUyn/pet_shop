# Embedding Service

**File:** `backend/embedding_service.py`

## Luồng dữ liệu

**Flutter → Backend (Image Search Pipeline):**
- Input: image_bytes (JPEG, ≤10MB)
- `encode_image(bytes)`: PIL.Image.open() → RGB → CLIP Vision Transformer → 512-dim raw → L2 normalize → query_emb (512-dim, ||v||=1)
- `compute_similarities(query_emb, index_embeddings)`: L2 normalize cả 2 → dot product → scores (N,) [0.0 - 1.0]
- Output: JSON `[{id, name, imageUrl, price, type, similarity}]`

**Flutter → Backend (Text Search Pipeline):**
- Input: text string
- `encode_text(text)`: CLIP Text Transformer → 512-dim raw → L2 normalize → text_emb
- `compute_similarities(text_emb, index_embeddings)` → scores → top-k ≥ 0.1
- Output: JSON `[{id, name, imageUrl, price, type, similarity}]`

**3 Service phối hợp:**
- `EmbeddingService`: encode_image/encode_text/compute_similarities
- `ProductService`: fetch_all_items/download_image
- `SearchService`: build_index/search_by_image/search_by_text
