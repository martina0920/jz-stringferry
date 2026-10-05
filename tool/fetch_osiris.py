# 重新下载 Osiris_Piano.zip（此前下载内部 CRC 损坏 393 个成员）
import json
import os
import subprocess
import urllib.request

def api(url):
    req = urllib.request.Request(url, headers={"User-Agent": "jz-dev"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())

repos = api("https://api.github.com/search/repositories?q=osiris+karoryfer&per_page=5")
print([r["full_name"] for r in repos.get("items", [])])
full = repos["items"][0]["full_name"]

rels = api(f"https://api.github.com/repos/{full}/releases")
rel = rels[0]
print("tag:", rel["tag_name"])
asset = next(a for a in rel["assets"] if a["name"].lower().endswith(".zip"))
print("asset:", asset["name"], asset["size"] / 1048576, "MB")

dest = os.path.join(r"D:\jz_stringferry\build\samples_src", "Osiris_Piano.zip")
if os.path.exists(dest):
    try:
        os.remove(dest)
    except PermissionError:
        dest = os.path.join(r"D:\jz_stringferry\build\samples_src", "Osiris_Piano_new.zip")
        print("locked, writing to", dest)
subprocess.run(
    ["curl.exe", "-L", "-o", dest, "--retry", "2",
     "https://ghfast.top/" + asset["browser_download_url"]],
    check=True,
)
print("downloaded:", round(os.path.getsize(dest) / 1048576, 1), "MB")
