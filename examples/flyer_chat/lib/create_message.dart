import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_lorem/flutter_lorem.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

Future<Message> createMessage(
  UserID authorId,
  Dio dio, {
  bool? textOnly,
  bool? localOnly,
  String? text,
}) async {
  const uuid = Uuid();
  Message message;

  // 只生成文本和图片，不生成文件消息（FileMessage）
  final randomType = Random().nextInt(2) + 1; // 1 or 2 (文本或图片)

  if (randomType == 1 || textOnly == true || text != null) {
    message = TextMessage(
      id: uuid.v4(),
      authorId: authorId,
      createdAt: DateTime.now().toUtc(),
      sentAt: localOnly == true ? DateTime.now().toUtc() : null,
      text: text ?? lorem(paragraphs: 1, words: Random().nextInt(30) + 1),
      metadata: isOnlyEmoji(text ?? '') ? {'isOnlyEmoji': true} : null,
    );
  } else {
    // 从本地相册随机选取图片
    final picker = ImagePicker();
    try {
      // 尝试从相册获取图片（不等待用户选择，如果用户取消则使用默认图片）
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        message = ImageMessage(
          id: uuid.v4(),
          authorId: authorId,
          createdAt: DateTime.now().toUtc(),
          sentAt: localOnly == true ? DateTime.now().toUtc() : null,
          source: image.path,
        );
      } else {
        // 如果用户取消选择，使用固定图片URL
        const fixedImageUrl =
            'https://pic.rmb.bdstatic.com/bjh/news/3fe6db1a8d291be39192f9a06c74ce99.png';
        const fixedThumbhash = '2gcODIKwdmg9eId1l4qTb2v4xw';
        const fixedBlurhash = 'LPFFjU00^+IV~W4n%LRkROM|WBxu';

        message = ImageMessage(
          id: uuid.v4(),
          authorId: authorId,
          createdAt: DateTime.now().toUtc(),
          sentAt: localOnly == true ? DateTime.now().toUtc() : null,
          source: fixedImageUrl,
          thumbhash: fixedThumbhash,
          blurhash: fixedBlurhash,
        );
      }
    } catch (e) {
      // 如果选择图片失败（权限问题等），使用固定图片URL
      const fixedImageUrl =
          'https://pic.rmb.bdstatic.com/bjh/news/3fe6db1a8d291be39192f9a06c74ce99.png';
      const fixedThumbhash = '2gcODIKwdmg9eId1l4qTb2v4xw';
      const fixedBlurhash = 'LPFFjU00^+IV~W4n%LRkROM|WBxu';

      message = ImageMessage(
        id: uuid.v4(),
        authorId: authorId,
        createdAt: DateTime.now().toUtc(),
        sentAt: localOnly == true ? DateTime.now().toUtc() : null,
        source: fixedImageUrl,
        thumbhash: fixedThumbhash,
        blurhash: fixedBlurhash,
      );
    }
  }

  // return ImageMessage(
  //   id: uuid.v4(),
  //   author: author,
  //   createdAt: DateTime.now().toUtc(),
  //   sentAt: localOnly == true ? DateTime.now().toUtc() : null,
  //   source:
  //       'https://www.hdcarwallpapers.com/walls/audi_r8_spyder_v10_performance_rwd_2021_4k_8k-HD.jpg',
  //   thumbhash: '2gcODIKwdmg9eId1l4qTb2v4xw',
  //   blurhash: 'LPFFjU00^+IV~W4n%LRkROM|WBxu',
  // );

  return message;
}
