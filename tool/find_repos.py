# 搜索 Karoryfer 的仓库与两个目标库的真实 release 资产
import json
import urllib.request

def api(url):
    req = urllib.request.Request(url, headers={"User-Agent": "jz-dev"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())

hits = api("https://api.github.com/search/repositories?q=karoryfer&per_page=5")
print("search karoryfer:", [r["full_name"] for r in hits.get("items", [])])

# 直接列 org/user repos
for owner in ["Karoryfer", "KaroryferSamples"]:
    try:
        repos = api(f"https://api.github.com/users/{owner}/repos?per_page=100")
        names = [r["name"] for r in repos]
        print(f"\n{owner}: {len(names)} repos")
        for n in names:
            if any(k in n.lower() for k in ["guitar", "osiris", "piano", "bass", "drum", "caveman"]):
                print("  ", n)
    except Exception as e:
        print(f"{owner}: {e}")
