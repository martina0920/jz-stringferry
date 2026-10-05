# 检查 Osiris 坏成员构成 + 重新校验 Guitars.zip
import os
import zipfile
from collections import Counter

SRC = r"D:\jz_stringferry\build\samples_src"

# 1) Osiris 坏成员后缀分布
marker = os.path.join(SRC, "extracted", ".Osiris_Piano.zip.done")
if os.path.exists(marker):
    with open(marker, encoding="utf-8") as f:
        lines = [l.split(":")[0].strip() for l in f if l.strip()]
    exts = Counter(os.path.splitext(l)[1].lower() for l in lines)
    print("Osiris bad members:", len(lines), dict(exts))

# 2) Guitars.zip 完整性
p = os.path.join(SRC, "Guitars.zip")
print("Guitars size:", round(os.path.getsize(p) / 1048576, 1), "MB")
try:
    z = zipfile.ZipFile(p)
    bad = z.testzip()
    n = len(z.namelist())
    print("Guitars:", n, "entries, testzip =", "OK" if bad is None else bad)
except Exception as e:
    print("Guitars CORRUPT:", e)

# 3) Osiris 已解压的 flac 数量 vs zip 内 flac 总数
z = zipfile.ZipFile(os.path.join(SRC, "Osiris_Piano.zip"))
total_flac = sum(1 for n in z.namelist() if n.lower().endswith(".flac"))
root = os.path.join(SRC, "extracted", "Osiris Piano")
got = 0
for dirpath, _, files in os.walk(root):
    got += sum(1 for f in files if f.lower().endswith(".flac"))
print(f"Osiris flac: zip total={total_flac}, extracted={got}")
