import 'dart:convert' show base64Decode;

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle, Uint8List;

import 'cache/cache.dart'
    if (dart.library.io) 'cache/io.dart'
    if (dart.library.js_interop) 'cache/html.dart'
    if (dart.library.html) 'cache/html.dart';

/// A cross-platform caching utility for downloading and storing binary data (like images).
///
/// It supports various data sources:
/// - HTTP/HTTPS URLs
/// - Local file paths
/// - Flutter asset paths (`assets/...`)
/// - Data URIs (`data:...`)
/// - Base64 encoded strings
///
/// Uses a platform-specific [Cache] implementation ([io.dart] or [html.dart])
/// for persistence and [Dio] for network requests.
class CrossCache {
  final Cache _cache;
  final Dio _dio;

  /// Optional base options for the internal [Dio] instance if one is not provided.
  final BaseOptions? options;

  /// Maximum number of retry attempts for network requests. Defaults to 3.
  final int maxRetries;

  /// Delay between retry attempts in milliseconds. Defaults to 1000ms.
  final int retryDelay;

  /// Whether to use exponential backoff for retry delays. Defaults to true.
  final bool useExponentialBackoff;

  /// Creates a [CrossCache] instance.
  ///
  /// Takes an optional [Dio] instance. If not provided, a default one is created
  /// using the optional [options].
  ///
  /// [maxRetries]: Maximum number of retry attempts (default: 3)
  /// [retryDelay]: Initial delay between retries in milliseconds (default: 1000)
  /// [useExponentialBackoff]: Whether to use exponential backoff (default: true)
  CrossCache({
    Dio? dio,
    this.options,
    this.maxRetries = 3,
    this.retryDelay = 1000,
    this.useExponentialBackoff = true,
  }) : _cache = Cache(),
       _dio = dio ?? Dio(options);

