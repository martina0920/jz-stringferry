# 解压采样 zip 到 build/samples_src/extracted/（坏成员跳过并记录）
import os
import shutil
import sys
import zipfile

SRC = r"D:\jz_stringferry\build\samples_src"
OUT = os.path.join(SRC, "extracted")

JOBS = [
    "Caveman.zip",
    "Guitars.zip",  # 当前损坏，存在则跳过
    "Bass.zip",
    "Drums.zip",
    "Osiris_Piano.zip",
]

only = sys.argv[1] if len(sys.argv) > 1 else None
os.makedirs(OUT, exist_ok=True)

for name in JOBS:
    if only and only not in name:
        continue
    dest_marker = os.path.join(OUT, f".{name}.done")
    if os.path.exists(dest_marker):
        print(f"{name}: already extracted, skip")
        continue
    zpath = os.path.join(SRC, name)
    if not os.path.exists(zpath):
        print(f"{name}: missing, skip")
        continue
    print(f"{name}: extracting...")
    bad = []
    try:
        with zipfile.ZipFile(zpath) as z:
            for info in z.infolist():
                if info.is_dir():
                    continue
                target = os.path.join(OUT, info.filename.replace("/", os.sep))
                try:
                    os.makedirs(os.path.dirname(target), exist_ok=True)
                    with z.open(info) as src, open(target, "wb") as dst:
                        shutil.copyfileobj(src, dst, 1024 * 1024)
                except Exception as e:
                    bad.append(f"{info.filename}: {e}")
                    try:
                        os.remove(target)
                    except OSError:
                        pass
    except zipfile.BadZipFile as e:
        print(f"{name}: CORRUPT, skip ({e})")
        continue
    with open(dest_marker, "w", encoding="utf-8") as f:
        f.write("\n".join(bad))
    print(f"{name}: done, bad={len(bad)}")
    for b in bad[:3]:
        print(f"  {b}")
