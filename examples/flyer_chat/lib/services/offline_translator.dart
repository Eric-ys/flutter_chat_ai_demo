import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 离线翻译服务
/// 从 assets/dict_en_zh.json 加载词典并提供翻译功能
class OfflineTranslator {
  static OfflineTranslator? _instance;
  static OfflineTranslator get instance {
    _instance ??= OfflineTranslator._();
    return _instance!;
  }

  OfflineTranslator._();

  Map<String, String>? _dictionary;
  Map<String, String>? _reverseDictionary;
  bool _isLoading = false;
  bool _isInitialized = false;

  /// 初始化词典（异步加载）
  Future<bool> initialize() async {
    if (_isInitialized && _dictionary != null) {
      return true;
    }

    if (_isLoading) {
      // 等待加载完成
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _dictionary != null;
    }

    _isLoading = true;
    try {
      // 从 assets 加载词典文件
      final String jsonString = await rootBundle.loadString('assets/dict_en_zh.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      // 转换为 Map<String, String>
      _dictionary = jsonData.map((key, value) => MapEntry(
        key.toLowerCase(),
        value is String ? value : value.toString(),
      ));

      // 构建反向词典（zh -> en），用于“中英互译”
      _reverseDictionary = <String, String>{};
      for (final entry in _dictionary!.entries) {
        final en = entry.key;
        final zh = entry.value.trim();
        if (zh.isNotEmpty) {
          // 只保留第一个英文映射，避免覆盖
          _reverseDictionary!.putIfAbsent(zh, () => en);
        }
      }
      
      _isInitialized = true;
      debugPrint('离线词典加载成功，共 ${_dictionary!.length} 条词条');
      return true;
    } catch (e) {
      debugPrint('加载离线词典失败: $e');
      _isInitialized = false;
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// 翻译文本
  /// @param text 要翻译的文本
  /// @return 翻译结果，如果未找到则返回 null
  String? translate(String text) {
    if (_dictionary == null || !_isInitialized) {
      return null;
    }

    // 将文本转为小写并去除首尾空格
    final key = text.toLowerCase().trim();

    if (key.isEmpty) {
      return null;
    }

    // 尝试精确匹配
    final translation = _dictionary![key];
    if (translation != null) {
      return translation;
    }

    // 如果未找到，尝试匹配单词（去除标点符号）
    final wordOnly = key.replaceAll(RegExp(r'[^a-z]'), '');
    if (wordOnly.isNotEmpty && wordOnly != key) {
      final wordTranslation = _dictionary![wordOnly];
      if (wordTranslation != null) {
        return wordTranslation;
      }
    }

    return null;
  }

  /// 自动中英互译：
  /// - 英文 -> 中文：走原有 en->zh 词典
  /// - 中文 -> 英文：走反向词典（zh->en）
  ///
  /// 返回：
  /// - 找到翻译：返回译文
  /// - 未找到：返回 null（由上层决定如何提示）
  ///
  /// 说明：这是离线词典的“词/短语级”翻译，不是完整句子机器翻译。
  String? translateAuto(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;

    // 简单判断：包含中文则认为 zh->en，否则 en->zh
    final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(t);
    if (hasChinese) {
      return translateZhToEnSmart(t);
    }

    return translate(t);
  }

  /// 中文 -> 英文（反向词典：精确匹配）
  String? translateZhToEn(String text) {
    if (_reverseDictionary == null || !_isInitialized) return null;
    final key = text.trim();
    if (key.isEmpty) return null;
    return _reverseDictionary![key];
  }

  /// 中文 -> 英文（更宽松的匹配）
  ///
  /// - 先尝试精确匹配整句/整段
  /// - 再按常见分隔符拆分后逐段匹配（适合“中文短语/词组”）
  String? translateZhToEnSmart(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;

    final exact = translateZhToEn(t);
    if (exact != null) return exact;

    // 拆分：空格/标点
    final parts = t
        .split(RegExp(r'[\s，。,\.！!？\?、;；:：]+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (parts.length == 1) return null;

    final translatedParts = <String>[];
    for (final p in parts) {
      final en = translateZhToEn(p) ?? p;
      translatedParts.add(en);
    }

    // 如果全都没翻译出来（都原样），返回 null
    final anyChanged = translatedParts.asMap().entries.any((e) => e.value != parts[e.key]);
    if (!anyChanged) return null;

    return translatedParts.join(' ');
  }

  /// 检查文本是否为英文（英文字符占比 ≥ 70%）
  bool isEnglishText(String text) {
    if (text.isEmpty) {
      return false;
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return false;
    }

    // 排除明显的 URL
    if (trimmedText.contains(RegExp(r'https?://|www\.|\.(com|org|net|io)', caseSensitive: false))) {
      return false;
    }

    // 排除纯数字或数字为主的文本
    final digitCount = trimmedText.split('').where((c) => c.contains(RegExp(r'[0-9]'))).length;
    final letterCount = trimmedText.split('').where((c) => c.contains(RegExp(r'[a-zA-Z]'))).length;
    if (digitCount > letterCount && letterCount < 3) {
      return false;
    }

    // 计算英文字符（ASCII 字母）和总字母字符数
    int englishCharCount = 0;
    int totalLetterCount = 0;

    for (final char in trimmedText.split('')) {
      if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        totalLetterCount++;
        // 检查是否为 ASCII 字母（英文字母）
        final code = char.codeUnitAt(0);
        if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
          englishCharCount++;
        }
      }
    }

    // 如果没有字母，不是英文
    if (totalLetterCount == 0) {
      return false;
    }

    // 英文字符占比 ≥ 70%
    final englishRatio = englishCharCount / totalLetterCount;
    final isEnglish = englishRatio >= 0.7;

    return isEnglish;
  }

  /// 检查词典是否已初始化
  bool get isInitialized => _isInitialized && _dictionary != null;
}

