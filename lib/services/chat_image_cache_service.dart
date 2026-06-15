import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatImageCacheService {
  ChatImageCacheService._();
  static final ChatImageCacheService instance = ChatImageCacheService._();

  static const _prefPrefix = 'chat_image_cache_v2_';
  static const _mediaChannel = MethodChannel('com.kimyuseong.motivating/media');

  Future<File> getImageFile(String url) async {
    final cached = await _cachedFile(url);
    if (cached != null) return cached;
    return _downloadToCache(url);
  }

  Future<void> cacheLocalImage(String url, File source) async {
    if (!await source.exists()) return;
    final target = await _cacheFileFor(url);
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    await _saveCachePath(url, target.path);
  }

  Future<String> saveToDownloads(String url) async {
    final file = await _freshFileForDownload(url);
    final fileName = _downloadFileName(url);
    final bytes = await file.readAsBytes();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final saved = await _saveToAndroidGallery(bytes, fileName);
      return saved ?? fileName;
    }

    final dir = await _downloadDir();
    await dir.create(recursive: true);
    final target = File('${dir.path}${Platform.pathSeparator}$fileName');
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<File> _freshFileForDownload(String url) async {
    try {
      return await _downloadToCache(url);
    } catch (_) {
      final cached = await _cachedFile(url);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<String?> _saveToAndroidGallery(Uint8List bytes, String fileName) async {
    try {
      return await _invokeAndroidSave(bytes, fileName);
    } on PlatformException catch (e) {
      if (e.code != 'NEEDS_PERMISSION') rethrow;
      final granted = await Permission.storage.request();
      if (!granted.isGranted) {
        throw PlatformException(
          code: 'PERMISSION_DENIED',
          message: 'Storage permission was denied.',
        );
      }
      return _invokeAndroidSave(bytes, fileName);
    }
  }

  Future<String?> _invokeAndroidSave(Uint8List bytes, String fileName) {
    return _mediaChannel.invokeMethod<String>('saveImage', {
      'bytes': bytes,
      'fileName': fileName,
      'mimeType': _mimeType(fileName),
    });
  }

  Future<File?> _cachedFile(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey(url));
    if (raw == null || raw.isEmpty) return null;

    String? path;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['url'] != url) {
        await prefs.remove(_prefKey(url));
        return null;
      }
      path = data['path'] as String?;
    } catch (_) {
      await prefs.remove(_prefKey(url));
      return null;
    }

    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (await file.exists()) return file;
    await prefs.remove(_prefKey(url));
    return null;
  }

  Future<File> _downloadToCache(String url) async {
    final uri = Uri.parse(url);
    final res = await http.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('image download failed: ${res.statusCode}');
    }

    final target = await _cacheFileFor(url, contentType: res.headers['content-type']);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(res.bodyBytes, flush: true);
    await _saveCachePath(url, target.path);
    return target;
  }

  Future<File> _cacheFileFor(String url, {String? contentType}) async {
    final dir = await _cacheDir();
    final ext = _extensionFrom(url, contentType: contentType);
    return File('${dir.path}${Platform.pathSeparator}${_stableKey(url)}$ext');
  }

  Future<Directory> _cacheDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}chat_image_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _downloadDir() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return Directory('${downloads.path}${Platform.pathSeparator}Motivating');
      }
    } catch (_) {}
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}${Platform.pathSeparator}downloads');
  }

  Future<void> _saveCachePath(String url, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey(url), jsonEncode({
      'url': url,
      'path': path,
      'cachedAt': DateTime.now().toIso8601String(),
    }));
  }

  String _prefKey(String url) => '$_prefPrefix${_stableKey(url)}';

  String _stableKey(String value) => sha256.convert(utf8.encode(value)).toString();

  String _downloadFileName(String url) {
    final ext = _extensionFrom(url);
    return 'motivating_chat_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  String _extensionFrom(String url, {String? contentType}) {
    try {
      final last = Uri.parse(url).pathSegments.last.toLowerCase();
      final dot = last.lastIndexOf('.');
      if (dot >= 0) {
        final ext = last.substring(dot);
        if (_isImageExtension(ext)) return ext;
      }
    } catch (_) {}

    if (contentType?.contains('png') == true) return '.png';
    if (contentType?.contains('webp') == true) return '.webp';
    if (contentType?.contains('gif') == true) return '.gif';
    return '.jpg';
  }

  bool _isImageExtension(String ext) =>
      ext == '.jpg' || ext == '.jpeg' || ext == '.png' ||
      ext == '.webp' || ext == '.gif';

  String _mimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
