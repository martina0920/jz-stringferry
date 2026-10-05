# 诊断 Guitars.zip 内容 + 从 GitHub API 查两个仓库的真实 release 资产地址
import json
import os
import urllib.request

SRC = r"D:\jz_stringferry\build\samples_src"

with open(os.path.join(SRC, "Guitars.zip"), "rb") as f:
    head = f.read(300)
print("Guitars head bytes:", head[:120])

def api(url):
    req = urllib.request.Request(url, headers={"User-Agent": "jz-dev"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())

for repo in ["KaroryferSamples/BlackAndGreenGuitars", "KaroryferSamples/Osiris-Piano"]:
    try:
        rels = api(f"https://api.github.com/repos/{repo}/releases")
        print(f"\n== {repo} ==")
        for rel in rels[:2]:
            print(" tag:", rel["tag_name"])
            for a in rel["assets"]:
                print("   asset:", a["name"], a["size"] // 1048576, "MB")
                print("   url:", a["browser_download_url"])
    except Exception as e:
        print(f"{repo}: API error {e}")
