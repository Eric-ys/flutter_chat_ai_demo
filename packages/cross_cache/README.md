# Cross Cache 💾

[![Pub Version](https://img.shields.io/pub/v/cross_cache?logo=flutter&color=orange)](https://pub.dev/packages/cross_cache) [![melos](https://img.shields.io/badge/maintained%20with-melos-ffffff.svg?color=orange)](https://github.com/invertase/melos)

A simple cross-platform caching library for Flutter, primarily designed for caching network resources like images.

## ✨ Features

- 💾 **Cross-Platform Caching:** Automatically uses the appropriate storage mechanism for Web and IO platforms.
- 🌐 **Versatile Fetching:** Downloads and caches resources from various sources:
    - Network URLs (http, https, blob)
    - Flutter asset paths (`assets/...`)
    - Data URIs (`data:...`)
    - Local file paths (IO platforms only)
    - Base64 encoded strings
- 🔁 **Automatic Retry:** Built-in retry mechanism with exponential backoff for transient network failures
- 🤝 **Dio Integration:** Uses [`dio`](https://pub.dev/packages/dio) for network requests (instance can be provided).
- 🖼️ **Flutter `ImageProvider`:** Includes `CachedNetworkImage`, a drop-in replacement for `NetworkImage` that uses the cache.
- ⚙️ **Standard Cache API:** Provides basic `get`, `set`, `contains`, `delete`, and `updateKey` methods for direct cache interaction.

## 🚀 Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  cross_cache: ^1.0.0
```

Then run `flutter pub get`.

## 📖 Usage

### Initialization

Create an instance of `CrossCache`. You can optionally provide your own configured `Dio` instance and customize retry behavior.

```dart
import 'package:cross_cache/cross_cache.dart';
import 'package:dio/dio.dart';

// Basic initialization (default: 3 retries, 1s delay, exponential backoff)
final cache = CrossCache();

// Or with custom retry configuration
final cacheWithRetry = CrossCache(
  maxRetries: 5,                    // Retry up to 5 times
  retryDelay: 2000,                 // 2 seconds initial delay
  useExponentialBackoff: true,      // Use exponential backoff (2s, 4s, 8s, ...)
);

// Or with a custom Dio instance
final dio = Dio(/* your custom options */);
final customCache = CrossCache(dio: dio);

// Remember to dispose when done (e.g., in your State's dispose method)
// cache.dispose();
```

### Downloading and Caching (`downloadAndSave`)

This is the primary method for fetching resources from various sources and caching them automatically. It returns the `Uint8List` data. If the resource is already cached, it returns the cached data directly.

**🔁 Automatic Retry:** Network requests automatically retry on transient failures (connection timeout, server errors, etc.) with configurable retry count and delays.

```dart
Future<void> loadImageData(String imageUrl) async {
  try {
    final Uint8List imageData = await cache.downloadAndSave(
      imageUrl,
      headers: {'Authorization': 'Bearer YOUR_TOKEN'}, // Optional headers
      onReceiveProgress: (cumulative, total) {
        print('Download progress: ${cumulative / total * 100}%'); // Optional progress
      },
    );
    // Use imageData (e.g., display with Image.memory)
    print('Image loaded, ${imageData.lengthInBytes} bytes');
  } catch (e) {
    print('Error loading image after retries: $e');
    // Handle final error (e.g., show placeholder)
  }
}

// Examples of different sources:
// await loadImageData('https://example.com/image.jpg');
// await loadImageData('assets/my_icon.png');
// await loadImageData('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA...');
// await loadImageData('/path/to/local/file.jpg'); // IO only
// await loadImageData('iVBORw0KGgoAAAANSUhEUgAAAAUA...'); // Base64 string
```

### Using `CachedNetworkImage` (Flutter)

Use `CachedNetworkImage` directly with Flutter's `Image` widget as a replacement for `NetworkImage`. It automatically uses your `CrossCache` instance.

```dart
import 'package:flutter/material.dart';
import 'package:cross_cache/cross_cache.dart';

class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final _cache = CrossCache(); // Create an instance

  @override
  void dispose() {
    _cache.dispose(); // Dispose the cache
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: CachedNetworkImage(
        'https://example.com/image.jpg',
        _cache, // Pass the cache instance
        headers: {'Authorization': 'Bearer YOUR_TOKEN'}, // Optional headers
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
    );
  }
}

```

### Direct Cache Access

You can interact with the cache directly if needed, though `downloadAndSave` handles most common cases.

```dart
// Check if an item exists
bool exists = await cache.contains('my_unique_key');

// Manually add data
Uint8List myData = Uint8List.fromList([1, 2, 3]);
await cache.set('my_unique_key', myData);

// Retrieve data
try {
  Uint8List cachedData = await cache.get('my_unique_key');
  // Use cachedData
} catch (e) {
  print('Key not found or error: $e');
}

// Delete data
await cache.delete('my_unique_key');

// Rename cache key
// await cache.updateKey('old_key', 'new_key');
```

## 🤔 How It Works

-   **Web:** Uses the `idb_shim` package to store `Uint8List` data in an IndexedDB object store named `data` within a database called `cross_cache_db`. The cache key is used directly as the IndexedDB key.
-   **IO:** Uses the `path_provider` package to get the application's cache directory. It creates a `cross_cache` subdirectory. The provided cache key is SHA256 hashed to create a unique filename, and the `Uint8List` data is written to that file.

## 🔁 Retry Mechanism

The library automatically retries failed network requests to handle transient network issues:

### Retry Strategy
- **Retryable Errors**: Connection timeouts, connection resets, DNS failures, 5xx server errors, 429 rate limits
- **Non-Retryable Errors**: 4xx client errors (except 429), invalid URLs
- **Exponential Backoff**: Default delays grow exponentially (1s → 2s → 4s → 8s...)
- **Linear Backoff**: Optional fixed delay between retries

### Configuration Options
```dart
final cache = CrossCache(
  maxRetries: 3,                    // Number of retry attempts (default: 3)
  retryDelay: 1000,                 // Initial delay in ms (default: 1000)
  useExponentialBackoff: true,      // Use exponential backoff (default: true)
);
```

### Logging
Retry attempts are logged to console for debugging:
```
CrossCache: Network error for https://example.com/image.jpg (attempt 1/3). 
Retrying in 1000ms... Error: DioException [unknown]: Connection reset by peer
```

## 🚧 Future Work

-   Cache management features like manual/automatic purging.
-   Cancellation support for downloads in progress.
-   Option to set maximum cache size or item count.
-   Caching strategy (LRU, MRU, FIFO etc.)

## 🤝 Contributing

Contributions are welcome! Please see the main project's [Contributing Guide](https://github.com/flyerhq/flutter_chat_ui/blob/main/CONTRIBUTING.md).

## 📜 License

Licensed under the MIT License. See the [LICENSE](https://github.com/flyerhq/flutter_chat_ui/blob/main/packages/cross_cache/LICENSE) file for details.
