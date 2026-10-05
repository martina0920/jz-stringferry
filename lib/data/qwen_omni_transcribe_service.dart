import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'transcribe_service.dart';

/// 阿里百炼 Qwen-Omni 云端识别（OpenAI 兼容 Chat Completions）。
///
/// 音频以 base64 放入 input_audio；超时 [timeout]、失败（网络/5xx/
/// 解析失败）自动重试一次；音频 > [maxUploadBytes] 直接抛
/// [TranscribeException] 引导用户录制短片段。
class QwenOmniTranscribeService implements TranscribeService {
  final http.Client client;

  /// 可注入覆写（测试用）；生产为固定北京地域端点。
  final Uri? endpointOverride;

  final Duration timeout;
  final int maxRetries;

  static const int maxUploadBytes = 8 * 1024 * 1024;
  static const String model = 'qwen3.8-omni-flash';

  static const String defaultEndpoint =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';

  /// 要求模型返回的 JSON 结构（写在 prompt 里）。
  static const String prompt =
      '你是扒带助手。听这段音频，判断它的调性、速度与和弦进行，'
      '只输出一个 JSON 对象，不要输出任何其他文字或代码块围栏，格式：'
      '{"key_root_pc":0 到 11 的整数，C=0，"key_mode":"major 或 minor",'
      '"bpm":整数,"chords":["C","Am","F","G"],'
      '"segments":[{"start_ms":0,"end_ms":15000,"label":"段落名",'
      '"chords":["C","Am"]}]}\n'
      'chords 是按时间顺序的完整和弦序列；segments 按音乐段落切分。'
      '不确定的项用 null。';

  QwenOmniTranscribeService({
    http.Client? client,
    this.endpointOverride,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 1,
  }) : client = client ?? http.Client();

  @override
  Future<TranscribeResult> transcribe({
    required String filePath,
    required String? apiKey,
  }) async {
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw TranscribeException('未配置 API Key，请到「设置」填写阿里百炼 Key');
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      throw TranscribeException('音频文件不存在');
    }
    final bytes = file.lengthSync();
    if (bytes > maxUploadBytes) {
      throw TranscribeException(
          '音频过大（${(bytes / 1024 / 1024).toStringAsFixed(1)}MB），'
          '请录制或截取 60 秒以内的片段再识别');
    }

    final body = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'input_audio',
              'input_audio': {
                'data': base64Encode(file.readAsBytesSync()),
                'format': 'wav',
              },
            },
          ],
        },
      ],
    });

    final endpoint = Uri.parse(endpointOverride?.toString() ?? defaultEndpoint);
    var lastError = '';
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final resp = await client
            .post(
              endpoint,
              headers: {
                'Authorization': 'Bearer ${apiKey.trim()}',
                'Content-Type': 'application/json',
              },
              body: body,
            )
            .timeout(timeout);

        if (resp.statusCode >= 500) {
          lastError = '云端服务暂时不可用（${resp.statusCode}）';
          continue; // 5xx 重试
        }
        if (resp.statusCode == 401) {
          throw TranscribeException('API Key 无效或已过期，请到「设置」检查');
        }
        if (resp.statusCode != 200) {
          throw TranscribeException('识别请求失败（${resp.statusCode}）');
        }
        return _extractResult(resp.body);
      } on TranscribeException catch (e) {
        if (!e.retryable) rethrow; // 业务错误不重试
        lastError = e.message; // 模型输出不合法 → 再试一次
      } on TimeoutException {
        lastError = '识别超时，请稍后重试';
      } on http.ClientException catch (e) {
        lastError = '网络不可用：${e.message}';
      } on SocketException {
        lastError = '网络不可用，请检查网络连接';
      }
    }
    throw TranscribeException(lastError);
  }

  /// OpenAI 兼容响应 → content 文本 → [TranscribeResultParser]。
  TranscribeResult _extractResult(String respBody) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(respBody) as Map<String, dynamic>;
    } on FormatException {
      throw TranscribeException('云端返回格式异常');
    }
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw TranscribeException('云端未返回识别结果');
    }
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw TranscribeException('云端未返回识别结果');
    }
    return TranscribeResultParser.parse(content);
  }
}