  /// Downloads data from the given [source] and saves it to the cache.
  ///
  /// If the data is already cached, it returns the cached bytes directly.
  /// Otherwise, it determines the source type (network, asset, local file, data URI, base64)
  /// fetches the data, saves it to the cache using the [source] string as the key,
  /// and returns the downloaded bytes.
  ///
  /// - [source]: The URL, file path, asset path, data URI, or base64 string.
  /// - [headers]: Optional HTTP headers for network requests.
  /// - [onReceiveProgress]: Optional callback for tracking download progress.
  ///
  /// Throws an exception if the source is invalid or download fails.
  Future<Uint8List> downloadAndSave(
    String source, {
    Map<String, dynamic>? headers,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final cached = await _cache.get(source);
      return cached;
      // ignore: empty_catches
    } catch (e) {}

    final uri = Uri.tryParse(source);

    if (source.startsWith('assets/')) {
      final byteData = await rootBundle.load(source);
      final bytes = Uint8List.view(byteData.buffer);
      await _cache.set(source, bytes);
      return bytes;
    } else if (uri != null && uri.scheme == 'data') {
      final data = uri.data;
      if (data == null) {
        throw Exception('Invalid data URI');
      }
      final bytes = data.contentAsBytes();
      await _cache.set(source, bytes);
      return bytes;
    } else if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'blob')) {
      // Try network request with retry mechanism
      return await _downloadWithRetry(
        source,
        headers: headers,
        onReceiveProgress: onReceiveProgress,
      );
    } else {
      // 尝试作为本地文件路径处理
      try {
        final xfile = XFile(source);
        // 优化：尝试读取文件，如果文件不存在会抛出异常
        final bytes = await xfile.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('File is empty: $source');
        }
        await _cache.set(source, bytes);
        return bytes;
      } catch (e) {
        // 如果文件读取失败（文件不存在或已损坏），继续尝试其他方式
        // 如果文件读取失败，尝试作为 base64 字符串
        try {
          final bytes = base64Decode(source);
          if (bytes.isEmpty) {
            throw Exception('Base64 decode resulted in empty bytes');
          }
          await _cache.set(source, bytes);
          return bytes;
        } catch (e2) {
          // 如果都失败了，抛出更详细的错误信息
          throw Exception(
            'Invalid source: cannot be processed. '
            'Tried as file path (error: ${e.toString()}) and base64 (error: ${e2.toString()}). '
            'Source: $source',
          );
        }
      }
    }
  }

  /// Stores the given byte [value] in the cache with the specified [key].
  ///
  /// Delegates to the underlying platform-specific [Cache] implementation.
  Future<void> set(String key, Uint8List value) => _cache.set(key, value);

  /// Retrieves the cached byte data for the given [key].
  ///
  /// Delegates to the underlying platform-specific [Cache] implementation.
  /// Throws if the key is not found.
  Future<Uint8List> get(String key) => _cache.get(key);

  /// Checks if the cache contains an entry for the given [key].
  ///
  /// Delegates to the underlying platform-specific [Cache] implementation.
  Future<bool> contains(String key) => _cache.contains(key);

  /// Removes the cache entry for the given [key].
  ///
  /// Delegates to the underlying platform-specific [Cache] implementation.
  Future<void> delete(String key) => _cache.delete(key);

  /// Renames a cache entry from [key] to [newKey].
  ///
  /// Delegates to the underlying platform-specific [Cache] implementation.
  /// Throws if the original [key] is not found.
  Future<void> updateKey(String key, String newKey) =>
      _cache.updateKey(key, newKey);

  /// Downloads data from network with automatic retry on failure.
  ///
  /// Implements exponential backoff if [useExponentialBackoff] is true.
  /// Retries [maxRetries] times before giving up.
  Future<Uint8List> _downloadWithRetry(
    String source, {
    Map<String, dynamic>? headers,
    ProgressCallback? onReceiveProgress,
    int attempt = 0,
  }) async {
    try {
      final response = await _dio.get(
        source,
        options: Options(headers: headers, responseType: ResponseType.bytes),
        onReceiveProgress: onReceiveProgress,
      );

      if (response.statusCode != 200) {
        throw DioException.badResponse(
          statusCode: response.statusCode ?? -1,
          requestOptions: response.requestOptions,
          response: response,
        );
      }

      final bytes = response.data as Uint8List;
      await _cache.set(source, bytes);

      return bytes;
    } catch (e) {
      // Check if we should retry
      if (attempt < maxRetries && _shouldRetry(e)) {
        // Calculate delay with exponential backoff if enabled
        final delay =
            useExponentialBackoff
                ? retryDelay *
                    (1 << attempt) // 2^attempt * retryDelay
                : retryDelay;

        // Log retry attempt
        print(
          'CrossCache: Network error for $source (attempt ${attempt + 1}/$maxRetries). '
          'Retrying in ${delay}ms... Error: $e',
        );

        await Future.delayed(Duration(milliseconds: delay));

        // Recursive retry
        return _downloadWithRetry(
          source,
          headers: headers,
          onReceiveProgress: onReceiveProgress,
          attempt: attempt + 1,
        );
      }

      // Max retries reached or non-retryable error
      print(
        'CrossCache: Failed to download $source after ${attempt + 1} attempts. Error: $e',
      );
      rethrow;
    }
  }

  /// Determines if an error is retryable.
  ///
  /// Returns true for network errors like connection timeouts, connection resets,
  /// DNS failures, etc. Returns false for client errors (4xx) or permanent failures.
  bool _shouldRetry(dynamic error) {
    if (error is DioException) {
      // Retry on connection errors
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return true;
      }

      // Retry on specific HTTP errors (5xx server errors)
      if (error.response?.statusCode != null) {
        final statusCode = error.response!.statusCode!;
        // Retry on 5xx server errors and 429 (rate limit)
        if (statusCode >= 500 || statusCode == 429) {
          return true;
        }
        // Don't retry on 4xx client errors (except 429)
        if (statusCode >= 400 && statusCode < 500) {
          return false;
        }
      }

      // Retry on unknown Dio errors (might be network issues)
      if (error.type == DioExceptionType.unknown) {
        return true;
      }
    }

    // Retry on generic exceptions (like SocketException)
    return true;
  }

  /// Disposes resources used by the cache.
  ///
  /// Closes the internal [Dio] client and calls `dispose` on the underlying
  /// platform-specific [Cache] implementation.
  void dispose() {
    _dio.close(force: true);
    _cache.dispose();
  }
}
