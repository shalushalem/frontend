import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:appwrite/enums.dart';
import 'package:myapp/config/env.dart';

class AppwriteService extends ChangeNotifier {
  late Client client;
  late Account account;
  late Databases databases;
  late Avatars avatars;

  AppwriteService() {
    client = Client()
      ..setEndpoint(Env.appwriteEndpoint)
      ..setProject(Env.appwriteProjectId);

    account = Account(client);
    databases = Databases(client);
    avatars = Avatars(client);
  }

  // =========================================================================
  // AUTHENTICATION METHODS
  // =========================================================================

  Future<User?> getCurrentUser() async {
    try {
      return await account.get();
    } catch (e) {
      debugPrint("No active session or error: $e");
      return null;
    }
  }

  Future<Session?> loginEmailPassword(String email, String password) async {
    try {
      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      notifyListeners();
      return session;
    } catch (e) {
      debugPrint("Login error: $e");
      rethrow;
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      await account.createOAuth2Session(provider: OAuthProvider.google);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Google login error: $e");
      return false;
    }
  }

  Future<bool> loginWithApple() async {
    try {
      await account.createOAuth2Session(provider: OAuthProvider.apple);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Apple login error: $e");
      return false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await account.createRecovery(
        email: email,
        url: '${Env.appwriteEndpoint}/reset-password',
      );
    } catch (e) {
      debugPrint("Password reset error: $e");
      rethrow;
    }
  }

