"""
Embedding Service using CLIP model via sentence-transformers.
Generates vector embeddings for images and text queries.
"""
import io
import numpy as np
from PIL import Image
from sentence_transformers import SentenceTransformer
import torch


class EmbeddingService:
    """Service to generate CLIP embeddings for images and text."""

    def __init__(self, model_name: str = "clip-ViT-B-32"):
        """
        Initialize the CLIP model.
        
        Args:
            model_name: Name of the sentence-transformers CLIP model.
                        Options: "clip-ViT-B-32" (fast, good), 
                                 "clip-ViT-L-14" (slower, more accurate)
        """
        print(f"[EmbeddingService] Loading model: {model_name} ...")
        self.model = SentenceTransformer(model_name)
        # Get dimension by encoding a dummy text
        try:
            self.dimension = self.model.get_sentence_embedding_dimension()
            if self.dimension is None:
                # Fallback: encode a dummy input to get dimension
                dummy_emb = self.model.encode("test", convert_to_numpy=True)
                self.dimension = dummy_emb.shape[0]
        except Exception:
            dummy_emb = self.model.encode("test", convert_to_numpy=True)
            self.dimension = dummy_emb.shape[0]
        print(f"[EmbeddingService] Model loaded. Embedding dimension: {self.dimension}")

    def encode_image(self, image_bytes: bytes) -> np.ndarray:
        """
        Encode an image into a CLIP embedding vector.
        
        Args:
            image_bytes: Raw image bytes (JPEG, PNG, etc.)
            
        Returns:
            numpy array of shape (dimension,)
        """
        try:
            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception as e:
            raise ValueError(f"Invalid image data: {e}")

        embedding = self.model.encode(image, convert_to_numpy=True)
        # Normalize the embedding
        embedding = embedding / np.linalg.norm(embedding)
        return embedding

    def encode_text(self, text: str) -> np.ndarray:
        """
        Encode a text query into a CLIP embedding vector.
        
        Args:
            text: Text query string
            
        Returns:
            numpy array of shape (dimension,)
        """
        embedding = self.model.encode(text, convert_to_numpy=True)
        embedding = embedding / np.linalg.norm(embedding)
        return embedding

    def compute_similarity(self, emb1: np.ndarray, emb2: np.ndarray) -> float:
        """
        Compute cosine similarity between two embeddings.
        
        Args:
            emb1: First embedding vector
            emb2: Second embedding vector
            
        Returns:
            Cosine similarity score (0 to 1)
        """
        return float(np.dot(emb1, emb2))

    def compute_similarities(self, query_emb: np.ndarray, 
                             candidate_embs: np.ndarray) -> np.ndarray:
        """
        Compute cosine similarities between a query embedding and many candidates.
        
        Args:
            query_emb: Query embedding vector of shape (dim,)
            candidate_embs: Candidate embeddings of shape (N, dim)
            
        Returns:
            Array of similarity scores of shape (N,)
        """
        # Normalize query if not already
        query_norm = query_emb / np.linalg.norm(query_emb)
        # Normalize candidates along axis 1
        candidate_norms = candidate_embs / np.linalg.norm(
            candidate_embs, axis=1, keepdims=True
        )
        return np.dot(candidate_norms, query_norm)
