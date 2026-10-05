# 获取 karoryfer.black-and-green-guitars 的 release 资产并下载
import json
import os
import subprocess
import urllib.request

def api(url):
    req = urllib.request.Request(url, headers={"User-Agent": "jz-dev"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())

rels = api("https://api.github.com/repos/sfzinstruments/karoryfer.black-and-green-guitars/releases")
for rel in rels:
    print("tag:", rel["tag_name"])
    for a in rel["assets"]:
        print("  asset:", a["name"], a["size"] / 1048576, "MB")
        print("  url:", a["browser_download_url"])

asset = rels[0]["assets"][0]
dest = os.path.join(r"D:\jz_stringferry\build\samples_src", "Guitars.zip")
subprocess.run(
    ["curl.exe", "-L", "-o", dest, "--retry", "2",
     "https://ghfast.top/" + asset["browser_download_url"]],
    check=True,
)
print("downloaded:", round(os.path.getsize(dest) / 1048576, 1), "MB")
