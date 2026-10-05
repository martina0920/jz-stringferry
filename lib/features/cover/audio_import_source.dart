import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

/// 一次成功导入的音频文件。
class ImportedAudio {
  /// 拷入应用文档目录后的绝对路径。
  final String path;
  final String title;

  const ImportedAudio({required this.path, required this.title});
}

/// 本地音频导入抽象（测试注入 Fake）。
abstract class AudioImportSource {
  /// 拉起系统文件选择器并拷贝到应用目录；取消/失败返回 null。
  Future<ImportedAudio?> pickAndCopy();
}

/// 生产实现：file_picker 选音频 → 拷入 <docs>/cover_audio/。
class FilePickerAudioImportSource implements AudioImportSource {
  @override
  Future<ImportedAudio?> pickAndCopy() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    final srcPath = files.isEmpty ? null : files.first.path;
    if (srcPath == null) return null;

    final src = File(srcPath);
    if (!await src.exists()) return null;

    final dir = await coverAudioDir();
    final ext = srcPath.contains('.')
        ? srcPath.substring(srcPath.lastIndexOf('.'))
        : '.audio';
    final destPath = '${dir.path}${Platform.pathSeparator}'
        '${const Uuid().v4()}$ext';
    await src.copy(destPath);

    var title = srcPath.contains('/')
        ? srcPath.substring(srcPath.lastIndexOf('/') + 1)
        : srcPath;
    if (title.contains('\\')) {
      title = title.substring(title.lastIndexOf('\\') + 1);
    }
    if (title.contains('.')) {
      title = title.substring(0, title.lastIndexOf('.'));
    }
    return ImportedAudio(path: destPath, title: title.isEmpty ? '导入音频' : title);
  }
}

/// 扒带音频统一存放目录（不存在则创建）。
Future<Directory> coverAudioDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(
      '${docs.path}${Platform.pathSeparator}cover_audio');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}
