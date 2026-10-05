# -*- coding: utf-8 -*-
"""并行分段下载：对限速镜像用多连接 range 请求提速，最后合并。"""
import os
import subprocess
import sys
import urllib.request

MIRROR = "https://ghfast.top/"
URL = MIRROR + ("https://github.com/sfzinstruments/karoryfer."
                "black-and-green-guitars/releases/download/v1.000/"
                "Karoryfer_Black_And_Green_Guitars_1000.zip")
DEST = r"D:\jz_stringferry\build\samples_src\Guitars.zip"
PARTS = 8


def head_content_length():
    req = urllib.request.Request(URL, method="HEAD")
    with urllib.request.urlopen(req, timeout=30) as r:
        return int(r.headers["Content-Length"])


def main():
    total = head_content_length()
    have = os.path.getsize(DEST) if os.path.exists(DEST) else 0
    if have >= total:
        print(f"already complete: {have} >= {total}")
        return
    print(f"total={total} have={have} remaining={total - have}")

    seg = (total - have + PARTS - 1) // PARTS
    part_files = []
    procs = []
    for i in range(PARTS):
        start = have + i * seg
        end = min(have + (i + 1) * seg - 1, total - 1)
        if start > end:
            break
        pf = f"{DEST}.part{i}"
        part_files.append(pf)
        cmd = ["curl.exe", "-sS", "-L", "--retry", "5", "--retry-delay", "2",
               "--retry-all-errors", "--max-time", "1800",
               "-r", f"{start}-{end}", "-o", pf, URL]
        procs.append(subprocess.Popen(cmd))
        print(f"  part{i}: {start}-{end} ({(end - start + 1) // 1048576}MB)")

    codes = [p.wait() for p in procs]
    print("exit codes:", codes)
    for i, pf in enumerate(part_files):
        expect = min(seg, total - have - i * seg)
        actual = os.path.getsize(pf) if os.path.exists(pf) else -1
        status = "OK" if actual == expect else f"BAD (want {expect})"
        print(f"  part{i}: {actual // 1048576}MB {status}")
        if actual != expect:
            sys.exit(f"part{i} size mismatch, abort")

    with open(DEST, "ab") as out:
        for pf in part_files:
            with open(pf, "rb") as f:
                while True:
                    chunk = f.read(1 << 20)
                    if not chunk:
                        break
                    out.write(chunk)
    for pf in part_files:
        os.remove(pf)

    final = os.path.getsize(DEST)
    print(f"merged: {final} / {total} -> "
          f"{'COMPLETE' if final == total else 'MISMATCH'}")


if __name__ == "__main__":
    main()
