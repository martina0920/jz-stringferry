import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/audio/local_audio_player.dart';
import '../../core/db/app_database.dart';
import '../../core/models/transcribe_models.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theory/key_harmony.dart';
import '../../data/settings_repository.dart';
import '../../data/transcribe_song_repository.dart';
import '../../data/transcribe_service.dart';
import '../arranger/state/arranger_store.dart';
import 'state/cover_store.dart';
import 'widgets/segment_list.dart';

/// 扒带详情页：慢放 / AB 循环 / 分段笔记 / 云端识别 / 发编曲台。
///
/// 播放器由构造注入（测试传 Fake）；路由进入时带 songId（extra）。
class SongDetailPage extends StatefulWidget {
  const SongDetailPage({super.key, this.songId, this.player});

  final String? songId;
  final LocalAudioPlayer? player;

  @override
  State<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends State<SongDetailPage> {
  late final LocalAudioPlayer _player;
  late final AbLoopController _ab;
  late final TranscribeSongRepository _repo;

  TranscribeSong? _song;
  List<TranscribeSegment> _segments = [];

  bool _ready = false;
  bool _playing = false;
  int _durationMs = 0;
  int _positionMs = 0;
  double _speed = 1.0;
  bool _aiBusy = false;

  StreamSubscription<int>? _posSub;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  void initState() {
    super.initState();
    _player = widget.player ?? JustAudioLocalPlayer();
    _ab = AbLoopController(_player);
    _repo = TranscribeSongRepository(AppDatabase.instance.database);
    _init();
  }

  Future<void> _init() async {
    final songId = widget.songId;
    if (songId == null) return;
    final song = await _repo.byId(songId);
    if (song == null || !mounted) return;
    setState(() => _song = song);

    final duration = await _player.setFilePath(song.filePath);
    if (!mounted) return;
    setState(() {
      _durationMs = duration > 0 ? duration : song.durationMs;
      _ready = true;
    });
    // 首次探测到真实时长则回填曲库。
    if (duration > 0 && duration != song.durationMs) {
      final updated = await _repo.update(song.copyWith(durationMs: duration));
      if (mounted) setState(() => _song = updated);
    }
    _posSub = _player.positionStream().listen((ms) {
      if (mounted) setState(() => _positionMs = ms);
    });
    _ab.start();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ab.dispose();
    _player.disposePlayer();
    super.dispose();
  }

  // ---------- 播放控制 ----------

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.play();
      setState(() => _playing = true);
    }
  }

  Future<void> _setSpeed(double s) async {
    setState(() => _speed = s);
    await _player.setSpeed(s);
  }

  Future<void> _seekTo(int ms) async {
    await _player.seekMs(ms.clamp(0, _durationMs == 0 ? ms : _durationMs));
    setState(() => _positionMs = ms.clamp(0, _durationMs));
  }

  // ---------- AB 循环 ----------

  void _setA() {
    _ab.setLoop(aMs: _positionMs, bMs: _ab.bMs);
    setState(() {});
  }

  void _setB() {
    _ab.setLoop(aMs: _ab.aMs, bMs: _positionMs);
    setState(() {});
  }

  void _clearAb() {
    _ab.setLoop();
    setState(() {});
  }

  void _playSegment(TranscribeSegment seg) {
    _ab.setLoop(aMs: seg.startMs, bMs: seg.endMs);
    unawaited(_seekTo(seg.startMs));
    unawaited(_player.play());
    setState(() => _playing = true);
  }

  // ---------- 分段 ----------

  Future<void> _addSegment() async {
    final start = _positionMs;
    final end = (_durationMs > 0) ? (start + 30000).clamp(start, _durationMs) : start + 30000;
    await _editSegmentDialog(null, initialStart: start, initialEnd: end);
  }

  Future<void> _editSegment(TranscribeSegment seg) =>
      _editSegmentDialog(seg, initialStart: seg.startMs, initialEnd: seg.endMs);

  /// 新建（seg=null）与编辑共用的弹窗：标签 / 和弦 / 起止时间。
  Future<void> _editSegmentDialog(
    TranscribeSegment? seg, {
    required int initialStart,
    required int initialEnd,
  }) async {
    final labelCtrl = TextEditingController(text: seg?.label ?? '');
    final chordsCtrl = TextEditingController(text: seg?.chordsText ?? '');
    final startCtrl = TextEditingController(text: formatMs(initialStart));
    final endCtrl = TextEditingController(text: formatMs(initialEnd));
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(seg == null ? '新建分段' : '编辑分段'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('seg_label_field'),
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                      hintText: '段名（如：主歌 / 副歌）'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('seg_chords_field'),
                  controller: chordsCtrl,
                  decoration: const InputDecoration(
                      hintText: '和弦，空格分隔（如 C Am F G）'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('seg_start_field'),
                        controller: startCtrl,
                        decoration: const InputDecoration(labelText: '起点 m:ss.s'),
                        validator: (v) =>
                            parseClock(v ?? '') == null ? '格式 m:ss.s' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        key: const Key('seg_end_field'),
                        controller: endCtrl,
                        decoration: const InputDecoration(labelText: '终点 m:ss.s'),
                        validator: (v) =>
                            parseClock(v ?? '') == null ? '格式 m:ss.s' : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('seg_save'),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;

    final start = parseClock(startCtrl.text) ?? initialStart;
    final end = parseClock(endCtrl.text) ?? initialEnd;
    if (end <= start) {
      _toast('终点必须晚于起点');
      return;
    }
    if (seg == null) {
      await _repo.insertSegment(TranscribeSegment(
        songId: widget.songId!,
        startMs: start,
        endMs: end,
        label: labelCtrl.text.trim(),
        chordsText: chordsCtrl.text.trim(),
        sortKey: 0,
      ));
    } else {
      await _repo.updateSegment(seg.copyWith(
        startMs: start,
        endMs: end,
        label: labelCtrl.text.trim(),
        chordsText: chordsCtrl.text.trim(),
      ));
    }
    await _reloadSegments();
  }

  Future<void> _deleteSegment(TranscribeSegment seg) async {
    final id = seg.id;
    if (id == null) return;
    await _repo.deleteSegment(id);
    await _reloadSegments();
  }

  Future<void> _reloadSegments() async {
    final list = await _repo.segmentsOf(widget.songId!);
    if (mounted) setState(() => _segments = list);
  }

  // ---------- 云端识别 ----------

  Future<void> _aiRecognize() async {
    if (_aiBusy || _song == null) return;
    // 先取齐依赖，避免 async gap 后使用 BuildContext。
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<SettingsRepository?>();
    final service = context.read<TranscribeService?>();
    final song = _song!;

    final apiKey = await settings?.get(SettingsRepository.dashscopeApiKey);
    if (mounted) setState(() => _aiBusy = true);
    try {
      if (apiKey == null || apiKey.trim().isEmpty) {
        messenger.showSnackBar(const SnackBar(
            content: Text('请先到「设置 → 云端识别」填写阿里百炼 API Key')));
        return;
      }
      if (service == null) {
        messenger.showSnackBar(
            const SnackBar(content: Text('云端识别服务不可用')));
        return;
      }
      final confirmed = await _confirmDialog(
        'AI 识别调性与和弦',
        '将把当前音频上传到阿里百炼（Qwen-Omni）识别调性、速度与和弦，'
            '识别结果会覆盖现有分段。确定继续？',
        confirmText: '开始识别',
      );
      if (confirmed != true || !mounted) return;

      // loading 弹窗只展示、不参与取值；完成后手动关闭。
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _BusyDialog(label: '识别中，约需数秒…'),
      ));
      final r =
          await service.transcribe(filePath: song.filePath, apiKey: apiKey.trim());
      if (!mounted) return;
      Navigator.of(context).pop(); // 关掉 loading

      final apply = await _previewResult(r);
      if (apply != true || !mounted) return;
      await _applyResult(r);
      messenger.showSnackBar(const SnackBar(content: Text('识别结果已应用')));
    } on TranscribeException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('识别失败：$e')));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<bool?> _confirmDialog(String title, String body,
      {String confirmText = '确定'}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmText)),
        ],
      ),
    );
  }

  Future<bool?> _previewResult(TranscribeResult r) {
    final keyText = r.keyRootPc == null
        ? '未识别'
        : '${MusicKey(r.keyRootPc!, r.keyMode == 'minor' ? KeyMode.minor : KeyMode.major)}'
            '${r.bpm == null ? '' : ' · ${r.bpm} BPM'}';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('识别结果'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('调性：$keyText'),
              const SizedBox(height: 8),
              Text(
                r.chords.isEmpty ? '（未识别到和弦）' : r.chords.join('  '),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5),
              ),
              if (r.segments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('将写入 ${r.segments.length} 个分段',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkSoft)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('不应用')),
          FilledButton(
              key: const Key('ai_apply'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('应用到本曲')),
        ],
      ),
    );
  }

  /// 应用识别结果：清旧分段 → 写新分段 → 回填调性/速度。
  Future<void> _applyResult(TranscribeResult r) async {
    for (final seg in _segments) {
      final id = seg.id;
      if (id != null) await _repo.deleteSegment(id);
    }
    for (var i = 0; i < r.segments.length; i++) {
      final s = r.segments[i];
      await _repo.insertSegment(TranscribeSegment(
        songId: widget.songId!,
        startMs: s.startMs,
        endMs: s.endMs,
        label: s.label,
        chordsText: s.chords.join(' '),
        sortKey: i,
      ));
    }
    final song = _song!;
    final updated = await _repo.update(song.copyWith(
      bpm: r.bpm,
      keyRootPc: r.keyRootPc,
      keyMode: r.keyMode,
    ));
    if (!mounted) return;
    setState(() => _song = updated);
    await _reloadSegments();
  }

  // ---------- 发编曲台 ----------

  Future<void> _sendToArranger() async {
    final messenger = ScaffoldMessenger.of(context);
    final store = context.read<ArrangerStore?>();
    final song = _song;
    if (store == null || song == null) return;

    final chords = [
      for (final seg in _segments)
        ...seg.chordsText.trim().split(RegExp(r'\s+')).where((c) => c.isNotEmpty),
    ];
    if (chords.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('先在分段里记一些和弦，再发送到编曲台')));
      return;
    }
    final key = MusicKey(
      song.keyRootPc ?? 0,
      song.keyMode == 'minor' ? KeyMode.minor : KeyMode.major,
    );
    await store.createFromChords(
        title: song.title, key: key, chords: chords);
    if (mounted) await context.push(AppRouter.arrangerEdit);
  }

  // ---------- build ----------

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    return Scaffold(
      appBar: AppBar(title: Text(song?.title ?? '扒带详情')),
      body: !_ready
          ? Center(
              child: Text(
                song == null ? '歌曲不存在' : '加载中…',
                style: const TextStyle(color: AppColors.inkSoft),
              ),
            )
          : _buildBody(song!),
    );
  }

  Widget _buildBody(TranscribeSong song) {
    final store = context.read<CoverStore?>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // 播放控制卡。
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton.filled(
                      key: const Key('detail_play'),
                      onPressed: _togglePlay,
                      icon: Icon(_playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        key: const Key('detail_seek'),
                        min: 0,
                        max: (_durationMs > 0 ? _durationMs : 1).toDouble(),
                        value: _positionMs
                            .clamp(0, _durationMs > 0 ? _durationMs : 1)
                            .toDouble(),
                        onChanged: (v) => _seekTo(v.round()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatMs(_positionMs)} / ${formatMs(_durationMs)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.inkSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 变速不变调。
                Row(
                  children: [
                    const Text('速度',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.inkSoft)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: [
                          for (final s in _speeds)
                            ChoiceChip(
                              key: Key('detail_speed_$s'),
                              label: Text('${s}x'),
                              selected: _speed == s,
                              onSelected: (_) => _setSpeed(s),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                // AB 循环。
                Row(
                  children: [
                    OutlinedButton(
                        key: const Key('detail_set_a'),
                        onPressed: _setA,
                        child: Text(_ab.aMs == null
                            ? '设 A 点'
                            : 'A ${formatMs(_ab.aMs!)}')),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        key: const Key('detail_set_b'),
                        onPressed: _setB,
                        child: Text(_ab.bMs == null
                            ? '设 B 点'
                            : 'B ${formatMs(_ab.bMs!)}')),
                    const Spacer(),
                    if (_ab.aMs != null || _ab.bMs != null)
                      TextButton(
                          key: const Key('detail_ab_clear'),
                          onPressed: _clearAb,
                          child: const Text('清除')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 分段卡。
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('分段笔记',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    OutlinedButton.icon(
                      key: const Key('seg_add'),
                      onPressed: _addSegment,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('在此刻新建'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_segments.isEmpty)
                  const Text(
                    '还没有分段。播放到想记的位置，点「在此刻新建」；'
                    '按 C Am F G 的格式记下每段和弦。',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.inkSoft, height: 1.6),
                  )
                else
                  SegmentList(
                    segments: _segments,
                    onPlay: _playSegment,
                    onEdit: _editSegment,
                    onDelete: _deleteSegment,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 识别与导出。
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('detail_ai'),
                onPressed: _aiBusy ? null : _aiRecognize,
                icon: _aiBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded),
                label: const Text('AI 识别'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('detail_to_arranger'),
                onPressed: _sendToArranger,
                icon: const Icon(Icons.library_music_rounded),
                label: const Text('发编曲台'),
              ),
            ),
          ],
        ),
        if (store?.error != null) ...[
          const SizedBox(height: 8),
          Text(store!.error!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
        ],
        if (song.bpm != null || song.keyRootPc != null) ...[
          const SizedBox(height: 12),
          Text(
            '已记：'
            '${song.keyRootPc == null ? '' : '调性 ${_keyLabel(song)} · '}'
            '${song.bpm == null ? '' : '${song.bpm} BPM'}',
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      ],
    );
  }

  String _keyLabel(TranscribeSong song) {
    const names = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    ];
    final root = names[song.keyRootPc! % 12];
    return song.keyMode == 'minor' ? '$root 小调' : '$root 大调';
  }
}

/// 全屏 loading 弹窗（识别进行中）。
class _BusyDialog extends StatelessWidget {
  const _BusyDialog({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Flexible(child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}