  Future<User> registerEmailPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      return user;
    } catch (e) {
      debugPrint("Register error: $e");
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await account.deleteSession(sessionId: 'current');
      notifyListeners();
    } catch (e) {
      debugPrint("Logout error: $e");
    }
  }

  Future<Uint8List?> getUserAvatar(String name) async {
    try {
      return await avatars.getInitials(name: name);
    } catch (e) {
      debugPrint("Avatar error: $e");
      return null;
    }
  }

  // =========================================================================
  // ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â‚¬Â WARDROBE (OUTFITS) DB METHODS
  // =========================================================================

  // =========================================================================
  // USERS PROFILE DB METHODS
  // =========================================================================

  static String _safeTrim(String? value) => value?.trim() ?? '';

  static bool _isValidEmail(String value) {
    final v = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  }

  static bool _isValidHttpUrl(String value) {
    final parsed = Uri.tryParse(value.trim());
    return parsed != null &&
        parsed.hasScheme &&
        (parsed.scheme == 'http' || parsed.scheme == 'https');
  }

  static String _deriveUsername(String name, String email) {
    final fromName = _safeTrim(
      name,
    ).toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    if (fromName.isNotEmpty) return fromName;
    final fromEmail = _safeTrim(email).split('@').first.toLowerCase();
    if (fromEmail.isNotEmpty) return fromEmail;
    return 'user';
  }

  static DateTime? _parseDob(String rawDob) {
    final raw = rawDob.trim();
    if (raw.isEmpty) return null;

    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;

    final parts = raw.split(RegExp(r'\s+'));
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final year = int.tryParse(parts[2]);
    if (day == null || year == null) return null;

    const monthMap = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'sept': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    final month = monthMap[parts[1].toLowerCase()];
    if (month == null) return null;
    return DateTime(year, month, day);
  }

  Future<Document?> getUserProfileDocument() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      try {
        return await databases.getDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.usersCollection,
          documentId: user.$id,
        );
      } catch (_) {
        final email = _safeTrim(user.email);
        if (!_isValidEmail(email)) return null;

        final byEmail = await databases.listDocuments(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.usersCollection,
          queries: [Query.equal('email', email), Query.limit(1)],
        );
        if (byEmail.documents.isEmpty) return null;
        return byEmail.documents.first;
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      return null;
    }
  }

  Future<Document?> upsertUserProfile({
    String? name,
    String? username,
    String? email,
    String? phone,
    String? dob,
    String? gender,
    int? skinTone,
    String? bodyShape,
    String? avatarUrl,
    List<String>? stylePreferences,
  }) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final existing = await getUserProfileDocument();
      final documentId = existing?.$id ?? user.$id;

      final cleanName = _safeTrim(name).isNotEmpty
          ? _safeTrim(name)
          : _safeTrim(user.name);
      final emailCandidate = _safeTrim(email).isNotEmpty
          ? _safeTrim(email)
          : _safeTrim(user.email);
      final cleanEmail = _isValidEmail(emailCandidate) ? emailCandidate : '';
      final cleanUsernameInput = _safeTrim(username);
      final cleanUsername = cleanUsernameInput.isNotEmpty
          ? cleanUsernameInput.replaceFirst('@', '')
          : _deriveUsername(cleanName, cleanEmail);

      final payload = <String, dynamic>{
        'name': cleanName,
        'username': cleanUsername,
        'phone': _safeTrim(phone),
        'gender': _safeTrim(gender),
        'bodyShape': _safeTrim(bodyShape),
      };

      if (cleanEmail.isNotEmpty) {
        payload['email'] = cleanEmail;
      }
      if (skinTone != null) {
        payload['skinTone'] = skinTone;
      }

      final parsedDob = _parseDob(_safeTrim(dob));
      if (parsedDob != null) {
        payload['dob'] = parsedDob.toUtc().toIso8601String();
      }

      if (stylePreferences != null) {
        payload['stylePreferences'] = stylePreferences
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final cleanAvatar = _safeTrim(avatarUrl);
      if (_isValidHttpUrl(cleanAvatar)) {
        payload['avatar_url'] = cleanAvatar;
      }

      try {
        return await databases.updateDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.usersCollection,
          documentId: documentId,
          data: payload,
        );
      } catch (_) {
        return await databases.createDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.usersCollection,
          documentId: documentId,
          data: payload,
        );
      }
    } catch (e) {
      debugPrint("Error upserting user profile: $e");
      return null;
    }
  }

  Future<Document?> ensureUserProfileDocument() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      final existing = await getUserProfileDocument();
      if (existing != null) return existing;

      return await upsertUserProfile(
        name: user.name,
        email: user.email,
        username: _deriveUsername(user.name, user.email),
      );
    } catch (e) {
      debugPrint("Error ensuring user profile: $e");
      return null;
    }
  }

  Future<List<Document>> getMemories({int limit = 20}) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      final safeLimit = limit < 1 ? 1 : (limit > 100 ? 100 : limit);
      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.memoriesCollection,
        queries: [
          Query.equal('userId', user.$id),
          Query.orderDesc('\$updatedAt'),
          Query.limit(safeLimit),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching memories: $e");
      return [];
    }
  }

  Future<Document?> getLatestMemory() async {
    final docs = await getMemories(limit: 1);
    if (docs.isEmpty) return null;
    return docs.first;
  }

  Future<Document?> upsertUserMemory(String memoryText) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      final cleanMemory = memoryText.trim();
      if (cleanMemory.isEmpty) {
        throw Exception("Memory text cannot be empty");
      }
      final existing = await getLatestMemory();
      if (existing != null) {
        return await databases.updateDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.memoriesCollection,
          documentId: existing.$id,
          data: {'memory': cleanMemory},
        );
      }
      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.memoriesCollection,
        documentId: ID.unique(),
        data: {'userId': user.$id, 'memory': cleanMemory},
      );
    } catch (e) {
      debugPrint("Error upserting memory: $e");
      return null;
    }
  }

  static String _normalizeLookup(String value) {
    final lower = value.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<List<String>> resolveWardrobeItemIds(List<String> labels) async {
    final normalizedLabels = labels
        .map(_normalizeLookup)
        .where((v) => v.isNotEmpty)
        .toList();
    if (normalizedLabels.isEmpty) return const <String>[];

    final items = await getWardrobeItems();
    if (items.isEmpty) return const <String>[];

    final byId = <String, Map<String, dynamic>>{
      for (final item in items) (item['id']?.toString() ?? ''): item,
    }..remove('');

    final nameById = <String, String>{
      for (final item in items)
        (item['id']?.toString() ?? ''): _normalizeLookup(
          item['name']?.toString() ?? '',
        ),
    }..remove('');

    final subCategoryById = <String, String>{
      for (final item in items)
        (item['id']?.toString() ?? ''): _normalizeLookup(
          item['sub_category']?.toString() ?? '',
        ),
    }..remove('');

    final categoryById = <String, String>{
      for (final item in items)
        (item['id']?.toString() ?? ''): _normalizeLookup(
          item['category']?.toString() ?? '',
        ),
    }..remove('');

    final resolved = <String>[];
    final used = <String>{};

    for (final label in normalizedLabels) {
      // If the caller already gave a real wardrobe doc id, keep it directly.
      if (byId.containsKey(label) && !used.contains(label)) {
        resolved.add(label);
        used.add(label);
        continue;
      }

      String? picked;

      for (final entry in nameById.entries) {
        if (used.contains(entry.key)) continue;
        if (entry.value.isNotEmpty && entry.value == label) {
          picked = entry.key;
          break;
        }
      }

      if (picked == null) {
        for (final entry in subCategoryById.entries) {
          if (used.contains(entry.key)) continue;
          if (entry.value.isNotEmpty && entry.value == label) {
            picked = entry.key;
            break;
          }
        }
      }

      if (picked == null) {
        for (final entry in categoryById.entries) {
          if (used.contains(entry.key)) continue;
          if (entry.value.isNotEmpty && entry.value == label) {
            picked = entry.key;
            break;
          }
        }
      }

      if (picked == null && label.length >= 4) {
        for (final entry in nameById.entries) {
          if (used.contains(entry.key)) continue;
          final candidate = entry.value;
          if (candidate.length >= 4 &&
              (candidate.contains(label) || label.contains(candidate))) {
            picked = entry.key;
            break;
          }
        }
      }

      if (picked != null) {
        resolved.add(picked);
        used.add(picked);
      }
    }

    return resolved;
  }

  Future<List<Map<String, dynamic>>> getWardrobeItems() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      Map<String, dynamic> _docToWardrobe(Document doc) {
        final occasionsRaw = doc.data['occasions'];
        final occasions = occasionsRaw is List
            ? occasionsRaw
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
            : <String>[];
        return {
          "id": doc.$id,
          "name": (doc.data['name'] ?? 'Garment').toString(),
          "category": (doc.data['category'] ?? 'Accessories').toString(),
          "sub_category": (doc.data['sub_category'] ?? 'General').toString(),
          "color_code": (doc.data['color_code'] ?? '').toString(),
          "pattern": (doc.data['pattern'] ?? 'solid').toString(),
          "occasions": occasions,
          "notes": (doc.data['notes'] ?? '').toString(),
          "worn": doc.data['worn'] is int ? doc.data['worn'] as int : 0,
          "liked": doc.data['liked'] == true,
          "image_url": (doc.data['image_url'] ?? doc.data['imageUrl'])?.toString(),
          "masked_url": (doc.data['masked_url'] ?? doc.data['maskedUrl'])?.toString(),
          "createdAt": doc.$createdAt,
        };
      }

      final byId = <String, Map<String, dynamic>>{};

      Future<void> _fetchByUserField(String fieldName) async {
        try {
          final result = await databases.listDocuments(
            databaseId: Env.appwriteDatabaseId,
            collectionId: Env.outfitsCollection,
            queries: [
              Query.equal(fieldName, [user.$id]),
              Query.orderDesc('\$createdAt'),
              Query.limit(300),
            ],
          );
          debugPrint(
            "Wardrobe fetch query field=$fieldName user=${user.$id} docs=${result.documents.length}",
          );
          for (final doc in result.documents) {
            byId[doc.$id] = _docToWardrobe(doc);
          }
        } catch (e) {
          debugPrint("Wardrobe fetch query field=$fieldName failed: $e");
        }
      }

      await _fetchByUserField('userId');
      if (byId.isEmpty) {
        await _fetchByUserField('user_id');
      }

      if (byId.isEmpty) {
        try {
          final result = await databases.listDocuments(
            databaseId: Env.appwriteDatabaseId,
            collectionId: Env.outfitsCollection,
            queries: [Query.orderDesc('\$createdAt'), Query.limit(300)],
          );
          final fallbackDocs = result.documents.where((doc) {
            final userId = (doc.data['userId'] ?? '').toString().trim();
            final userUnderscore = (doc.data['user_id'] ?? '').toString().trim();
            return userId == user.$id || userUnderscore == user.$id;
          });
          for (final doc in fallbackDocs) {
            byId[doc.$id] = _docToWardrobe(doc);
          }
          debugPrint(
            "Wardrobe fallback scan user=${user.$id} matched=${byId.length} total=${result.documents.length}",
          );
        } catch (e) {
          debugPrint("Wardrobe fallback scan failed: $e");
        }
      }

      final items = byId.values.toList()
        ..sort(
          (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
            a['createdAt']?.toString() ?? '',
          ),
        );
      for (final item in items) {
        item.remove('createdAt');
      }

      debugPrint("Wardrobe fetch final user=${user.$id} count=${items.length}");
      return items;
    } catch (e) {
      debugPrint("Error fetching wardrobe items: $e");
      return [];
    }
  }
  // =========================================================================
  // CALENDAR PLANS DB METHODS
  // =========================================================================

  Future<Document> createPlan(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final payload = Map<String, dynamic>.from(data);
      payload['userId'] = user.$id;
      payload['occasion'] =
          (payload['occasion']?.toString().trim().isNotEmpty ?? false)
          ? payload['occasion'].toString().trim()
          : 'Occasion';
      payload['emoji'] =
          (payload['emoji']?.toString().trim().isNotEmpty ?? false)
          ? payload['emoji'].toString().trim()
          : '\u2728';
      payload['dateTime'] =
          (payload['dateTime']?.toString().trim().isNotEmpty ?? false)
          ? payload['dateTime'].toString().trim()
          : DateTime.now().toUtc().toIso8601String();
      payload['reminder'] = payload['reminder'] == true;

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        documentId: ID.unique(),
        data: payload,
      );
    } catch (e) {
      debugPrint("Error creating plan: $e");
      rethrow;
    }
  }

  Future<List<Document>> getUserPlans() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        queries: [
          Query.equal('userId', user.$id),
          Query.orderAsc('dateTime'),
          Query.limit(1000),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching plans: $e");
      return [];
    }
  }

  Future<void> deletePlan(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting plan: $e");
      rethrow;
    }
  }

  Future<void> updatePlanReminder(String documentId, bool reminder) async {
    try {
      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        documentId: documentId,
        data: {'reminder': reminder},
      );
    } catch (e) {
      debugPrint("Error updating plan reminder: $e");
      rethrow;
    }
  }

  // =========================================================================
  // SAVED BOARDS DB METHODS
  // =========================================================================

  Future<Document?> createSavedBoard({
    required String occasion,
    required String imageUrl,
    List<String>? itemIds,
  }) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final cleanedItemIds = (itemIds ?? const <String>[])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(100)
          .toList();

      final data = <String, dynamic>{
        'userId': user.$id,
        'occasion': occasion,
        'imageUrl': imageUrl,
      };
      if (cleanedItemIds.isNotEmpty) {
        data['itemIds'] = cleanedItemIds;
      }

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating saved board: $e");
      return null;
    }
  }

  Future<List<Document>> getSavedBoardsByOccasion(String occasion) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.equal('occasion', occasion),
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching $occasion boards: $e");
      return [];
    }
  }

  Future<List<Document>> getAllSavedBoards() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching all boards: $e");
      return [];
    }
  }

  Future<void> deleteSavedBoard(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting board: $e");
      throw Exception("Failed to delete board");
    }
  }

  // =========================================================================
  // CHAT THREADS DB METHODS
  // =========================================================================

  Future<List<Document>> getChatThreads({String? module}) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final queries = <String>[
        Query.equal('userId', user.$id),
        Query.orderDesc('\$updatedAt'),
        Query.limit(100),
      ];
      final normalizedModule = (module ?? '').trim();
      if (normalizedModule.isNotEmpty) {
        queries.insert(1, Query.equal('module', normalizedModule));
      }

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.chatThreadsCollection,
        queries: queries,
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching chat threads: $e");
      return [];
    }
  }

  Future<Document?> upsertChatThread({
    required String threadId,
    required String title,
    required String module,
    required String lastMessage,
  }) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final data = <String, dynamic>{
        'userId': user.$id,
        'title': title,
        'module': module,
        'lastMessage': lastMessage,
      };

      // Try update first. If id does not exist (or is local temp id), create new.
      try {
        return await databases.updateDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.chatThreadsCollection,
          documentId: threadId,
          data: data,
        );
      } catch (_) {
        return await databases.createDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.chatThreadsCollection,
          documentId: ID.unique(),
          data: data,
        );
      }
    } catch (e) {
      debugPrint("Error upserting chat thread: $e");
      return null;
    }
  }

  Future<void> deleteChatThread(String threadId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.chatThreadsCollection,
        documentId: threadId,
      );
    } catch (e) {
      debugPrint("Error deleting chat thread: $e");
    }
  }

  String _encodeChatMeta(Map<String, dynamic>? meta) {
    if (meta == null || meta.isEmpty) return '';
    final encoded = jsonEncode(meta);
    return encoded.length <= 2000 ? encoded : encoded.substring(0, 2000);
  }

  Future<Document?> createChatMessage({
    required String threadId,
    required String role,
    required String content,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      final trimmedThreadId = threadId.trim();
      final trimmedRole = role.trim();
      final trimmedContent = content.trim();
      if (trimmedThreadId.isEmpty ||
          trimmedRole.isEmpty ||
          trimmedContent.isEmpty) {
        return null;
      }

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.chatMessagesCollection,
        documentId: ID.unique(),
        data: {
          'threadId': trimmedThreadId,
          'userId': user.$id,
          'role': trimmedRole,
          'content': trimmedContent,
          'meta': _encodeChatMeta(meta),
        },
      );
    } catch (e) {
      debugPrint("Error creating chat message: $e");
      return null;
    }
  }

  Future<List<Document>> getChatMessages({
    required String threadId,
    int limit = 500,
  }) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      final trimmedThreadId = threadId.trim();
      if (trimmedThreadId.isEmpty) return [];

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.chatMessagesCollection,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('threadId', trimmedThreadId),
          Query.orderAsc('\$createdAt'),
          Query.limit(limit.clamp(1, 500).toInt()),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching chat messages: $e");
      return [];
    }
  }

  Future<void> deleteChatMessagesByThread(String threadId) async {
    try {
      final docs = await getChatMessages(threadId: threadId, limit: 500);
      for (final d in docs) {
        try {
          await databases.deleteDocument(
            databaseId: Env.appwriteDatabaseId,
            collectionId: Env.chatMessagesCollection,
            documentId: d.$id,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Error deleting chat messages: $e");
    }
  }

  // =========================================================================
  // SKINCARE DB METHODS
  // =========================================================================

  Future<Document?> getSkincareProfile() async {
    try {
      final user = await getCurrentUser();
      if (user == null) return null;

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.skincareCollection,
        queries: [Query.equal('userId', user.$id)], // FIXED to userId
      );

      if (result.documents.isEmpty) {
        return await databases.createDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.skincareCollection,
          documentId: ID.unique(),
          data: {
            'userId': user.$id, // FIXED to userId
            'skinType': '',
            'concerns': [],
            'daySteps': [],
            'nightSteps': [],
            'lastUpdated': DateTime.now().toIso8601String(),
          },
        );
      }
      return result.documents.first;
    } catch (e) {
      debugPrint("Error fetching skincare profile: $e");
      return null;
    }
  }

  Future<void> updateSkincareProfile({
    required String documentId,
    String? skinType,
    List<String>? concerns,
    List<int>? daySteps,
    List<int>? nightSteps,
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      if (skinType != null) updateData['skinType'] = skinType;
      if (concerns != null) updateData['concerns'] = concerns;
      if (daySteps != null) updateData['daySteps'] = daySteps;
      if (nightSteps != null) updateData['nightSteps'] = nightSteps;
      updateData['lastUpdated'] = DateTime.now().toIso8601String();

      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.skincareCollection,
        documentId: documentId,
        data: updateData,
      );
    } catch (e) {
      debugPrint("Error updating skincare profile: $e");
    }
  }

  // =========================================================================
  // WORKOUT OUTFITS DB METHODS
  // =========================================================================

  Future<List<Document>> getWorkoutOutfits() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.workoutOutfitsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching workout outfits: $e");
      return [];
    }
  }

  Future<Document> createWorkoutOutfit(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      final name = (data['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        throw Exception("Workout outfit name is required");
      }
      final cat = (data['cat'] ?? '').toString().trim();
      final safeCat = cat.isEmpty ? 'gym' : cat;
      final tag = (data['tag'] ?? '').toString().trim();
      final safeTag = tag.isEmpty ? safeCat : tag;
      final emoji = (data['emoji'] ?? '').toString().trim();
      final rawItems = data['items'];
      final items = rawItems is List
          ? rawItems
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];
      final notes = (data['notes'] ?? '').toString().trim();

      data = {
        'userId': user.$id, // FIXED to userId
        'name': name,
        'emoji': emoji.isEmpty ? 'ðŸ‹ï¸' : emoji,
        'cat': safeCat,
        'tag': safeTag,
        'items': items,
        'notes': notes,
      };

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.workoutOutfitsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating workout outfit: $e");
      rethrow;
    }
  }

  Future<void> deleteWorkoutOutfit(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.workoutOutfitsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting workout outfit: $e");
      rethrow;
    }
  }

  // =========================================================================
  // BILLS & COUPONS DB METHODS
  // =========================================================================

  Future<List<Document>> getBills() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.billsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching bills: $e");
      return [];
    }
  }

  Future<Document> createBill(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.billsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating bill: $e");
      rethrow;
    }
  }

  Future<void> deleteBill(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.billsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting bill: $e");
      rethrow;
    }
  }

  Future<List<Document>> getCoupons() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.couponsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching coupons: $e");
      return [];
    }
  }

  Future<Document> createCoupon(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.couponsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating coupon: $e");
      rethrow;
    }
  }

  Future<void> deleteCoupon(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.couponsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting coupon: $e");
      rethrow;
    }
  }

  // =========================================================================
  // MEDI TRACKER DB METHODS
  // =========================================================================

  Future<List<Document>> getMeds() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching meds: $e");
      return [];
    }
  }

  Future<Document> createMed(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final name = (data['name'] ?? '').toString().trim();
      final dose = (data['dose'] ?? '').toString().trim();
      final freq = (data['freq'] ?? '').toString().trim();
      final time = (data['time'] ?? '').toString().trim();
      if (name.isEmpty || dose.isEmpty || freq.isEmpty || time.isEmpty) {
        throw Exception(
          "Medication name, dose, frequency, and time are required",
        );
      }

      final leftRaw = data['left'];
      final left = leftRaw is num
          ? leftRaw.toInt()
          : int.tryParse(leftRaw?.toString() ?? '') ?? 0;
      final totalRaw = data['total'];
      final total = totalRaw is num
          ? totalRaw.toInt()
          : int.tryParse(totalRaw?.toString() ?? '') ?? left;
      final takenToday = data['takenToday'] == true;
      final notes = (data['notes'] ?? '').toString().trim();
      final refillDateRaw = (data['refillDate'] ?? '').toString().trim();
      final refillDate = DateTime.tryParse(
        refillDateRaw,
      )?.toUtc().toIso8601String();

      final payload = <String, dynamic>{
        'userId': user.$id, // FIXED to userId
        'name': name,
        'dose': dose,
        'freq': freq,
        'time': time,
        'left': left < 0 ? 0 : left,
        'total': total < 0 ? 0 : total,
        'takenToday': takenToday,
        'notes': notes.isEmpty ? null : notes,
      };
      if (refillDate != null) {
        payload['refillDate'] = refillDate;
      }

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        documentId: ID.unique(),
        data: payload,
      );
    } catch (e) {
      debugPrint("Error creating med: $e");
      rethrow;
    }
  }

  Future<void> updateMed(String documentId, Map<String, dynamic> data) async {
    try {
      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        documentId: documentId,
        data: data,
      );
    } catch (e) {
      debugPrint("Error updating med: $e");
      rethrow;
    }
  }

  Future<void> deleteMed(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting med: $e");
      rethrow;
    }
  }

  Future<List<Document>> getMedLogs() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medLogsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching med logs: $e");
      return [];
    }
  }

  Future<Document> createMedLog(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status.isEmpty) {
        throw Exception("Med log status is required");
      }
      final medId = (data['medId'] ?? '').toString().trim();
      final medName = (data['medName'] ?? '').toString().trim();
      final takenAtRaw = data['takenAt'] ?? data['time'];
      String takenAt;
      if (takenAtRaw is DateTime) {
        takenAt = takenAtRaw.toIso8601String();
      } else {
        final parsed = DateTime.tryParse((takenAtRaw ?? '').toString());
        takenAt = (parsed ?? DateTime.now()).toIso8601String();
      }
      final payload = <String, dynamic>{
        'userId': user.$id, // FIXED to userId
        'medId': medId.isEmpty ? null : medId,
        'medName': medName.isEmpty ? null : medName,
        'takenAt': takenAt,
        'status': status,
      };

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medLogsCollection,
        documentId: ID.unique(),
        data: payload,
      );
    } catch (e) {
      debugPrint("Error creating med log: $e");
      rethrow;
    }
  }

  // =========================================================================
  // MEAL PLANNER DB METHODS
  // =========================================================================

  Future<List<Document>> getMealPlans() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.mealPlansCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching meal plans: $e");
      return [];
    }
  }

  Future<Document> createMealPlan(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      final name = (data['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        throw Exception("Meal plan name is required");
      }
      final desc = (data['desc'] ?? '').toString().trim();
      final planType = (data['planType'] ?? 'daily')
          .toString()
          .trim()
          .toLowerCase();
      final totalCalRaw = data['totalCal'];
      final totalCal = totalCalRaw is num
          ? totalCalRaw.toInt()
          : int.tryParse(totalCalRaw?.toString() ?? '') ?? 0;
      final rawMeals = data['meals'];
      final meals = rawMeals is List
          ? rawMeals
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];

      data = {
        'userId': user.$id, // FIXED to userId
        'name': name,
        'desc': desc.isEmpty ? 'Meal plan' : desc,
        'planType': planType.isEmpty ? 'daily' : planType,
        'totalCal': totalCal < 0 ? 0 : totalCal,
        'meals': meals,
      };

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.mealPlansCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating meal plan: $e");
      rethrow;
    }
  }

  Future<void> updateMealPlan(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      final payload = <String, dynamic>{};

      if (data.containsKey('name')) {
        final name = (data['name'] ?? '').toString().trim();
        if (name.isNotEmpty) payload['name'] = name;
      }
      if (data.containsKey('desc')) {
        final desc = (data['desc'] ?? '').toString().trim();
        payload['desc'] = desc.isEmpty ? 'Meal plan' : desc;
      }
      if (data.containsKey('planType')) {
        final planType = (data['planType'] ?? 'daily')
            .toString()
            .trim()
            .toLowerCase();
        payload['planType'] = planType.isEmpty ? 'daily' : planType;
      }
      if (data.containsKey('totalCal')) {
        final totalCalRaw = data['totalCal'];
        final totalCal = totalCalRaw is num
            ? totalCalRaw.toInt()
            : int.tryParse(totalCalRaw?.toString() ?? '') ?? 0;
        payload['totalCal'] = totalCal < 0 ? 0 : totalCal;
      }
      if (data.containsKey('meals')) {
        final rawMeals = data['meals'];
        payload['meals'] = rawMeals is List
            ? rawMeals
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
            : <String>[];
      }

      if (payload.isEmpty) return;

      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.mealPlansCollection,
        documentId: documentId,
        data: payload,
      );
    } catch (e) {
      debugPrint("Error updating meal plan: $e");
      rethrow;
    }
  }

  Future<void> deleteMealPlan(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.mealPlansCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting meal plan: $e");
      rethrow;
    }
  }

  // =========================================================================
  // LIFE GOALS DB METHODS
  // =========================================================================

  Future<List<Document>> getLifeGoals() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching life goals: $e");
      return [];
    }
  }

  Future<Document> createLifeGoal(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      final title = (data['title'] ?? '').toString().trim();
      if (title.isEmpty) {
        throw Exception("Life goal title is required");
      }
      final category = (data['category'] ?? '').toString().trim();
      if (category.isEmpty) {
        throw Exception("Life goal category is required");
      }
      final targetRaw = data['target'];
      final target = targetRaw is num
          ? targetRaw.toInt()
          : int.tryParse(targetRaw?.toString() ?? '') ?? 0;
      if (target <= 0) {
        throw Exception("Life goal target must be greater than 0");
      }
      final progressRaw = data['progress'];
      final progress = progressRaw is num
          ? progressRaw.toInt()
          : int.tryParse(progressRaw?.toString() ?? '') ?? 0;
      final description = (data['description'] ?? '').toString().trim();
      final unit = (data['unit'] ?? '').toString().trim();

      data = {
        'userId': user.$id, // FIXED to userId
        'title': title,
        'description': description.isEmpty ? null : description,
        'category': category,
        'target': target,
        'unit': unit.isEmpty ? null : unit,
        'progress': progress < 0 ? 0 : progress,
      };

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating life goal: $e");
      rethrow;
    }
  }

  Future<void> updateLifeGoal(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      final payload = <String, dynamic>{};

      if (data.containsKey('title')) {
        final title = (data['title'] ?? '').toString().trim();
        if (title.isNotEmpty) payload['title'] = title;
      }
      if (data.containsKey('description')) {
        final description = (data['description'] ?? '').toString().trim();
        payload['description'] = description.isEmpty ? null : description;
      }
      if (data.containsKey('category')) {
        final category = (data['category'] ?? '').toString().trim();
        if (category.isNotEmpty) payload['category'] = category;
      }
      if (data.containsKey('target')) {
        final targetRaw = data['target'];
        final target = targetRaw is num
            ? targetRaw.toInt()
            : int.tryParse(targetRaw?.toString() ?? '') ?? 0;
        if (target > 0) payload['target'] = target;
      }
      if (data.containsKey('unit')) {
        final unit = (data['unit'] ?? '').toString().trim();
        payload['unit'] = unit.isEmpty ? null : unit;
      }
      if (data.containsKey('progress')) {
        final progressRaw = data['progress'];
        final progress = progressRaw is num
            ? progressRaw.toInt()
            : int.tryParse(progressRaw?.toString() ?? '') ?? 0;
        payload['progress'] = progress < 0 ? 0 : progress;
      }

      if (payload.isEmpty) return;

      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        documentId: documentId,
        data: payload,
      );
    } catch (e) {
      debugPrint("Error updating life goal: $e");
      rethrow;
    }
  }

  Future<void> updateLifeGoalProgress(String documentId, int progress) async {
    try {
      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        documentId: documentId,
        data: {'progress': progress < 0 ? 0 : progress},
      );
    } catch (e) {
      debugPrint("Error updating life goal progress: $e");
      rethrow;
    }
  }

  Future<void> deleteLifeGoal(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting life goal: $e");
      rethrow;
    }
  }
}
