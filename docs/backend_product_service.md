# Product Service

**File:** `backend/product_service.py`

## Luồng dữ liệu

**Flutter → Backend (Image Search):**
- `ImageSearchService.searchByImageFile(xfile)` → POST `/api/v1/search/image` (multipart: file, top_k)
- Backend validate → SearchService.search_by_image() → EmbeddingService.encode_image() → compute_similarities → top-k filter ≥ 0.1
- Response JSON: `[{id, name, imageUrl, price, type, description, category, similarity}]`
- Flutter parse → `List<ImageSearchResult>` → UI

**Backend → Firestore (Build Index):**
- `ProductService.fetch_all_items()` → `fetch_products()` (collection "products") + `fetch_pets()` (collection "pets")
- `ProductInfo`: `{id, name, imageUrl, price, type, description, category}`
- Download ảnh → EmbeddingService.encode_image() → cache (embeddings.npy + items.pkl)

**Flutter → Firestore (User tap kết quả):**
- type=="product" → `ProductRepository.getProductById(id)` → CustomerProductDetailPage
- type=="pet" → `PetRepository.getPetById(id)` → CustomerPetDetailPage
