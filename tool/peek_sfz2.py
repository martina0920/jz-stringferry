# Bass 程序列表 + unitra/kick 的 region 字段形态
import os
import re

ROOT = r"D:\jz_stringferry\build\samples_src\extracted"

print("== Bass root Programs/*.sfz ==")
progs = sorted(os.listdir(os.path.join(ROOT, "Programs")))
for f in progs:
    if f.lower().endswith(".sfz"):
        print("  ", f)

def show(path, regex, n=6):
    print(f"\n== {os.path.relpath(path, ROOT)} : lines matching {regex} ==")
    with open(path, encoding="utf-8", errors="replace") as f:
        cnt = 0
        for line in f:
            if re.search(regex, line):
                print("  ", line.rstrip()[:150])
                cnt += 1
                if cnt >= n:
                    break

show(os.path.join(ROOT, r"Caveman_Cosmonaut\Programs\mappings\unitra_bass_16_1.sfz"),
     r"<region>|keycenter|pitch_keycenter|lokey|hikey|sample=")
show(os.path.join(ROOT, r"Programs\default\03-kick.sfz"),
     r"<region>|keycenter|pitch_keycenter|lokey|hikey|sample=")
show(os.path.join(ROOT, r"Programs\default\06-hihat.sfz"),
     r"<region>|keycenter|pitch_keycenter|lokey|hikey|sample=")
