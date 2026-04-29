import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/config/env.dart';
import 'package:myapp/services/appwrite_service.dart';

Map<String, dynamic> _parseJsonMap(String payload) =>
    Map<String, dynamic>.from(jsonDecode(payload) as Map);

String _encodeBytes(Uint8List bytes) => base64Encode(bytes);

class BackendService {
  final String baseUrl = Env.backendApiUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final AppwriteService _appwriteService = AppwriteService();
  static const String _fallbackRailwayUrl =
      'https://myflow-production-6cf6.up.railway.app';

  BackendService() {
    final effective = baseUrl.isEmpty ? _fallbackRailwayUrl : baseUrl;
    debugPrint('BackendService init | baseUrl=$effective | envBaseUrl=$baseUrl');
  }

  Uri _buildApiUri(String path) {
    final rawBase = baseUrl.isEmpty ? _fallbackRailwayUrl : baseUrl;
    final full = '$rawBase$path';
    final uri = Uri.tryParse(full);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw Exception(
        'Invalid backend URL. EXPO_PUBLIC_BACKEND_API_URL="$baseUrl" resolved="$full"',
      );
    }
    return uri;
  }

  // --- Chat & Styling Engine ---
  Future<Map<String, dynamic>> sendChatQuery(
    String query,
    String userId,
    List<Map<String, String>> chatHistory,
    String currentMemory, {
    String? threadId,
    bool isRetry = false,
    List<Map<String, dynamic>>? fetchedWardrobe,
  }) async {
    try {
      if (!isRetry) {
        print("ðŸ’¬ Sending message to AHVI (No wardrobe attached yet)...");
      }

      // ðŸš€ STRIP THE FAT: Remove the heavy image URLs before sending to FastAPI!
      final safeWardrobePayload = (fetchedWardrobe ?? []).map((item) {
        final copy = Map<String, dynamic>.from(item);
        copy.remove('image_url'); // Server only needs the text to think!
        return copy;
      }).toList();
      final resolvedThreadId = (threadId ?? '').trim().isNotEmpty
          ? threadId!.trim()
          : 'main';

      final response = await http.post(
        _buildApiUri('/api/text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'thread_id': resolvedThreadId,
          'messages': [
            ...chatHistory,
            {'role': 'user', 'content': query},
          ],
          'language': 'en',
          'current_memory': currentMemory,
          'user_profile': {'name': userId.replaceFirst('user_', '')},
          'wardrobe_items': safeWardrobePayload,
          'wardrobe_attached': isRetry,
        }),
      );

      if (response.statusCode == 200) {
        final data = await compute(_parseJsonMap, response.body);

        // ðŸ›‘ THE PING-PONG INTERCEPTOR
        if (data['requires_wardrobe'] == true && !isRetry) {
          print("ðŸ›‘ AHVI requested your wardrobe! Fetching from Appwrite...");
          final items = await _appwriteService.getWardrobeItems();

          print(
            "âœ… Fetched ${items.length} items. Sending them back to AHVI...",
          );
          return sendChatQuery(
            query,
            userId,
            chatHistory,
            currentMemory,
            threadId: threadId,
            isRetry: true,
            fetchedWardrobe: items,
          );
        }

        // ðŸš€ UI LOGIC PARSING
        String rawText =
            data['message']?['content'] ??
            "I'm having trouble thinking right now.";
        String cleanText = rawText;

        List<dynamic> extractedChips = data['chips'] ?? [];
        String? extractedBoardData =
            (data['board_ids'] != null &&
                data['board_ids'].toString().isNotEmpty)
            ? data['board_ids']
            : null;
        String? extractedPackData =
            (data['pack_ids'] != null &&
                data['pack_ids'].toString().isNotEmpty)
            ? data['pack_ids']
            : null;
        String hiddenMenuText = "";

        RegExp chipsRegex = RegExp(r'\[CHIPS:\s*(.*?)\]');
        Match? chipsMatch = chipsRegex.firstMatch(cleanText);
        if (chipsMatch != null) {
          extractedChips = chipsMatch
              .group(1)!
              .split(',')
              .map((e) => e.trim())
              .toList();
          cleanText = cleanText.replaceAll(chipsMatch.group(0)!, '').trim();
        }

        RegExp boardRegex = RegExp(r'\[STYLE_BOARD:\s*(.*?)\]');
        Match? boardMatch = boardRegex.firstMatch(cleanText);
        if (boardMatch != null) {
          extractedBoardData = boardMatch.group(1);
          cleanText = cleanText.replaceAll(boardMatch.group(0)!, '').trim();
        }

        RegExp packRegex = RegExp(r'\[PACK_LIST:\s*(.*?)\]');
        Match? packMatch = packRegex.firstMatch(cleanText);
        if (packMatch != null) {
          extractedPackData = packMatch.group(1);
          hiddenMenuText = cleanText.replaceAll(packMatch.group(0)!, '').trim();
          cleanText = "I've prepared your custom Packing Menu! ðŸŒ´âœ¨";
        }

        data['message']['content'] = cleanText;
        data['chips'] = extractedChips;
        data['board_ids'] = extractedBoardData;
        data['pack_ids'] = extractedPackData;
        data['full_menu_text'] = hiddenMenuText;
        data['has_actions'] =
            (extractedBoardData != null || extractedPackData != null);

        return data;
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } catch (e) {
      print('Backend Error: $e');
      return {'error': 'Could not connect to AHVI brain. Error: $e'};
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  WARDROBE: VISION & BACKGROUND REMOVAL
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String?> removeBackground(String base64Image) async {
    try {
      final response = await http.post(
        _buildApiUri('/api/remove-bg'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64Image}),
      );
      if (response.statusCode == 200) {
        final data = await compute(_parseJsonMap, response.body);
        return data['image_base64'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ðŸš€ FIXED: Now converts Uint8List to Base64 and sends to the NEW JSON endpoint!
  Future<Map<String, dynamic>?> analyzeImage(Uint8List imageBytes) async {
    try {
      // 1. Convert the image bytes to a Base64 string
      final base64String = await compute(_encodeBytes, imageBytes);

      // 2. Point to the NEW endpoint from your vision.py router
      final uri = _buildApiUri('/api/analyze-image');

      // 3. Send a standard JSON POST request
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64String}),
      );

      if (response.statusCode == 200) {
        final rawPayload = utf8.decode(response.bodyBytes, allowMalformed: true);
        final dynamic decoded = jsonDecode(rawPayload);
        Map<String, dynamic> parsed;
        if (decoded is Map) {
          parsed = Map<String, dynamic>.from(decoded);
        } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          parsed = Map<String, dynamic>.from(decoded.first as Map);
        } else {
          print('Analyze API unexpected payload: ${decoded.runtimeType}');
          print('Analyze API payload (truncated): ${rawPayload.substring(0, rawPayload.length > 280 ? 280 : rawPayload.length)}');
          throw Exception(
            'Analyze API returned unexpected payload. '
            'Please retry analysis or enter details manually.',
          );
        }

        // Guard against backend version drift: some older analyze endpoints
        // return garment fields but omit masked_image_base64.
        final masked = parsed['masked_image_base64']?.toString().trim() ?? '';
        if (masked.isEmpty) {
          final fallbackMasked = await removeBackground(base64String);
          if (fallbackMasked != null && fallbackMasked.trim().isNotEmpty) {
            parsed['masked_image_base64'] = fallbackMasked.trim();
          } else {
            throw Exception(
              'Analyze API response missing masked_image_base64. '
              'Verify backend at $baseUrl is the latest version.',
            );
          }
        }
        return parsed;
      } else {
        String detail = response.body;
        try {
          final payload = jsonDecode(response.body);
          if (payload is Map && payload['detail'] != null) {
            detail = payload['detail'].toString();
          }
        } catch (_) {}
        throw Exception('Analyze API failed: $detail');
      }
    } catch (e) {
      print('âŒ Garment Analysis Error: $e');
      rethrow;
    }
  }
  Future<Map<String, dynamic>?> saveWardrobeItem({
    required String userId,
    required Uint8List rawImageBytes,
    required String maskedImageBase64,
    required String name,
    required String category,
    required List<String> occasions,
    String? subCategory,
    String? pattern,
    String? colorCode,
    String? notes,
    int worn = 0,
    bool liked = false,
    String rawFilename = 'upload.jpg',
  }) async {
    try {
      final response = await http.post(
        _buildApiUri('/api/wardrobe/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'name': name,
          'category': category,
          'sub_category': subCategory,
          'pattern': pattern,
          'occasions': occasions,
          'color_code': colorCode,
          'notes': notes ?? '',
          'worn': worn,
          'liked': liked,
          'raw_image_base64': base64Encode(rawImageBytes),
          'masked_image_base64': maskedImageBase64,
          'raw_filename': rawFilename,
        }),
      );

      if (response.statusCode != 200) {
        print('Wardrobe save failed: ${response.statusCode} - ${response.body}');
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (e) {
      print('Wardrobe save error: $e');
      return null;
    }
  }
}

