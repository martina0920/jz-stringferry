# Karoryfer CC0 采样裁剪：为 v0.4 新乐器生成 assets/audio/<dir>/<midi>.wav
#
# 用法：
#   python tool/crop_karoryfer_samples.py                # 全量裁剪
#   python tool/crop_karoryfer_samples.py --only piano   # 只裁某乐器
#   python tool/crop_karoryfer_samples.py --dry          # 只打印选样方案
#
# 处理链：sfz region 选样（keycenter 精确优先，lokey/hikey 覆盖兜底，
# 取中间 velocity 层）→ 解码(flac/wav) → 单声道 → 22.05kHz 线性重采样
# → 起音点对齐（首个 |x|>0.002 前 5ms）→ 截断 ≤2.2s → 末尾 120ms 淡出
# → 峰值归一 0.7 → 16bit PCM WAV。
#
# 单乐器产物 ≤6MB（guitar_assets_test 强制断言）。

import argparse
import os
import struct
import sys
import wave

import numpy as np
import soundfile as sf

ROOT = r"D:\jz_stringferry"
SRC = os.path.join(ROOT, "build", "samples_src", "extracted")
OUT = os.path.join(ROOT, "assets", "audio")

SR = 22050
MAX_SEC = 2.2
FADE_SEC = 0.12
ONSET_THRESH = 0.002
ONSET_GUARD_MS = 5
PEAK = 0.7


# ---------- sfz 解析 ----------

def parse_sfz(path):
    """返回 region 列表 [{sample, keycenter, lokey, hikey, lovel, hivel}]。

    sample 相对 sfz 所在目录解析；<control> 的 default_path 作为前缀。
    """
    regions = []
    default_path = ""
    base = os.path.dirname(path)
    cur = None
    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.split("//")[0].strip()
            if not line:
                continue
            low = line.lower()
            if low.startswith("<"):
                if cur:
                    regions.append(cur)
                    cur = None
                if low.startswith("<region>"):
                    cur = {"sample": None, "keycenter": None, "lokey": None,
                           "hikey": None, "lovel": 0, "hivel": 127}
                continue
            if cur is None:
                # <control> 等块内的全局 opcodes
                for tok in line.split():
                    k, _, v = tok.partition("=")
                    if k.lower() == "default_path":
                        default_path = v
                continue
            for tok in line.split():
                if "=" not in tok:
                    continue
                k, _, v = tok.partition("=")
                k = k.lower()
                if k == "sample":
                    cur["sample"] = v
                elif k in ("keycenter", "pitch_keycenter"):
                    try:
                        cur["keycenter"] = int(v)
                    except ValueError:
                        pass
                elif k in ("lokey", "hikey", "lovel", "hivel"):
                    try:
                        cur[k] = int(v)
                    except ValueError:
                        pass
    if cur:
        regions.append(cur)
    # 解析绝对路径并丢弃无 sample 的 region。
    # 部分包（Big Little Bass）sfz 在 Programs\maps\ 下却引用 ..\Samples\，
    # 相对解析会落到不存在的 Programs\Samples\，故逐级向上回退查找。
    out = []
    for r in regions:
        if not r["sample"]:
            continue
        rel = default_path + r["sample"]
        r["file"] = resolve_sample(base, rel)
        out.append(r)
    return out


def resolve_sample(base, rel):
    """从 sfz 所在目录逐级向上尝试解析采样路径。"""
    d = base
    for _ in range(4):
        p = os.path.normpath(os.path.join(d, rel))
        if os.path.exists(p):
            return p
        d = os.path.dirname(d)
    return os.path.normpath(os.path.join(base, rel))


def covers(r, midi):
    if r["keycenter"] is not None:
        return r["keycenter"] == midi
    lo = r["lokey"] if r["lokey"] is not None else 0
    hi = r["hikey"] if r["hikey"] is not None else 127
    return lo <= midi <= hi


def pick_region(regions, midi):
    """选样：精确 keycenter 优先 → 覆盖区间最窄 → velocity 层取中。"""
    cands = [r for r in regions if covers(r, midi)]
    if not cands:
        return None
    def rank(r):
        exact = 0 if r["keycenter"] == midi else 1
        lo = r["lokey"] if r["lokey"] is not None else 0
        hi = r["hikey"] if r["hikey"] is not None else 127
        width = (hi - lo) if r["keycenter"] is None else 0
        vel_mid = (r["lovel"] + r["hivel"]) / 2
        vel_pref = abs(vel_mid - 80)
        return (exact, width, vel_pref)
    return sorted(cands, key=rank)[0]


def nearest_keycenter(regions, midi):
    """全库离 midi 最近的已采样键。"""
    keys = sorted({r["keycenter"] for r in regions
                   if r["keycenter"] is not None})
    if not keys:
        return None
    return min(keys, key=lambda k: (abs(k - midi), k))


# ---------- 音频处理 ----------

def load_mono(path):
    data, sr = sf.read(path, always_2d=True)
    mono = data.mean(axis=1)
    return mono.astype(np.float64), sr


def resample_linear(x, sr_in, sr_out):
    if sr_in == sr_out:
        return x
    n_out = int(round(len(x) * sr_out / sr_in))
    if n_out <= 1:
        return x[:1]
    idx = np.linspace(0, len(x) - 1, n_out)
    return np.interp(idx, np.arange(len(x)), x)


