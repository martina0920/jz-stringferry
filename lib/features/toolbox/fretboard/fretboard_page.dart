import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theory/fretboard_quiz.dart';

/// 指板学习页：随机「某弦某品」出题，回答音名；答错给正解。
class FretboardPage extends StatefulWidget {
  const FretboardPage({super.key});

  @override
  State<FretboardPage> createState() => _FretboardPageState();
}

class _FretboardPageState extends State<FretboardPage> {
  final FretboardQuiz _quiz = FretboardQuiz();
  final TextEditingController _input = TextEditingController();

  FretboardQuestion? _question;
  bool? _lastCorrect;
  int correct = 0;
  int total = 0;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _next() {
    setState(() {
      _question = _quiz.next();
      _lastCorrect = null;
      _input.clear();
    });
  }

  void _submit() {
    final q = _question;
    if (q == null || _lastCorrect != null) return;
    final ok = judgeFretAnswer(q, _input.text);
    setState(() {
      _lastCorrect = ok;
      total++;
      if (ok) correct++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    return Scaffold(
      appBar: AppBar(title: const Text('指板学习')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Text('本轮 $correct/$total',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.inkSoft)),
                const Spacer(),
                if (_lastCorrect != null)
                  Text(
                    _lastCorrect! ? '答对了！' : '不对哦',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          _lastCorrect! ? AppColors.gold : AppColors.danger,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.tonal(
                key: const Key('fret_next'),
                onPressed: _next,
                child: Text(q == null ? '开始出题' : '下一题'),
              ),
            ),
            const SizedBox(height: 16),
            if (q != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${q.stringNo} 弦 · ${q.fret} 品 的音名是？',
                    key: const Key('fret_question'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('fret_input'),
                controller: _input,
                textAlign: TextAlign.center,
                maxLength: 3,
                enabled: _lastCorrect == null,
                decoration: const InputDecoration(
                    hintText: '如 C / F# / Bb'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              Center(
                child: FilledButton(
                  key: const Key('fret_submit'),
                  onPressed: _lastCorrect == null ? _submit : null,
                  child: const Text('提交'),
                ),
              ),
              if (_lastCorrect == false) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '正确答案：${_answerOf(q)}（同音异名任一即可）',
                    key: const Key('fret_answer'),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _answerOf(FretboardQuestion q) {
    final pc = ((q.midi % 12) + 12) % 12;
    return '${sharpNames[pc]} / ${flatNames[pc]}';
  }
}
