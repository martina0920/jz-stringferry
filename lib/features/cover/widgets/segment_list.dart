import 'package:flutter/material.dart';

import '../../../core/models/transcribe_models.dart';
import '../../../core/theme/app_theme.dart';

/// 分段笔记列表（纯展示；操作通过回调上抛）。
class SegmentList extends StatelessWidget {
  const SegmentList({
    super.key,
    required this.segments,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TranscribeSegment> segments;
  final void Function(TranscribeSegment seg) onPlay;
  final void Function(TranscribeSegment seg) onEdit;
  final void Function(TranscribeSegment seg) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < segments.length; i++)
          _SegmentTile(
            key: Key('seg_tile_$i'),
            index: i,
            seg: segments[i],
            onPlay: () => onPlay(segments[i]),
            onEdit: () => onEdit(segments[i]),
            onDelete: () => onDelete(segments[i]),
          ),
      ],
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    super.key,
    required this.index,
    required this.seg,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final TranscribeSegment seg;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final chords = seg.chordsText.trim().split(RegExp(r'\s+')).where((c) => c.isNotEmpty).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${index + 1}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold)),
                const SizedBox(width: 8),
                Text(
                  '${formatMs(seg.startMs)} – ${formatMs(seg.endMs)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.inkSoft),
                ),
                if (seg.label.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(seg.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                IconButton(
                  key: Key('seg_play_$index'),
                  visualDensity: VisualDensity.compact,
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  tooltip: '循环播放该段',
                ),
                IconButton(
                  key: Key('seg_edit_$index'),
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  tooltip: '编辑',
                ),
                IconButton(
                  key: Key('seg_del_$index'),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: '删除',
                ),
              ],
            ),
            if (chords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in chords)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.mist,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Text(c,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 毫秒 → m:ss.s 文案。
String formatMs(int ms) {
  final totalSec = ms / 1000.0;
  final m = totalSec ~/ 60;
  final s = totalSec - m * 60;
  return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
}

/// m:ss.s（或纯秒数 83.5）→ 毫秒；解析失败返回 null。
int? parseClock(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final m = RegExp(r'^(\d+):(\d{1,2}(?:\.\d+)?)$').firstMatch(t);
  if (m != null) {
    final minutes = int.parse(m.group(1)!);
    final seconds = double.parse(m.group(2)!);
    return ((minutes * 60 + seconds) * 1000).round();
  }
  final sec = double.tryParse(t);
  if (sec == null) return null;
  return (sec * 1000).round();
}
