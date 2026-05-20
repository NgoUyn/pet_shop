import 'package:flutter/foundation.dart';
import '../../features/home/services/pet_repository.dart';

/// Single Source of Truth for Pet data.
/// Uses ChangeNotifier so that any widget can listen and auto-refresh.
class PetProvider extends ChangeNotifier {
  PetProvider._();

  static final PetProvider instance = PetProvider._();

  List<PetItem> _pets = [];
  bool _isLoading = false;
  String? _error;

  List<PetItem> get pets => _pets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all active pets visible to customers (only active + đang bán).
  Future<void> loadPets({int limit = 200}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pets = await PetRepository.instance.listActivePets(limit: limit);
      _error = null;
    } catch (e) {
      _error = 'Không thể tải danh sách thú cưng';
      debugPrint('PetProvider.loadPets error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load ALL pets (including inactive/sold) — for admin use.
  Future<void> loadAllPets({int limit = 500}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pets = await PetRepository.instance.listAllPets(limit: limit);
      _error = null;
    } catch (e) {
      _error = 'Không thể tải danh sách thú cưng';
      debugPrint('PetProvider.loadAllPets error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a single pet by ID from the local cache, or fetch from repository.
  Future<PetItem?> getPetById(int petId) async {
    // First check local cache
    final cached = _pets.where((p) => p.petId == petId).firstOrNull;
    if (cached != null) return cached;

    // Fallback to repository
    try {
      return await PetRepository.instance.getPetById(petId);
    } catch (e) {
      debugPrint('PetProvider.getPetById error: $e');
      return null;
    }
  }

  /// Refresh a single pet in the list after an update.
  void refreshPet(PetItem updatedPet) {
    final index = _pets.indexWhere((p) => p.petId == updatedPet.petId);
    if (index != -1) {
      _pets[index] = updatedPet;
    } else {
      _pets.add(updatedPet);
    }
    notifyListeners();
  }

  /// Remove a pet from the list (soft delete).
  void removePet(int petId) {
    _pets.removeWhere((p) => p.petId == petId);
    notifyListeners();
  }

  /// Reload all pets from scratch.
  Future<void> reload() => loadPets();
}
