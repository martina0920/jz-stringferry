# 校验 build/samples_src 下采样 zip 的完整性并列出内部结构（前几层目录）
import os
import zipfile
from collections import Counter

D = r"D:\jz_stringferry\build\samples_src"
FILES = ["Caveman.zip", "Guitars.zip", "Bass.zip", "Drums.zip", "Osiris_Piano.zip"]

for f in FILES:
    p = os.path.join(D, f)
    size = os.path.getsize(p) / 1048576
    try:
        z = zipfile.ZipFile(p)
        bad = z.testzip()
        names = z.namelist()
        exts = Counter(os.path.splitext(n)[1].lower() for n in names)
        top = Counter(n.split("/")[0] for n in names)
        status = "OK" if bad is None else f"BAD: {bad}"
        print(f"{f}: {size:.1f} MB, {len(names)} entries, {status}")
        print(f"  ext: {dict(exts.most_common(6))}")
        print(f"  top dirs: {dict(top.most_common(8))}")
    except Exception as e:
        print(f"{f}: {size:.1f} MB, CORRUPT: {e}")
