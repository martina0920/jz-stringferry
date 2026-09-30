import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 模块三：AI 助手
///
/// 首版骨架：对话式聊天界面。
/// 后续接入大模型 API（已确认：接现成大模型 API，按量付费）。
class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  static const _suggestions = [
    '推荐一个 C 调的常用和弦进行',
    '分析我的学习进度',
    '这个和弦进行怎么配节奏型？',
    '帮我做扒带练习计划',
  ];

  final List<_Message> _messages = [
    const _Message(
      text: '你好，我是弦渡 AI 助手。可以问我乐理、和弦、编曲问题，也可以帮你安排学习计划。',
      isUser: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (final m in _messages) _Bubble(message: m),
                  if (_messages.length == 1) ...[
                    const SizedBox(height: 24),
                    const Text('试试这些：', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                    const SizedBox(height: 10),
                    for (final s in _suggestions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SuggestionChip(
                          text: s,
                          onTap: () => _send(s),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            _InputBar(onSend: _send),
          ],
        ),
      ),
    );
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _messages.add(const _Message(text: '（AI 接入后，这里会给出回答）', isUser: false));
    });
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? AppColors.ink : AppColors.mist,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isUser ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.ink)),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({required this.onSend});

  final ValueChanged<String> onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: '问点什么…',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message {
  const _Message({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}
