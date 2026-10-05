import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/guitar_audio_service.dart';
import '../../core/audio/just_audio_tone_player.dart';
import '../../core/models/chord_spec.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theory/note.dart';
import 'state/chord_collection_store.dart';
import 'widgets/chord_audition_buttons.dart';
import 'widgets/fretboard_diagram.dart';

/// 和弦详情：组成音、音程构成、多指法切换、试听。
class ChordDetailPage extends StatefulWidget {
  final ChordSpec chord;

  const ChordDetailPage({super.key, required this.chord});

  @override
  State<ChordDetailPage> createState() => _ChordDetailPageState();
}

class _ChordDetailPageState extends State<ChordDetailPage> {
  final _pageController = PageController(viewportFraction: 0.78);
  final _audio = GuitarAudioService(JustAudioTonePlayer());
  int _index = 0;

  @override
  void dispose() {
    unawaited(_audio.stop());
    _pageController.dispose();
    super.dispose();
  }

  void _play(PlayMode mode) {
    final c = widget.chord;
    final midis = GuitarAudioService.voiceChord(
      rootPc: c.rootPc,
      pitchClasses: c.tones.map(Note.pitchClassOf).toList(),
    );
    _audio.playChord(midis, mode: mode);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chord;
    final fingers = c.fingerings;
    final store = context.watch<ChordCollectionStore?>();
    final chordId = c.id;
    final favorite =
        store != null && chordId != null && store.isFavorite(chordId);

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          if (store != null && chordId != null)
            IconButton(
              tooltip: favorite ? '取消收藏' : '收藏',
              icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded),
              color: favorite ? AppColors.gold : AppColors.ink,
              onPressed: () => store.toggleFavorite(chordId),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            // 名称 + 家族标签
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(c.name,
                    style: const TextStyle(
                        fontSize: 34, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(c.family,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 组成音
            const _SectionLabel('组成音'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in c.tones)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(t,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // 音程构成
            const _SectionLabel('音程构成'),
            const SizedBox(height: 6),
            Text(c.intervalText,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.ink, height: 1.5)),
            const SizedBox(height: 20),

            // 指法图
            const _SectionLabel('指法（6 弦 → 1 弦）'),
            const SizedBox(height: 8),
            if (fingers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child:
                      Text('暂无指法图', style: TextStyle(color: AppColors.inkSoft)),
                ),
              )
            else ...[
              SizedBox(
                height: 286,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: fingers.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FretboardDiagram(fingering: fingers[i]),
                          const SizedBox(height: 4),
                          Text(fingers[i].tabString,
                              style: const TextStyle(
                                  fontSize: 14,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkSoft)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (fingers.length > 1) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < fingers.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color:
                              i == _index ? AppColors.gold : AppColors.hairline,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('${_index + 1} / ${fingers.length} 种按法',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft)),
                ),
              ],
            ],
            const SizedBox(height: 24),

            // 试听
            const _SectionLabel('试听'),
            const SizedBox(height: 8),
            ChordAuditionButtons(
              onPlay: _play,
              onStop: () => unawaited(_audio.stop()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
          letterSpacing: 1,
        ));
  }
}
