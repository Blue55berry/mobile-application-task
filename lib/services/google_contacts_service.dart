import 'package:flutter/material.dart';
import 'package:googleapis/people/v1.dart' as people;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

/// Service to fetch contact photos from Google People API
/// and cache them locally for offline access
class GoogleContactsService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn;
  people.PeopleServiceApi? _peopleApi;
  final Map<String, String> _photoCache = {}; // phone -> local path

  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  GoogleContactsService(this._googleSignIn);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  /// Initialize the service by setting up the API client
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('📸 Initializing Google Contacts Service...');
    _isLoading = true;
    notifyListeners();

    try {
      final httpClient = (await _googleSignIn.authenticatedClient())!;
      _peopleApi = people.PeopleServiceApi(httpClient);
      _isInitialized = true;
      debugPrint('✅ Google Contacts Service initialized');

      // Load cache from disk if needed (implementation omitted for brevity, adding placeholder)
      await _loadCacheFromDisk();
    } catch (e) {
      debugPrint('❌ Failed to initialize Google Contacts Service: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCacheFromDisk() async {
    // Placeholder for loading cached photo paths
  }

  /// Get a contact's photo URL or local path by phone number
  Future<String?> getContactPhoto(String phoneNumber) async {
    if (!_isInitialized || _peopleApi == null) return null;

    // Check memory cache first
    if (_photoCache.containsKey(phoneNumber)) {
      return _photoCache[phoneNumber];
    }

    try {
      // Search for contact by phone number
      final response = await _peopleApi!.people.searchContacts(
        query: phoneNumber,
        readMask: 'photos,phoneNumbers',
      );

      if (response.results != null && response.results!.isNotEmpty) {
        final person = response.results!.first.person;
        if (person?.photos != null && person!.photos!.isNotEmpty) {
          final photoUrl = person.photos!.first.url;
          if (photoUrl != null) {
            // In a full implementation, we would download and cache the image here
            // For now, we'll return the URL and store it in memory
            _photoCache[phoneNumber] = photoUrl;
            return photoUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching contact photo for $phoneNumber: $e');
    }

    return null;
  }

  /// Clear the cache
  void clearCache() {
    _photoCache.clear();
    notifyListeners();
  }
}
