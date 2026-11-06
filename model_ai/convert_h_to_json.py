# convert_h_to_json.py
# Konversi model_weights.h → model_payload.json (untuk upload ke Flask)

import json
import re

H_FILE      = "model_weights.h"
OUT_FILE    = "model_payload.json"
DEVICE_ID   = "esp32_greenhouse_01"    # ← GANTI sesuai device Anda

src = open(H_FILE).read()

def extract_2d(name):
    # Dukung dua gaya penamaan: W1_ai (wajib untuk ESP32) atau W1 (lama)
    for cand in (f"{name}_ai", name):
        m = re.search(rf"\b{cand}\s*(?:\[[^\]]*\]\s*)*=\s*\{{(.*?)\}}\s*;", src, re.S)
        if m:
            break
    if not m:
        raise SystemExit(f"✖ '{name}' tidak ditemukan di {H_FILE}")
    body = m.group(1)
    rows = re.findall(r"\{([^{}]*)\}", body)
    return [[float(v) for v in re.findall(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", r)]
            for r in rows]

def extract_1d(name):
    for cand in (f"{name}_ai", name):
        m = re.search(rf"\b{cand}\s*(?:\[[^\]]*\]\s*)*=\s*\{{(.*?)\}}\s*;", src, re.S)
        if m:
            break
    if not m:
        raise SystemExit(f"✖ '{name}' tidak ditemukan di {H_FILE}")
    return [float(v) for v in re.findall(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", m.group(1))]

def extract_def(name, default=None):
    m = re.search(rf"#define\s+{name}\s+([0-9.]+)f?", src)
    return float(m.group(1)) if m else default

W1 = extract_2d("W1")
B1 = extract_1d("B1")
W2 = extract_2d("W2")
B2 = extract_1d("B2")

max_out = [
    extract_def("MAX_A",       200.0),
    extract_def("MAX_B",       200.0),
    extract_def("MAX_PH_UP",    30.0),
    extract_def("MAX_PH_DOWN",  30.0),
]

payload = {
    "device_id": DEVICE_ID,
    "W1": W1, "B1": B1, "W2": W2, "B2": B2,
    "max_out": max_out,
    "r2": 0.0,                 # tidak ada di .h — boleh 0
    "source": "manual_h",
}

with open(OUT_FILE, "w") as f:
    json.dump(payload, f)

print(f"✅ {OUT_FILE} dibuat")
print(f"   W1: {len(W1)}x{len(W1[0])}   B1: {len(B1)}")
print(f"   W2: {len(W2)}x{len(W2[0])}   B2: {len(B2)}")
print(f"   MAX: {max_out}")