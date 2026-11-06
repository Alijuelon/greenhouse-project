# =====================================================================
# ai_model.py
# Modul inferensi MLP 8-10-4 untuk dosing greenhouse cabai.
# Konstanta & expert() HARUS identik dengan train_model.py di Colab.
# =====================================================================
import numpy as np

# ---------------------------------------------------------------------
# Konstanta global
# ---------------------------------------------------------------------
TANK_L               = 100.0
SOL_EC               = [1.4, 2.0, 2.6, 3.0]
ML_PER_L_PER_MS      = 5.0
PH_ML_PER_L_PER_UNIT = 0.40
SOL_MULT             = 0.18
MAX_OUT              = np.array([200.0, 200.0, 30.0, 30.0], dtype=np.float32)
N_IN, N_HID, N_OUT   = 8, 10, 4
EC_UNIT_DIV          = 1000.0

_CACHE = {
    "device_id": None, "version": 0,
    "W1": None, "B1": None, "W2": None, "B2": None,
    "max_out": MAX_OUT.copy(),
}


# =====================================================================
# Expert — identik dengan Colab
# =====================================================================
def expert(x):
    x = np.asarray(x, dtype=np.float64)
    out = np.zeros(4, dtype=np.float64)

    ph = max(0, min(3, int(round(float(x[7]) * 3))))
    deficit = max(0.0, float(x[0]))
    base = 0.0
    if x[5] >= 0.30:
        base = SOL_MULT * ML_PER_L_PER_MS * deficit * SOL_EC[ph] * TANK_L
    base *= 1.0 - 0.3 * max(0.0, float(x[6]))

    n_bias = float(x[1]) - (float(x[2]) + float(x[3])) / 2.0
    r_a = float(np.clip(1.0 + 0.3 * n_bias, 0.8, 1.2))

    out[0] = base * r_a
    out[1] = base * (2.0 - r_a)
    if x[4] > 0.35:
        out[2] = 0.5 * PH_ML_PER_L_PER_UNIT * float(x[4]) * TANK_L
    if x[4] < -0.35:
        out[3] = 0.5 * PH_ML_PER_L_PER_UNIT * (-float(x[4])) * TANK_L
    return out


# =====================================================================
# Feature builder: dict sensor Flask → x[8]
# =====================================================================
def build_features(sensor, phase, ec_setpoint=2.0):
    ec_raw = float(sensor.get("ec", 0.0) or 0.0) / EC_UNIT_DIV
    ph     = float(sensor.get("ph", 7.0) or 7.0)
    soil   = float(sensor.get("tanah_lembap", 0.0) or 0.0)
    air_t  = float(sensor.get("air_suhu", 25.0) or 25.0)

    ec_err = ec_setpoint - ec_raw
    return np.array([
        np.clip(ec_err,               -0.6, 0.8),
        np.clip((ec_raw - 1.5) / 1.5, -0.6, 0.8),
        np.clip( 0.5 * ec_err,        -0.6, 0.8),
        np.clip(-0.5 * ec_err,        -0.6, 0.8),
        np.clip((7.0 - ph) / 3.0,     -1.5, 1.5),
        np.clip(soil / 100.0,          0.0, 1.0),
        np.clip((air_t - 25.0) / 15.0, -1.0, 1.0),
        float(phase) / 3.0,
    ], dtype=np.float32)


# =====================================================================
# Manajemen cache bobot
# =====================================================================
def load_weights(device_id, version, w, max_out=None):
    W1 = np.asarray(w["W1"], dtype=np.float32)
    B1 = np.asarray(w["B1"], dtype=np.float32)
    W2 = np.asarray(w["W2"], dtype=np.float32)
    B2 = np.asarray(w["B2"], dtype=np.float32)

    assert W1.shape == (N_HID, N_IN),  f"W1 {W1.shape}"
    assert B1.shape == (N_HID,),       f"B1 {B1.shape}"
    assert W2.shape == (N_OUT, N_HID), f"W2 {W2.shape}"
    assert B2.shape == (N_OUT,),       f"B2 {B2.shape}"

    _CACHE.update({
        "device_id": device_id, "version": version,
        "W1": W1, "B1": B1, "W2": W2, "B2": B2,
        "max_out": np.asarray(max_out, dtype=np.float32) if max_out else MAX_OUT.copy(),
    })


def has_model(device_id):
    return _CACHE["device_id"] == device_id and _CACHE["W1"] is not None


def current_version(device_id):
    return _CACHE["version"] if has_model(device_id) else 0


def clear_cache():
    _CACHE.update({"device_id": None, "version": 0,
                   "W1": None, "B1": None, "W2": None, "B2": None,
                   "max_out": MAX_OUT.copy()})


# =====================================================================
# Inferensi MLP
# =====================================================================
def infer(x):
    if _CACHE["W1"] is None:
        return None
    x = np.asarray(x, dtype=np.float32).reshape(1, -1)
    h = np.maximum(0.0, x @ _CACHE["W1"].T + _CACHE["B1"])
    y = h @ _CACHE["W2"].T + _CACHE["B2"]
    y = np.clip(y, 0.0, 1.0)
    return (y[0] * _CACHE["max_out"]).astype(float).tolist()


# =====================================================================
# Keputusan dosis
# =====================================================================
def decide(x, ai_mode, ai_ready):
    ml_expert = expert(x).tolist()
    if ai_mode == "off" or not ai_ready:
        return "expert", ml_expert
    ml_ai = infer(x)
    if ml_ai is None:
        return "expert", ml_expert
    if ai_mode == "shadow":
        return "expert_shadow", ml_expert, ml_ai
    return "ai", ml_ai
