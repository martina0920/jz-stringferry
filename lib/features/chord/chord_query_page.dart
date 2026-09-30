import 'package:flutter/material.dart';

import '../../data/chord_repository.dart';
import '../../core/models/chord.dart';
import '../../core/theme/app_theme.dart';

/// 模块一：和弦查询
///
/// 一键查询和弦名称、组成音、音程构成与吉他指法。
class ChordQueryPage extends StatefulWidget {
  const ChordQueryPage({super.key});

  @override
  State<ChordQueryPage> createState() => _ChordQueryPageState();
}

class _ChordQueryPageState extends State<ChordQueryPage> {
  String _keyword = '';
  Chord? _selected;

  @override
  Widget build(BuildContext context) {
    final results = ChordRepository.search(_keyword);
    return Scaffold(
      appBar: AppBar(title: const Text('和弦查询')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextField(
              autofocus: false,
              decoration: const InputDecoration(
                hintText: '输入和弦名，如 C、Am7、F#m7b5',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _keyword = v),
            ),
            const SizedBox(height: 16),
            if (_selected != null) _ChordDetailCard(chord: _selected!),
            const SizedBox(height: 16),
            Text(
              _keyword.isEmpty ? '常用和弦' : '搜索结果（${results.length}）',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 8),
            ...results.map((c) => _ChordTile(
                  chord: c,
                  onTap: () => setState(() => _selected = c),
                )),
          ],
        ),
      ),
    );
  }
}

class _ChordTile extends StatelessWidget {
  const _ChordTile({required this.chord, required this.onTap});

  final Chord chord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(chord.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(chord.tones.join(' · ')),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
        onTap: onTap,
      ),
    );
  }
}

class _ChordDetailCard extends StatelessWidget {
  const _ChordDetailCard({required this.chord});

  final Chord chord;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    chord.name,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('组成音：${chord.tones.join('  ')}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('音程：${chord.intervals}',
                          style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('指法（低音弦 → 高音弦）',
                style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            _FingeringRow(fingering: chord.fingering),
          ],
        ),
      ),
    );
  }
}

class _FingeringRow extends StatelessWidget {
  const _FingeringRow({required this.fingering});

  final String fingering;

  @override
  Widget build(BuildContext context) {
    final parts = fingering.split('');
    return Row(
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.mist,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              parts[i].toUpperCase(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
        ],
      ],
    );
  }
}
