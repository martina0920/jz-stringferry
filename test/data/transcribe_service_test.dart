import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jz_stringferry/data/qwen_omni_transcribe_service.dart';
import 'package:jz_stringferry/data/transcribe_service.dart';

void main() {
  group('TranscribeResultParser（容错解析纯函数）', () {
    test('标准 JSON 直接解析', () {
      final r = TranscribeResultParser.parse(
          '{"key_root_pc":0,"key_mode":"major","bpm":96,'
          '"chords":["C","Am","F","G"],'
          '"segments":[{"start_ms":0,"end_ms":15000,"label":"主歌",'
          '"chords":["C","Am"]}]}');
      expect(r.keyRootPc, 0);
      expect(r.keyMode, 'major');
      expect(r.bpm, 96);
      expect(r.chords, ['C', 'Am', 'F', 'G']);
      expect(r.segments.length, 1);
      expect(r.segments.first.label, '主歌');
    });

    test('剥 ```json 围栏与前后杂文', () {
      final r = TranscribeResultParser.parse('好的，分析如下：\n'
          '```json\n{"key_root_pc":9,"key_mode":"minor","bpm":72,\n'
          '"chords":["Am","F","C","G"]}\n```\n希望有帮助。');
      expect(r.keyRootPc, 9);
      expect(r.keyMode, 'minor');
      expect(r.chords, ['Am', 'F', 'C', 'G']);
      expect(r.segments, isEmpty);
    });

    test('无围栏但夹杂说明文字时提取首个配平对象（含字符串内花括号）', () {
      final r = TranscribeResultParser.parse(
          '结果 {"key_root_pc":2,"bpm":100,"note":"段落{A}","chords":["D"]} 完毕');
      expect(r.keyRootPc, 2);
      expect(r.chords, ['D']);
    });

    test('调性字符串形态："C 大调" / "Am" / "Bb"', () {
      final r1 = TranscribeResultParser.parse(
          '{"key":"C 大调","chords":[]}');
      expect(r1.keyRootPc, 0);
      expect(r1.keyMode, 'major');

      final r2 = TranscribeResultParser.parse('{"key":"Am","chords":[]}');
      expect(r2.keyRootPc, 9);
      expect(r2.keyMode, 'minor');

      final r3 = TranscribeResultParser.parse('{"key":"Bb","chords":[]}');
      expect(r3.keyRootPc, 10);
    });

    test('bpm 字符串带杂讯也能取到数字', () {
      final r = TranscribeResultParser.parse(
          '{"bpm":"约 96 BPM","key_root_pc":0,"chords":[]}');
      expect(r.bpm, 96);
    });

    test('非法和弦名被丢弃，合法项保留', () {
      final r = TranscribeResultParser.parse(
          '{"key_root_pc":0,"chords":["C"," xyz ","Am7","123","Fsus4","C/B","F#m"]}');
      expect(r.chords, ['C', 'Am7', 'Fsus4', 'C/B', 'F#m']);
    });

    test('分段缺 end/end<=start 被跳过', () {
      final r = TranscribeResultParser.parse(
          '{"segments":[{"start_ms":0,"end_ms":1000},{"start_ms":2000},'
          '{"start_ms":3000,"end_ms":2000}]}');
      expect(r.segments.length, 1);
    });

    test('完全无法解析时抛 TranscribeException', () {
      expect(() => TranscribeResultParser.parse('我不会识别和弦'),
          throwsA(isA<TranscribeException>()));
      expect(() => TranscribeResultParser.parse('{"截断的 json'),
          throwsA(isA<TranscribeException>()));
    });

    test('全字段缺失时返回空结果不抛', () {
      final r = TranscribeResultParser.parse('{}');
      expect(r.keyRootPc, isNull);
      expect(r.bpm, isNull);
      expect(r.chords, isEmpty);
      expect(r.segments, isEmpty);
    });
  });

  group('QwenOmniTranscribeService', () {
    late Directory tmp;
    late File wav;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('jz_qwen_');
      wav = File('${tmp.path}\\clip.wav')
        ..writeAsBytesSync(List.filled(64, 1));
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    QwenOmniTranscribeService serviceWith(MockClient client,
            {Uri? endpoint}) =>
        QwenOmniTranscribeService(client: client, endpointOverride: endpoint);

    test('请求体：qwen 模型 + input_audio base64 + Bearer key', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      String? capturedBody;
      final svc = serviceWith(MockClient((req) async {
        capturedUri = req.url;
        capturedHeaders = req.headers;
        capturedBody = req.body;
        return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content':
                        '{"key_root_pc":0,"key_mode":"major","bpm":90,'
                        '"chords":["C","Am","F","G"]}'
                  }
                }
              ]
            }),
            200);
      }));

      final r = await svc.transcribe(filePath: wav.path, apiKey: 'sk-test');
      expect(r.chords, ['C', 'Am', 'F', 'G']);
      expect(capturedUri!.host, 'dashscope.aliyuncs.com');
      expect(capturedUri!.path, endsWith('/chat/completions'));
      expect(capturedHeaders!['Authorization'], 'Bearer sk-test');
      final body = jsonDecode(capturedBody!) as Map;
      expect(body['model'], 'qwen3.8-omni-flash');
      final content = (body['messages'] as List).first['content'] as List;
      expect(
          content.any((c) => c is Map && c['type'] == 'input_audio'), isTrue);
      final audio = content
          .firstWhere((c) => c is Map && c['type'] == 'input_audio')
          as Map;
      expect(audio['input_audio']['data'],
          base64Encode(wav.readAsBytesSync()));
    });

    test('无 key → 明确提示；文件缺失 → 提示', () async {
      final svc = serviceWith(
          MockClient((req) async => http.Response('{}', 200)));
      expect(
        () => svc.transcribe(filePath: wav.path, apiKey: '  '),
        throwsA(isA<TranscribeException>()
            .having((e) => e.message, 'message', contains('API Key'))),
      );
      expect(
        () => svc.transcribe(
            filePath: '${tmp.path}\\nope.wav', apiKey: 'sk'),
        throwsA(isA<TranscribeException>()
            .having((e) => e.message, 'message', contains('不存在'))),
      );
    });

    test('音频超 8MB → 引导录短片段，不发请求', () async {
      var called = false;
      final big = File('${tmp.path}\\big.wav')
        ..writeAsBytesSync(List.filled(9 * 1024 * 1024, 0));
      final svc = serviceWith(MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      }));
      await expectLater(
        svc.transcribe(filePath: big.path, apiKey: 'sk'),
        throwsA(isA<TranscribeException>()
            .having((e) => e.message, 'message', contains('过大'))),
      );
      expect(called, isFalse);
    });

    test('401 → key 无效提示（不重试）', () async {
      var calls = 0;
      final svc = serviceWith(MockClient((req) async {
        calls++;
        return http.Response('{"error":"auth"}', 401);
      }));
      await expectLater(
        svc.transcribe(filePath: wav.path, apiKey: 'sk-bad'),
        throwsA(isA<TranscribeException>()
            .having((e) => e.message, 'message', contains('无效'))),
      );
      expect(calls, 1);
    });

    test('5xx 重试一次后成功', () async {
      var calls = 0;
      final svc = serviceWith(MockClient((req) async {
        calls++;
        if (calls == 1) return http.Response('busy', 503);
        return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': '{"key_root_pc":5,"chords":["F"]}'
                  }
                }
              ]
            }),
            200);
      }));
      final r = await svc.transcribe(filePath: wav.path, apiKey: 'sk');
      expect(calls, 2);
      expect(r.keyRootPc, 5);
    });

    test('连续网络异常 → 重试后抛「网络不可用」', () async {
      var calls = 0;
      final svc = serviceWith(MockClient((req) async {
        calls++;
        throw http.ClientException('boom');
      }));
      await expectLater(
        svc.transcribe(filePath: wav.path, apiKey: 'sk'),
        throwsA(isA<TranscribeException>()
            .having((e) => e.message, 'message', contains('网络'))),
      );
      expect(calls, 2); // 初次 + 1 重试
    });

    test('返回无法解析的内容 → 重试一次后抛解析失败', () async {
      var calls = 0;
      final svc = serviceWith(MockClient((req) async {
        calls++;
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'choices': [
                {
                  'message': {'content': '抱歉我听不出来'}
                }
              ]
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      await expectLater(
        svc.transcribe(filePath: wav.path, apiKey: 'sk'),
        throwsA(isA<TranscribeException>()),
      );
      expect(calls, 2);
    });
  });
}
