import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/chat_service.dart';
import '../../data/study_analytics.dart';
import '../arranger/state/arranger_store.dart';
import '../study/state/study_plan_store.dart';

/// 模块三：AI 助手（v0.2 为离线本地规则服务，无网络请求）。
class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  static const _suggestions = [
    'Am7 和弦的组成音是什么？',
    '推荐一个 C 调的常用和弦进行',
    '1564 进行是什么？',
    '分析我的学习进度',
  ];

  final List<_Message> _messages = [
    const _Message(
        text: '你好，我是弦渡助手。可以问我和弦组成音、常用和弦进行，也可以帮你汇总学习进度。', isUser: false),
  ];
  bool _thinking = false;

  StudySnapshot? _studySnapshot() {
    final store = context.read<StudyPlanStore?>();
    if (store == null || !store.loaded || store.tasks.isEmpty) return null;
    return StudySnapshot.fromReport(StudyAnalytics.build(
      plans: store.plans,
      tasks: store.tasks,
      checkins: store.checkinSnapshot,
    ));
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _thinking) return;

    setState(() {
      _messages.add(_Message(text: trimmed, isUser: true));
      _thinking = true;
    });

    final ChatService service =
        context.read<ChatService?>() ?? LocalChatService();
    final reply = await service.ask(trimmed, study: _studySnapshot());
    final draft = service.suggestProgression(trimmed);

    if (!mounted) return;
    setState(() {
      _messages
          .add(_Message(text: reply, isUser: false, draft: draft));
      _thinking = false;
    });
  }

  /// 把 AI 识别出的进行一键送到编曲台并进入编辑器（FR-21）。
  Future<void> _sendToArranger(ProgressionDraft draft) async {
    final store = context.read<ArrangerStore?>();
    if (store == null) return;
    await store.createFromChords(
      title: draft.title,
      key: draft.key,
      chords: draft.chords,
    );
    if (mounted) await context.push(AppRouter.arrangerEdit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Center(
              child: Text('离线本地模式',
                  style: TextStyle(fontSize: 12, color: AppColors.gold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length + (_thinking ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: _TypingBubble(),
                    );
                  }
                  final m = _messages[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bubble(message: m),
                      if (!m.isUser && m.draft != null)
                        _SendToArrangerButton(
                          draft: m.draft!,
                          onPressed: () => _sendToArranger(m.draft!),
                        ),
                      if (i == _messages.length - 1 &&
                          !_thinking &&
                          _messages.length == 1) ...[
                        const SizedBox(height: 20),
                        const Text('试试这些：',
                            style: TextStyle(
                                color: AppColors.inkSoft, fontSize: 13)),
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
                  );
                },
              ),
            ),
            _InputBar(onSend: _send, enabled: !_thinking),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.mist,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
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
        child: Text(text,
            style: const TextStyle(fontSize: 13, color: AppColors.ink)),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({required this.onSend, required this.enabled});

  final ValueChanged<String> onSend;
  final bool enabled;

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
    if (text.isEmpty || !widget.enabled) return;
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
                enabled: widget.enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: '问点什么…',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: widget.enabled ? _submit : null,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message {
  const _Message({required this.text, required this.isUser, this.draft});

  final String text;
  final bool isUser;
  final ProgressionDraft? draft;
}

/// 进行类回答下方的「发送到编曲台」按钮（FR-21）。
class _SendToArrangerButton extends StatelessWidget {
  final ProgressionDraft draft;
  final VoidCallback onPressed;

  const _SendToArrangerButton({required this.draft, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        key: const Key('send_to_arranger'),
        onPressed: onPressed,
        icon: const Icon(Icons.send_to_mobile_rounded, size: 17),
        label: Text('发送到编曲台（${draft.chords.join(' · ')}）'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.gold),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
