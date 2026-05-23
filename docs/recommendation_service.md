# Recommendation Service

**File Flutter:** `lib/features/home/services/recommendation_service.dart`
**Server:** Recommendation Server (Docker, port 8000)

## Luồng dữ liệu

**Flutter → Recommendation Server:**
- `RecommendationService.getRecommendations(userId, limit=50)` → GET `http://localhost:8000/api/v1/recommendations?user_id=123&limit=50` (timeout 5s)
- Server: nếu có userId → collaborative/content-based filtering → trả về IDs
- Server: nếu userId=null → trả về popular items
- Response: `{"products": [{"id": 1}, ...], "pets": [{"id": 3}, ...]}`

**Flutter → Firestore (map IDs → items):**
- `_buildSuggestedItems()`: với mỗi productId → tìm trong `List<ProductItem>` (đã load từ Firestore) → `RecommendedItem.product(product)`
- Với mỗi petId → tìm trong `List<PetItem>` → `RecommendedItem.pet(pet)`

**Flutter UI:**
- HomePage section "Gợi ý cho bạn" → ProductCard/PetCard
- User tap "Xem thêm" → RecommendedListPage (filter: Tất cả/Sản phẩm/Thú cưng)
- User tap item → ProductDetailPage / PetDetailPage
- User tap icon tim → FavoriteRepository.toggle(id)
- User tap icon giỏ hàng → CartRepository.add(id)
