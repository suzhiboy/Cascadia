"""Run two actual game processes; verify a full game and identical final state."""
import subprocess, time, sys, re, os
from pathlib import Path
exe = sys.argv[1]
cmd = [exe, "--headless", "--", "--lan-test"]
count = int(sys.argv[2]) if len(sys.argv)>2 else 2
env = dict(os.environ, CASCADIA_TEST_COUNT=str(count))
jobs = []
for role in ["host"] + ["client"+str(i) for i in range(1,count)]:
    f = open("build/lan-" + role + ".log", "w", encoding="utf-8")
    p = subprocess.Popen(cmd + [role], stdout=f, stderr=subprocess.STDOUT, env=env)
    jobs.append((role, p, f))
    time.sleep(1)
hashes = []
ok = True
for role, p, f in jobs:
    try:
        p.wait(timeout=35)
    except subprocess.TimeoutExpired:
        p.kill()
        p.wait()
    f.close()
    text = Path("build/lan-" + role + ".log").read_text(encoding="utf-8")
    print(role, p.returncode, text[-1800:])
    ok = ok and p.returncode == 0 and "LAN PASS" in text and "SCRIPT ERROR" not in text
    hashes.extend(re.findall(r"STATE HASH (\w+)", text))
ok = ok and len(hashes) == count and len(set(hashes)) == 1
print("LAN PROCESS TEST:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
