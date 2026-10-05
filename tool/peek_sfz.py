# 摸底各采样包的 sfz 结构：region 关键字段形态与样例
import os
import re

ROOT = r"D:\jz_stringferry\build\samples_src\extracted"

def head(path, n=14):
    print(f"\n===== {os.path.relpath(path, ROOT)} =====")
    with open(path, encoding="utf-8", errors="replace") as f:
        for i, line in enumerate(f):
            if i >= n:
                break
            print("  ", line.rstrip()[:130])

# Caveman（EP 候选：poly_map 全键盘映射）
head(os.path.join(ROOT, r"Caveman_Cosmonaut\Programs\mappings\poly_map.sfz"), 16)
head(os.path.join(ROOT, r"Caveman_Cosmonaut\Programs\main.sfz"), 12)

# Bass（根目录 Programs/*.sfz）
head(os.path.join(ROOT, r"Programs\01-big_little_pluck.sfz"), 16)

# Drums：找一个 kick/snare/hat 相关 sfz
for dirpath, _, files in os.walk(os.path.join(ROOT, "Programs")):
    for fn in files:
        if fn.lower().endswith(".sfz") and any(
                k in fn.lower() for k in ["kick", "snare", "hat", "main", "kit"]):
            print("  drums sfz:", os.path.relpath(os.path.join(dirpath, fn), ROOT))
