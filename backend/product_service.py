"""
Product Service - fetches product and pet data from Firestore.
Uses Firebase Admin SDK to read product/pet collections.
"""
import os
import json
from typing import Optional
import requests

# Try to use firebase-admin if available, otherwise fallback to Firestore REST API
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    _FIREBASE_ADMIN_AVAILABLE = True
except ImportError:
    _FIREBASE_ADMIN_AVAILABLE = False


class ProductInfo:
    """Represents a product or pet item from the database."""
    def __init__(
        self,
        item_id: int,
        name: str,
        image_url: str,
        price: float,
        item_type: str,  # "product" or "pet"
        description: str = "",
        category: str = "",
    ):
        self.item_id = item_id
        self.name = name
        self.image_url = image_url
        self.price = price
        self.item_type = item_type
        self.description = description
        self.category = category

    def to_dict(self):
        return {
            "id": self.item_id,
            "name": self.name,
            "imageUrl": self.image_url,
            "price": self.price,
            "type": self.item_type,
            "description": self.description,
            "category": self.category,
        }


class ProductService:
    """Service to fetch product/pet data from Firestore."""

    def __init__(self, 
                 firebase_cred_path: Optional[str] = None,
                 firestore_project_id: Optional[str] = None):
        """
        Initialize Firebase connection.
        
        Args:
            firebase_cred_path: Path to Firebase service account JSON file.
                                If None, tries to use FIREBASE_CREDENTIALS env var.
            firestore_project_id: Firestore project ID. If None, reads from credentials.
        """
        self._db = None
        self._use_rest = False
        self._project_id = firestore_project_id

        if _FIREBASE_ADMIN_AVAILABLE:
            self._init_firebase_admin(firebase_cred_path)
        else:
            print("[ProductService] firebase-admin not installed. Will use REST API fallback.")
            self._use_rest = True

        # Cache for product/pet embeddings
        self._cached_items: list[ProductInfo] = []
        self._cached_embeddings = None  # numpy array

    def _init_firebase_admin(self, cred_path: Optional[str] = None):
        """Initialize Firebase Admin SDK."""
        try:
            if cred_path and os.path.exists(cred_path):
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
            elif os.environ.get("FIREBASE_CREDENTIALS"):
                cred_json = json.loads(os.environ["FIREBASE_CREDENTIALS"])
                cred = credentials.Certificate(cred_json)
                firebase_admin.initialize_app(cred)
            else:
                # Try default (application default credentials)
                firebase_admin.initialize_app()
            
            self._db = firestore.client()
            if not self._project_id:
                self._project_id = self._db.project
            print(f"[ProductService] Firebase Admin initialized. Project: {self._project_id}")
        except Exception as e:
            print(f"[ProductService] Firebase Admin init failed: {e}")
            print("[ProductService] Will use REST API fallback.")
            self._use_rest = True

    def _get_rest_api_url(self, collection: str) -> str:
        """Get Firestore REST API URL for a collection."""
        project = self._project_id or "pet-shop-v2"
        return (
            f"https://firestore.googleapis.com/v1/"
            f"projects/{project}/databases/(default)/documents/{collection}"
        )

    def _fetch_collection_rest(self, collection: str) -> list[dict]:
        """Fetch a Firestore collection via REST API."""
        url = self._get_rest_api_url(collection)
        try:
            resp = requests.get(url, timeout=10)
            if resp.status_code == 200:
                data = resp.json()
                documents = data.get("documents", [])
                results = []
                for doc in documents:
                    fields = doc.get("fields", {})
                    # Convert Firestore REST format to simple dict
                    record = {}
                    for key, value in fields.items():
                        record[key] = self._extract_firestore_value(value)
                    results.append(record)
                return results
            else:
                print(f"[ProductService] REST API error {resp.status_code}: {resp.text}")
                return []
        except Exception as e:
            print(f"[ProductService] REST API request failed: {e}")
            return []

    def _extract_firestore_value(self, value: dict):
        """Extract a value from Firestore REST format."""
        if "stringValue" in value:
            return value["stringValue"]
        elif "integerValue" in value:
            return int(value["integerValue"])
        elif "doubleValue" in value:
            return float(value["doubleValue"])
        elif "booleanValue" in value:
            return value["booleanValue"]
        elif "arrayValue" in value:
            return [self._extract_firestore_value(v) for v in value["arrayValue"].get("values", [])]
        elif "mapValue" in value:
            return {k: self._extract_firestore_value(v) for k, v in value["mapValue"].get("fields", {}).items()}
        return None

    def _fetch_collection_admin(self, collection: str) -> list[dict]:
        """Fetch a Firestore collection via Admin SDK."""
        try:
            docs = self._db.collection(collection).where("isActive", "==", True).stream()
            return [{**doc.to_dict()} for doc in docs]
        except Exception as e:
            print(f"[ProductService] Admin SDK fetch error: {e}")
            return []

    def fetch_products(self) -> list[ProductInfo]:
        """Fetch all active products from Firestore."""
        if self._use_rest:
            raw_items = self._fetch_collection_rest("products")
        else:
            raw_items = self._fetch_collection_admin("products")

        products = []
        for item in raw_items:
            try:
                product = ProductInfo(
                    item_id=int(item.get("productId", 0)),
                    name=str(item.get("productName", "")),
                    image_url=str(item.get("imageUrl", "") or ""),
                    price=float(item.get("price", 0)),
                    item_type="product",
                    description=str(item.get("description", "") or ""),
                    category=str(item.get("categoryName", "") or ""),
                )
                if product.image_url and product.name:
                    products.append(product)
            except (ValueError, TypeError) as e:
                print(f"[ProductService] Skipping invalid product: {e}")
                continue

        print(f"[ProductService] Fetched {len(products)} products")
        return products

    def fetch_pets(self) -> list[ProductInfo]:
        """Fetch all active pets from Firestore."""
        if self._use_rest:
            raw_items = self._fetch_collection_rest("pets")
        else:
            raw_items = self._fetch_collection_admin("pets")

        pets = []
        for item in raw_items:
            try:
                pet = ProductInfo(
                    item_id=int(item.get("petId", 0)),
                    name=str(item.get("petName", "")),
                    image_url=str(item.get("imageUrl", "") or ""),
                    price=float(item.get("price", 0) or 0),
                    item_type="pet",
                    description=str(item.get("description", "") or ""),
                    category=str(item.get("species", "") or ""),
                )
                if pet.image_url and pet.name:
                    pets.append(pet)
            except (ValueError, TypeError) as e:
                print(f"[ProductService] Skipping invalid pet: {e}")
                continue

        print(f"[ProductService] Fetched {len(pets)} pets")
        return pets

    def fetch_all_items(self) -> list[ProductInfo]:
        """Fetch all products and pets."""
        products = self.fetch_products()
        pets = self.fetch_pets()
        return products + pets

    def download_image(self, image_url: str) -> Optional[bytes]:
        """Download an image from URL."""
        if not image_url:
            return None
        try:
            resp = requests.get(image_url, timeout=15)
            if resp.status_code == 200:
                return resp.content
            else:
                print(f"[ProductService] Failed to download image: {image_url} (status {resp.status_code})")
                return None
        except Exception as e:
            print(f"[ProductService] Error downloading image {image_url}: {e}")
            return None
