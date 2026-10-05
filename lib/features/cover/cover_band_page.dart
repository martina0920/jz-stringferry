import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/transcribe_models.dart' show TranscribeSong;
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import 'state/cover_store.dart';
import 'widgets/segment_list.dart' show formatMs;

/// 模块五：扒带助手
///
/// 歌曲列表 + 本地导入 / 应用内录音两个入口。
class CoverBandPage extends StatefulWidget {
  const CoverBandPage({super.key});

  @override
  State<CoverBandPage> createState() => _CoverBandPageState();
}

class _CoverBandPageState extends State<CoverBandPage> {
  @override
  void initState() {
    super.initState();
    // 返回详情页后刷新列表（updated_at 排序）。
    context.read<CoverStore>().load();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CoverStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('扒带助手')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _EntryCard(
              key: const Key('cover_import'),
              icon: Icons.library_music_rounded,
              title: '导入本地音频',
              subtitle: store.busy ? '正在导入…' : '从手机里选一首歌开始扒带',
              enabled: !store.busy && !store.recording,
              onTap: _import,
            ),
            const SizedBox(height: 12),
            _EntryCard(
              key: const Key('cover_record'),
              icon: store.recording
                  ? Icons.stop_circle_rounded
                  : Icons.mic_rounded,
              title: store.recording ? '停止录音' : '录制一段音频',
              subtitle: store.recording ? '正在录音，点这里结束' : '用麦克风录下想扒的片段',
              enabled: !store.busy,
              onTap: _toggleRecord,
            ),
            const SizedBox(height: 20),
            if (store.error != null) ...[
              Text(store.error!,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.redAccent)),
              const SizedBox(height: 8),
            ],
            if (store.items.isEmpty) ...[
              const Text(
                '扒带四步：听调性 → 定速度 → 分段落 → 记和弦',
                style: TextStyle(
                    fontSize: 13, color: AppColors.inkSoft, height: 1.6),
              ),
              const SizedBox(height: 8),
              const Text(
                '导入或录制一段音频后，可以慢放、AB 循环、'
                    '按段记和弦，也能一键让 AI 识别调性与和弦，'
                    '最后把和弦发送到编曲台试听。',
                style: TextStyle(
                    fontSize: 13, color: AppColors.inkSoft, height: 1.6),
              ),
            ] else
              ...[
                const Text('我的曲库',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft)),
                const SizedBox(height: 8),
                for (final song in store.items)
                  _SongTile(
                    key: Key('cover_song_${song.id}'),
                    song: song,
                    onTap: () =>
                        context.push(AppRouter.coverSong, extra: song.id),
                    onDelete: () => _delete(song),
                  ),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    final store = context.read<CoverStore>();
    final messenger = ScaffoldMessenger.of(context);
    final id = await store.importAudio();
    if (id != null && mounted) {
      await context.push(AppRouter.coverSong, extra: id);
    } else if (store.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(store.error!)));
    }
  }

  Future<void> _toggleRecord() async {
    final store = context.read<CoverStore>();
    final messenger = ScaffoldMessenger.of(context);
    if (store.recording) {
      final id = await store.stopRecording();
      if (id != null && mounted) {
        await context.push(AppRouter.coverSong, extra: id);
      } else if (store.error != null) {
        messenger.showSnackBar(SnackBar(content: Text(store.error!)));
      }
    } else {
      final ok = await store.startRecording();
      if (!ok) {
        messenger.showSnackBar(
            const SnackBar(content: Text('无法启动录音：请检查麦克风权限')));
      }
    }
  }

  Future<void> _delete(TranscribeSong song) async {
    final store = context.read<CoverStore>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除歌曲'),
        content: Text('将删除「${song.title}」及其全部分段笔记，音频文件也会一并删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) await store.deleteSong(song);
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Icon(icon, color: AppColors.ink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    super.key,
    required this.song,
    required this.onTap,
    required this.onDelete,
  });

  final TranscribeSong song;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = [
      song.source == 'record' ? '录音' : '导入',
      if (song.durationMs > 0) formatMs(song.durationMs),
      if (song.bpm != null) '${song.bpm} BPM',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.music_note_rounded),
        title: Text(song.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(meta,
            style:
                const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          onPressed: onDelete,
          tooltip: '删除',
        ),
        onTap: onTap,
      ),
    );
  }
}
