import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, {this.status});
  @override
  String toString() => 'ApiException(${status ?? ''}): $message';
}

class ApiService {
  // IMPORTANT:
  // - On Android emulator use http://10.0.2.2
  // - On iOS simulator/desktop/web use http://127.0.0.1
  // - On a physical device use your PC's LAN IP (e.g. http://192.168.x.x)
  // You can override via: --dart-define=API_BASE_URL=http://192.168.x.x/bot/server/public
  static final String baseUrl = _detectBaseUrl();

  static String get uploadBaseUrl {
    final root = baseUrl;
    if (root.endsWith('/public')) return root;
    return '$root/public';
  }

  static String _detectBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://127.0.0.1/bot/server/public';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2/bot/server/public';
    }
    return 'http://127.0.0.1/bot/server/public';
  }

  Uri _url(String path) => Uri.parse('$baseUrl$path');

  Future<(String token, Map<String, dynamic> user)> login({required String username, required String password}) async {
    final res = await http.post(
      _url('/api/login.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = _decode(res);
    // Be tolerant to slightly different shapes or extra output
    final token = (data['token']) ?? (data['data'] is Map ? (data['data']['token']) : null);
    final user = (data['user']) ?? (data['data'] is Map ? (data['data']['user']) : null);
    if (res.statusCode >= 200 && res.statusCode < 300 && token != null) {
      final userMap = (user is Map) ? Map<String, dynamic>.from(user) : <String, dynamic>{};
      return (token as String, userMap);
    }
    final msg = data['error']?.toString() ?? (data['raw']?.toString()) ?? 'Login failed';
    throw ApiException(msg, status: res.statusCode);
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final res = await http.get(
      _url('/api/profile.php'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['profile'] != null) {
      return Map<String, dynamic>.from(data['profile'] as Map);
    }
    throw ApiException(data['error']?.toString() ?? 'Cannot load profile', status: res.statusCode);
  }

  Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> payload) async {
    final res = await http.post(
      _url('/api/profile.php'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['profile'] != null) {
      return Map<String, dynamic>.from(data['profile'] as Map);
    }
    throw ApiException(data['error']?.toString() ?? 'Cannot update profile', status: res.statusCode);
  }

  // Posts
  Future<List<Map<String, dynamic>>> getPosts({int limit = 20, int offset = 0}) async {
    final uri = _url('/api/posts.php').replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
    });
    final res = await http.get(uri);
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = (data['posts'] as List?) ?? const [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw ApiException(data['error']?.toString() ?? 'Cannot load posts', status: res.statusCode);
  }

  Future<Map<String, dynamic>> createPost(String token, String content, {String visibility = 'public', String? bgColor, String? textColor, String? emoji}) async {
    final res = await http.post(
      _url('/api/posts.php'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'content': content, 'visibility': visibility, 'bg_color': bgColor, 'text_color': textColor, 'feeling_emoji': emoji}),
    );
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['post'] != null) {
      return Map<String, dynamic>.from(data['post'] as Map);
    }
    throw ApiException(data['error']?.toString() ?? 'Cannot create post', status: res.statusCode);
  }

  Future<Map<String, dynamic>> createPostWithImage(String token, String content, String imagePath,
      {String? filename, String? contentType, String visibility = 'public', String? bgColor, String? textColor, String? emoji}) async {
    final req = http.MultipartRequest('POST', _url('/api/posts.php'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['content'] = content
      ..fields['visibility'] = visibility
      ..fields['bg_color'] = bgColor ?? ''
      ..fields['text_color'] = textColor ?? ''
      ..fields['feeling_emoji'] = emoji ?? ''
      ..files.add(await http.MultipartFile.fromPath('image', imagePath, filename: filename, contentType: _mediaType(contentType)));
    final res = await http.Response.fromStream(await req.send());
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['post'] != null) {
      return Map<String, dynamic>.from(data['post'] as Map);
    }
    throw ApiException(data['error']?.toString() ?? 'Cannot create post', status: res.statusCode);
  }

  Future<void> deletePost(String token, int id) async {
    final uri = _url('/api/posts.php').replace(queryParameters: {'id': '$id'});
    final res = await http.delete(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = _decode(res);
      throw ApiException(data['error']?.toString() ?? 'Cannot delete post', status: res.statusCode);
    }
  }

  Future<Map<String, dynamic>> updatePost(
    String token,
    int id,
    {
      required String content,
      String visibility = 'public',
      String? bgColor,
      String? textColor,
      String? emoji,
    }
  ) async {
    final uri = _url('/api/posts.php').replace(queryParameters: {'id': '$id'});
    final res = await http.patch(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'content': content,
        'visibility': visibility,
        'bg_color': bgColor,
        'text_color': textColor,
        'feeling_emoji': emoji,
      }),
    );
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['post'] != null) {
      return Map<String, dynamic>.from(data['post'] as Map);
    }
    throw ApiException(data['error']?.toString() ?? 'Cannot update post', status: res.statusCode);
  }

  // Web/bytes-friendly variant for image uploads
  Future<Map<String, dynamic>> createPostWithImageBytes(
    String token,
    String content,
    List<int> bytes, {
    String filename = 'image.jpg',
    String? contentType,
    String visibility = 'public',
    String? bgColor,
    String? textColor,
    String? emoji,
  }) async {
    final req = http.MultipartRequest('POST', _url('/api/posts.php'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['content'] = content
      ..fields['visibility'] = visibility
      ..fields['bg_color'] = bgColor ?? ''
      ..fields['text_color'] = textColor ?? ''
      ..fields['feeling_emoji'] = emoji ?? ''
      ..files.add(http.MultipartFile.fromBytes('image', bytes, filename: filename, contentType: _mediaType(contentType)));
    final res = await http.Response.fromStream(await req.send());
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['post'] != null) {
      return Map<String, dynamic>.from(data['post'] as Map);
    }
    throw ApiException(data['error']?.toString() ?? 'Cannot create post', status: res.statusCode);
  }

  

  Future<Map<String, dynamic>> reactToPost(String token, int postId, {String type = 'like'}) async {
    final res = await http.post(
      _url('/api/reactions.php'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'post_id': postId, 'type': type}),
    );
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(data['error']?.toString() ?? 'Reaction failed', status: res.statusCode);
  }

  Future<Map<String, dynamic>> getReactions(int postId, {String? token}) async {
    final uri = _url('/api/reactions.php').replace(queryParameters: {'post_id': '$postId'});
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final res = await http.get(uri, headers: headers);
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }
    throw ApiException(data['error']?.toString() ?? 'Cannot load reactions', status: res.statusCode);
  }

  Future<List<Map<String, dynamic>>> getComments(int postId) async {
    final uri = _url('/api/comments.php').replace(queryParameters: {'post_id': '$postId'});
    final res = await http.get(uri);
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = (data['comments'] as List?) ?? const [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw ApiException(data['error']?.toString() ?? 'Cannot load comments', status: res.statusCode);
  }

  Future<Map<String, dynamic>> addComment(String token, int postId, String content, {int? parentId}) async {
    final res = await http.post(
      _url('/api/comments.php'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'post_id': postId, 'content': content, if (parentId != null) 'parent_id': parentId}),
    );
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return Map<String, dynamic>.from(data['comment'] as Map);
    throw ApiException(data['error']?.toString() ?? 'Cannot add comment', status: res.statusCode);
  }

  Future<void> deleteComment(String token, int commentId) async {
    final uri = _url('/api/comments.php').replace(queryParameters: {'id': '$commentId'});
    final res = await http.delete(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = _decode(res);
      throw ApiException(data['error']?.toString() ?? 'Cannot delete comment', status: res.statusCode);
    }
  }

  Future<Map<String, dynamic>> reactToComment(String token, int commentId, {String type = 'like'}) async {
    final res = await http.post(
      _url('/api/comment_reactions.php'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'comment_id': commentId, 'type': type}),
    );
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(data['error']?.toString() ?? 'Reaction failed', status: res.statusCode);
  }

  Future<Map<String, dynamic>> getCommentReactions(int commentId, {String? token}) async {
    final uri = _url('/api/comment_reactions.php').replace(queryParameters: {'comment_id': '$commentId'});
    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final res = await http.get(uri, headers: headers);
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return Map<String, dynamic>.from(data);
    throw ApiException(data['error']?.toString() ?? 'Cannot load comment reactions', status: res.statusCode);
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return (body is Map<String, dynamic>) ? body : <String, dynamic>{'data': body};
    } catch (_) {
      // Try to salvage JSON from noisy responses (e.g., warnings before JSON)
      final text = res.body;
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final slice = text.substring(start, end + 1);
        try {
          final body = jsonDecode(slice);
          return (body is Map<String, dynamic>) ? body : <String, dynamic>{'data': body};
        } catch (_) {}
      }
      return <String, dynamic>{'error': 'Invalid JSON', 'raw': res.body};
    }
  }

  Future<String> uploadAvatarBytes(String token, List<int> bytes, {String filename = 'avatar.jpg', String contentType = 'image/jpeg'}) async {
    final req = http.MultipartRequest('POST', _url('/api/avatar.php'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: _mediaType(contentType)));
    final res = await http.Response.fromStream(await req.send());
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['avatar_url'] != null) {
      return data['avatar_url'] as String;
    }
    throw ApiException(data['error']?.toString() ?? 'Upload failed', status: res.statusCode);
  }

  Future<String> uploadAvatarPath(String token, String path, {String? filename, String? contentType}) async {
    final req = http.MultipartRequest('POST', _url('/api/avatar.php'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', path, filename: filename, contentType: _mediaType(contentType)));
    final res = await http.Response.fromStream(await req.send());
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['avatar_url'] != null) {
      return data['avatar_url'] as String;
    }
    throw ApiException(data['error']?.toString() ?? 'Upload failed', status: res.statusCode);
  }

  Future<void> deleteAvatar(String token) async {
    final res = await http.delete(_url('/api/avatar.php'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = _decode(res);
      throw ApiException(data['error']?.toString() ?? 'Delete failed', status: res.statusCode);
    }
  }

  // Banner upload/delete
  Future<String> uploadBannerBytes(String token, List<int> bytes, {String filename = 'banner.jpg', String contentType = 'image/jpeg'}) async {
    final req = http.MultipartRequest('POST', _url('/api/banner.php'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: _mediaType(contentType)));
    final res = await http.Response.fromStream(await req.send());
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['banner_url'] != null) {
      return data['banner_url'] as String;
    }
    throw ApiException(data['error']?.toString() ?? 'Upload failed', status: res.statusCode);
  }

  Future<String> uploadBannerPath(String token, String path, {String? filename, String? contentType}) async {
    final req = http.MultipartRequest('POST', _url('/api/banner.php'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', path, filename: filename, contentType: _mediaType(contentType)));
    final res = await http.Response.fromStream(await req.send());
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['banner_url'] != null) {
      return data['banner_url'] as String;
    }
    throw ApiException(data['error']?.toString() ?? 'Upload failed', status: res.statusCode);
  }

  Future<void> deleteBanner(String token) async {
    final res = await http.delete(_url('/api/banner.php'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = _decode(res);
      throw ApiException(data['error']?.toString() ?? 'Delete failed', status: res.statusCode);
    }
  }

  // Helper to build MediaType without importing http_parser directly
  dynamic _mediaType(String? contentType) {
    if (contentType == null) return null;
    try {
      final parts = contentType.split('/');
      if (parts.length == 2) {
        // http.MultipartFile expects a MediaType from package:http_parser, but
        // it accepts a dynamic. Avoid hard dep; null is also acceptable.
        // However, when null, http will infer from filename. We'll return null if parsing fails.
        // Leaving as null keeps compatibility.
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> updateComment(String token, int commentId, String text) async {
    final res = await http.patch(
      _url('/api/comments.php'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'id': commentId, 'content': text}),
    );
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['comment'] is Map) {
      return Map<String, dynamic>.from(data['comment'] as Map);
    }
    throw ApiException(data['error']?.toString() ?? 'Cannot update comment', status: res.statusCode);
  }

  Future<String> uploadCommentMedia(String token, String path, {String? filename, String? contentType}) async {
    final req = http.MultipartRequest('POST', _url('/api/comment_media.php'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', path, filename: filename, contentType: _mediaType(contentType)));
    final res = await http.Response.fromStream(await req.send());
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['url'] != null) {
      return data['url'] as String;
    }
    throw ApiException(data['error']?.toString() ?? 'Upload failed', status: res.statusCode);
  }

  Future<String> uploadCommentMediaBytes(String token, List<int> bytes,
      {String filename = 'attachment.jpg', String? contentType}) async {
    final req = http.MultipartRequest('POST', _url('/api/comment_media.php'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: _mediaType(contentType)));
    final res = await http.Response.fromStream(await req.send());
    final data = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['url'] != null) {
      return data['url'] as String;
    }
    throw ApiException(data['error']?.toString() ?? 'Upload failed', status: res.statusCode);
  }
}
