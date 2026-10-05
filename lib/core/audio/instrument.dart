/// 乐器音色：一套单音采样（assets/audio/{assetDir}/$midi.wav）。
///
/// v0.4 内置尼龙吉他/钢琴/EP/电吉他/贝斯；新增乐器只需补齐采样目录
/// 并在 [melodicInstruments] 注册一行，无需改动任何播放逻辑。
class Instrument {
  final String id;

  /// UI 展示名。
  final String label;

  /// 采样最低/最高 MIDI（闭区间）。
  final int lowMidi;
  final int highMidi;

  /// assets/audio/ 下的采样目录名。
  final String assetDir;

  const Instrument({
    required this.id,
    required this.label,
    required this.lowMidi,
    required this.highMidi,
    required this.assetDir,
  });

  /// 采样数（lowMidi..highMidi 闭区间）。
  int get sampleCount => highMidi - lowMidi + 1;
}

const Instrument guitarInstrument = Instrument(
  id: 'guitar',
  label: '尼龙吉他',
  lowMidi: 40,
  highMidi: 76,
  assetDir: 'guitar',
);

const Instrument pianoInstrument = Instrument(
  id: 'piano',
  label: '钢琴',
  lowMidi: 48,
  highMidi: 84,
  assetDir: 'piano',
);

// Caveman Cosmonaut EP 实际采样覆盖 43–83，这里取 C3–B5。
const Instrument epInstrument = Instrument(
  id: 'ep',
  label: '电钢',
  lowMidi: 48,
  highMidi: 83,
  assetDir: 'ep',
);

const Instrument eGuitarInstrument = Instrument(
  id: 'eguitar',
  label: '电吉他',
  lowMidi: 40,
  highMidi: 76,
  assetDir: 'eguitar',
);

// Big Little Bass 实际采样覆盖 35–78，这里取 B1–E4（宽 30 半音，
// 可容纳 voiceGuitarStrings 的 5 音上行跨度）。
const Instrument bassInstrument = Instrument(
  id: 'bass',
  label: '贝斯',
  lowMidi: 35,
  highMidi: 64,
  assetDir: 'bass',
);

/// 旋律乐器注册表（顺序即 UI 展示顺序）。
const List<Instrument> melodicInstruments = [
  guitarInstrument,
  pianoInstrument,
  epInstrument,
  eGuitarInstrument,
  bassInstrument,
];

/// 按 id 取乐器；未知 id 回落尼龙吉他（脏数据兜底）。
Instrument instrumentById(String id) => melodicInstruments
    .firstWhere((i) => i.id == id, orElse: () => guitarInstrument);

/// 节拍器鼓组采样（独立于乐器注册表，无音高语义）。
const String drumKickAsset = 'assets/audio/drums/kick.wav';
const String drumSnareAsset = 'assets/audio/drums/snare.wav';
const String drumHatAsset = 'assets/audio/drums/hat.wav';
