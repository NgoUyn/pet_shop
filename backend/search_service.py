"""
Search Service - manages the embedding index and performs similarity search.
Pre-computes embeddings for all products/pets and caches them for fast retrieval.
"""
import os
import pickle
import numpy as np
from typing import Optional

from embedding_service import EmbeddingService
from product_service import ProductService, ProductInfo


class SearchService:
    """Service to manage embedding index and perform similarity search."""

    def __init__(self, 
                 embedding_service: EmbeddingService,
                 product_service: ProductService,
                 cache_dir: str = "cache"):
        """
        Initialize the search service.
        
        Args:
            embedding_service: CLIP embedding service
            product_service: Product data service
            cache_dir: Directory to cache embeddings
        """
        self.embedder = embedding_service
        self.product_service = product_service
        self.cache_dir = cache_dir
        
        # In-memory index
        self.items: list[ProductInfo] = []
        self.embeddings: Optional[np.ndarray] = None  # shape (N, dim)
        self._is_index_loaded = False

        # Create cache directory
        os.makedirs(cache_dir, exist_ok=True)

    def _get_cache_path(self, name: str) -> str:
        return os.path.join(self.cache_dir, name)

    def _save_index(self):
        """Save the embedding index to disk."""
        if self.embeddings is None:
            return
        
        # Save embeddings
        emb_path = self._get_cache_path("embeddings.npy")
        np.save(emb_path, self.embeddings)
        
        # Save item metadata
        meta_path = self._get_cache_path("items.pkl")
        with open(meta_path, "wb") as f:
            pickle.dump(self.items, f)
        
        print(f"[SearchService] Index saved: {len(self.items)} items, "
              f"embedding shape {self.embeddings.shape}")

    def _load_index(self) -> bool:
        """Load the embedding index from disk if available."""
        emb_path = self._get_cache_path("embeddings.npy")
        meta_path = self._get_cache_path("items.pkl")
        
        if not os.path.exists(emb_path) or not os.path.exists(meta_path):
            return False
        
        try:
            self.embeddings = np.load(emb_path)
            with open(meta_path, "rb") as f:
                self.items = pickle.load(f)
            print(f"[SearchService] Index loaded: {len(self.items)} items, "
                  f"embedding shape {self.embeddings.shape}")
            return True
        except Exception as e:
            print(f"[SearchService] Failed to load index: {e}")
            return False

    def build_index(self, force_rebuild: bool = False):
        """
        Build the embedding index by encoding all product/pet images.
        
        Args:
            force_rebuild: If True, rebuild even if cache exists
        """
        if not force_rebuild and self._load_index():
            self._is_index_loaded = True
            return

        print("[SearchService] Building index from scratch...")
        
        # Fetch all items
        all_items = self.product_service.fetch_all_items()
        
        if not all_items:
            print("[SearchService] No items found in database!")
            self.items = []
            self.embeddings = np.array([])
            self._is_index_loaded = True
            return

        # Encode each item's image
        embeddings_list = []
        valid_items = []
        
        for i, item in enumerate(all_items):
            print(f"[SearchService] Encoding {i+1}/{len(all_items)}: {item.name}...")
            
            image_bytes = self.product_service.download_image(item.image_url)
            if image_bytes is None:
                print(f"  -> Skipping {item.name}: could not download image")
                continue
            
            try:
                emb = self.embedder.encode_image(image_bytes)
                embeddings_list.append(emb)
                valid_items.append(item)
            except Exception as e:
                print(f"  -> Error encoding {item.name}: {e}")
                continue

        if embeddings_list:
            self.embeddings = np.array(embeddings_list)
            self.items = valid_items
            self._save_index()
        else:
            self.embeddings = np.array([])
            self.items = []

        self._is_index_loaded = True
        print(f"[SearchService] Index built: {len(self.items)} items")

    def search_by_image(self, image_bytes: bytes, top_k: int = 20) -> list[dict]:
        """
        Search for similar items by image.
        
        Args:
            image_bytes: Raw image bytes to search with
            top_k: Number of results to return
            
        Returns:
            List of dicts with item info and similarity score
        """
        if not self._is_index_loaded:
            self.build_index()
        
        if not self.items or self.embeddings is None or len(self.embeddings) == 0:
            return []

        # Encode query image
        query_emb = self.embedder.encode_image(image_bytes)
        
        # Compute similarities
        scores = self.embedder.compute_similarities(query_emb, self.embeddings)
        
        # Get top-k indices
        if len(scores) <= top_k:
            top_indices = np.argsort(scores)[::-1]
        else:
            top_indices = np.argpartition(scores, -top_k)[-top_k:]
            top_indices = top_indices[np.argsort(scores[top_indices])[::-1]]
        
        # Build results
        results = []
        for idx in top_indices:
            score = float(scores[idx])
            if score < 0.1:  # Skip very low similarity
                continue
            item = self.items[idx]
            result = item.to_dict()
            result["similarity"] = round(score, 4)
            results.append(result)
        
        return results

    def search_by_text(self, text: str, top_k: int = 20) -> list[dict]:
        """
        Search for items by text description (using CLIP text encoder).
        
        Args:
            text: Text query (e.g., "a brown dog", "cat food")
            top_k: Number of results to return
            
        Returns:
            List of dicts with item info and similarity score
        """
        if not self._is_index_loaded:
            self.build_index()
        
        if not self.items or self.embeddings is None or len(self.embeddings) == 0:
            return []

        # Encode text query
        query_emb = self.embedder.encode_text(text)
        
        # Compute similarities
        scores = self.embedder.compute_similarities(query_emb, self.embeddings)
        
        # Get top-k indices
        if len(scores) <= top_k:
            top_indices = np.argsort(scores)[::-1]
        else:
            top_indices = np.argpartition(scores, -top_k)[-top_k:]
            top_indices = top_indices[np.argsort(scores[top_indices])[::-1]]
        
        # Build results
        results = []
        for idx in top_indices:
            score = float(scores[idx])
            if score < 0.1:
                continue
            item = self.items[idx]
            result = item.to_dict()
            result["similarity"] = round(score, 4)
            results.append(result)
        
        return results

    def get_index_stats(self) -> dict:
        """Get statistics about the current index."""
        return {
            "total_items": len(self.items),
            "embedding_dimension": self.embeddings.shape[1] if self.embeddings is not None and len(self.embeddings) > 0 else 0,
            "is_loaded": self._is_index_loaded,
            "products": sum(1 for i in self.items if i.item_type == "product"),
            "pets": sum(1 for i in self.items if i.item_type == "pet"),
        }