def process(mono, sr):
    x = resample_linear(mono, sr, SR)
    # 起音点对齐
    above = np.flatnonzero(np.abs(x) > ONSET_THRESH)
    start = 0
    if len(above):
        start = max(0, above[0] - int(ONSET_GUARD_MS * SR / 1000))
    x = x[start:]
    # 截断
    x = x[: int(MAX_SEC * SR)]
    if len(x) < 64:
        return None
    # 淡出
    fade = min(len(x), int(FADE_SEC * SR))
    if fade > 0:
        x[-fade:] *= np.linspace(1.0, 0.0, fade)
    # 归一
    peak = np.max(np.abs(x))
    if peak > 0:
        x = x / peak * PEAK
    return x


def write_wav(path, x):
    pcm = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# ---------- 乐器配置 ----------

class Pack:
    def __init__(self, asset_dir, low, high, sfz_list, keyword=None):
        self.asset_dir = asset_dir
        self.low = low
        self.high = high
        self.sfz_list = sfz_list  # 相对 SRC 的 sfz 文件列表
        self.keyword = keyword    # 鼓组用：按文件名关键词挑 sample


PACKS = {
    # 钢琴：Osiris 天然档 · 麦克风 A · 大力度层（重下 v0.925 后解压）
    "piano": Pack("piano", 48, 84, [
        os.path.join("Osiris Piano", "Programs", "modules", "mappings",
                     "uc_mica_vl2_map.sfz"),
    ]),
    # 电钢：Caveman Cosmonaut 合成器全键盘映射（实测覆盖 43–83）
    "ep": Pack("ep", 48, 83, [
        os.path.join("Caveman_Cosmonaut", "Programs", "mappings",
                     "unitra_all_1.sfz"),
    ]),
    # 电吉他：Black And Green 绿琴普通音持续档
    # （46 键 40–86 × 3 力度层，缺 midi 60 由借键兜底；
    #   zip 无顶层目录，解压后与 Bass 共享 extracted 根）
    "eguitar": Pack("eguitar", 40, 76, [
        os.path.join("Programs", "modules", "maps_green", "ord.sfz"),
    ]),
    # 贝斯：Big Little Bass forte 力度层（实测覆盖 35–78，取 B1–E4）
    "bass": Pack("bass", 35, 64, [
        os.path.join("Programs", "maps", "f_map.sfz"),
    ]),
}

# 鼓组：Big Rusty Drums 直接挑中高力度层单文件（vl 层号/rr1 轮替）。
# kick 14 层取 vl12，snare 10 层取 vl8，hihat 6 层取 vl5。
DRUM_FILES = {
    "kick": os.path.join("Samples", "kick_24", "kick", "kick",
                         "k_vl12_rr1.flac"),
    "snare": os.path.join("Samples", "snare_14", "center", "top",
                          "sn_center_vl8_rr1.flac"),
    "hat": os.path.join("Samples", "hihat_14", "cl", "cl",
                        "ht_cl_vl5_rr1.flac"),
}


def crop_melodic(name, pack, dry):
    regions = []
    for rel in pack.sfz_list:
        p = os.path.join(SRC, rel)
        if not os.path.exists(p):
            print(f"[{name}] WARN sfz 不存在: {rel}")
            continue
        regions.extend(parse_sfz(p))
    print(f"[{name}] {len(regions)} regions from {len(pack.sfz_list)} sfz")
    if not regions:
        print(f"[{name}] 无可用 region，跳过")
        return

    outdir = os.path.join(OUT, pack.asset_dir)
    if not dry:
        os.makedirs(outdir, exist_ok=True)
    total = 0
    missing = []
    for midi in range(pack.low, pack.high + 1):
        r = pick_region(regions, midi)
        shift = 1.0
        if r is None:
            # 缺音兜底：借最近键采样，重采样时搬移音高（半音级）。
            k = nearest_keycenter(regions, midi)
            if k is None:
                missing.append(midi)
                continue
            r = pick_region(regions, k)
            shift = 2 ** ((midi - k) / 12)
            print(f"  midi {midi}: 借键 {k} 搬移 "
                  f"{(midi - k):+d} 半音")
        if r is None or not os.path.exists(r["file"]):
            missing.append(midi)
            continue
        if dry:
            print(f"  midi {midi}: {os.path.relpath(r['file'], SRC)}")
            continue
        mono, sr = load_mono(r["file"])
        x = process(mono, sr * shift)
        if x is None:
            missing.append(midi)
            continue
        path = os.path.join(outdir, f"{midi}.wav")
        write_wav(path, x)
        total += os.path.getsize(path)
    if missing:
        print(f"[{name}] 缺失 {len(missing)} 个音: {missing[:10]}")
    else:
        print(f"[{name}] 完成 {pack.high - pack.low + 1} 音, "
              f"{total / 1048576:.2f} MB")


def crop_drums(dry):
    for kind, rel in DRUM_FILES.items():
        p = os.path.join(SRC, rel)
        print(f"  {kind}: {rel}")
        if not os.path.exists(p):
            print(f"    WARN 采样不存在: {p}")
            continue
        if dry:
            continue
        mono, sr = load_mono(p)
        x = process(mono, sr)
        if x is None:
            print(f"    处理后过短，跳过")
            continue
        outdir = os.path.join(OUT, "drums")
        os.makedirs(outdir, exist_ok=True)
        path = os.path.join(outdir, f"{kind}.wav")
        write_wav(path, x)
        print(f"    -> {path} ({os.path.getsize(path) / 1024:.0f} KB)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None, help="逗号分隔乐器名，如 piano,ep")
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()
    names = args.only.split(",") if args.only else list(PACKS)

    for name in names:
        if name == "drums":
            crop_drums(args.dry)
        elif name in PACKS:
            crop_melodic(name, PACKS[name], args.dry)
        else:
            print(f"未知乐器 {name}")


if __name__ == "__main__":
    sys.exit(main())
