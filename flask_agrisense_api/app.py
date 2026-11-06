# =====================================================================
#  GREENHOUSE API — Flask + AI Model
#  Struktur:
#    1. Setup & Config
#    2. Helper (AI cache loader)
#    3. ESP32 Endpoints
#    4. Flutter App Endpoints (existing)
#    5. AI Model Endpoints (new)
#    6. Main
# =====================================================================
import csv
import json as _json
import os
import secrets
import time
from datetime import datetime, timedelta
from io import StringIO, BytesIO

from flask import Flask, request, jsonify, Response, send_file
from flask_cors import CORS
from werkzeug.utils import secure_filename

from database import (db, DeviceState, Telemetry, AutomationRule,
                      ActivityLog, AppSettings, AIModel, DoseLog,
                      AIPerformance, ManualCommand)
from rule_engine import evaluate_rules
import ai_model


# =====================================================================
#  1. SETUP & CONFIG
# =====================================================================
app = Flask(__name__)
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = (
    os.environ.get('DATABASE_URL')
    or 'mysql+pymysql://root:123456@localhost/agrisense_db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

app.config['UPLOAD_FOLDER'] = os.path.join(app.root_path, 'static', 'uploads')
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Batas ukuran upload (samakan dengan client_max_body_size nginx / cPanel)
app.config['MAX_CONTENT_LENGTH'] = int(
    os.environ.get('MAX_UPLOAD_MB', '12')
) * 1024 * 1024

db.init_app(app)

# API key valid dibaca dari env API_SECRET_KEYS (dipisah koma).
# Fallback: kunci lama agar instalasi LAN tetap berjalan sebelum .env dibuat.
API_SECRET_KEYS = {
    k.strip()
    for k in os.environ.get(
        'API_SECRET_KEYS',
        'rahasia-greenhouse-2025,live_sec_agri_89f2',
    ).split(',')
    if k.strip()
}

@app.before_request
def check_api_auth():
    """Validasi API key pada endpoint mutasi data (POST, PUT, DELETE)."""
    if request.method in ('POST', 'PUT', 'DELETE') and request.path.startswith('/api/'):
        key = request.headers.get('x-api-key') or request.headers.get('X-API-Key')
        if key in API_SECRET_KEYS:
            return None
        setting = AppSettings.query.first()
        if setting and setting.api_key and key == setting.api_key:
            return None
        return jsonify({"error": "Unauthorized: API Key tidak valid atau tidak disertakan"}), 401



# =====================================================================
#  2. HELPER — AI model cache
# =====================================================================
def _load_ai_model_for(device_id):
    """Muat bobot terbaru dari DB ke cache memori (kalau versi berbeda)."""
    row = (AIModel.query
           .filter_by(device_id=device_id)
           .order_by(AIModel.version.desc())
           .first())
    if not row:
        return False
    if ai_model.current_version(device_id) == row.version:
        return True
    try:
        w = {
            "W1": _json.loads(row.W1_json),
            "B1": _json.loads(row.B1_json),
            "W2": _json.loads(row.W2_json),
            "B2": _json.loads(row.B2_json),
        }
        max_out = _json.loads(row.max_out_json) if row.max_out_json else None
        ai_model.load_weights(device_id, row.version, w, max_out)
        return True
    except Exception as e:
        print(f"[AI] Gagal load model: {e}")
        return False


def _warmup_ai_cache():
    """Panggil sekali saat startup."""
    with app.app_context():
        db.create_all()
        for d in DeviceState.query.all():
            _load_ai_model_for(d.id)
        n = AIModel.query.count()
        print(f"[AI] Warm-up selesai. Total model di DB: {n}")


def _log_dose(device_id, src, phase, x_vec, ml_exec, ai_ml=None):
    """Simpan log dosis, kembalikan id atau None."""
    try:
        log = DoseLog(
            device_id=device_id, src=src, phase=phase,
            x_json=_json.dumps(x_vec.tolist()),
            ml_json=_json.dumps({k: ml_exec[i]
                                 for i, k in enumerate(("A", "B", "PH_UP", "PH_DOWN"))}),
            ai_ml_json=(_json.dumps(ai_ml) if ai_ml else None),
        )
        db.session.add(log)
        db.session.commit()
        return log.id
    except Exception as e:
        db.session.rollback()
        print(f"[AI] Gagal log dose: {e}")
        return None


# =====================================================================
#  3. ESP32 ENDPOINTS
# =====================================================================
@app.route('/api/sensor', methods=['POST'])
def esp32_sensor_data():
    """
    ESP32 POST telemetry → server balas target relay + (opsional) dose AI.
    
    Catatan:
    - AI tetap dihitung walau NPK kosong (biarkan saja)
    - Log dose HANYA disimpan ke database kalau NPK valid (salah satu > 0)
    """
    data = request.json
    if not data or 'device_id' not in data:
        return jsonify({"error": "Bad Request"}), 400

    device_id = data['device_id']
    device = db.session.get(DeviceState, device_id)
    if not device:
        device = DeviceState(id=device_id)
        db.session.add(device)

    # --- Update state dari sensor ---
    device.air_suhu     = data.get('air_suhu', 0.0)
    device.air_hum      = data.get('air_hum', 0.0)
    device.tanah_suhu   = data.get('tanah_suhu', 0.0)
    device.tanah_lembap = data.get('tanah_lembap', 0.0)
    device.ph           = data.get('ph', 0.0)
    device.ec           = data.get('ec', 0.0)
    device.n            = data.get('n', 0)
    device.p            = data.get('p', 0)
    device.k            = data.get('k', 0)
    device.soil_ok      = data.get('soil_ok', False)
    device.uptime       = data.get('uptime', 0)
    device.last_seen    = datetime.utcnow()

    if 'relay' in data:
        device.relay_state = data['relay']

    db.session.commit()

    # --- Simpan telemetry historis (SELALU — ini data sensor mentah) ---
    tel = Telemetry(
        device_id=device_id,
        air_suhu=device.air_suhu, air_hum=device.air_hum,
        tanah_suhu=device.tanah_suhu, tanah_lembap=device.tanah_lembap,
        ph=device.ph, ec=device.ec, n=device.n, p=device.p, k=device.k,
    )
    db.session.add(tel)
    db.session.commit()

    # --- Jalankan rule engine (existing) ---
    evaluate_rules(device_id)

    # --- AI decision ---
    device = db.session.get(DeviceState, device_id)
    target_relay = device.target_relay_state
    dose_payload, ai_ready = None, _load_ai_model_for(device_id)

    # Cek validitas NPK (untuk keputusan penyimpanan log saja)
    npk_valid = (device.n > 0) or (device.p > 0) or (device.k > 0)

    if device.ai_mode in ("shadow", "auto") and ai_ready:
        # Tetap hitung AI walau NPK kosong — biarkan saja
        x_vec = ai_model.build_features(
            sensor={
                "ec": device.ec, "ph": device.ph,
                "tanah_lembap": device.tanah_lembap,
                "air_suhu": device.air_suhu,
            },
            phase=device.phase,
            ec_setpoint=device.ec_setpoint or 2.0,
        )

        result = ai_model.decide(x_vec, device.ai_mode, ai_ready)
        ai_ml_shadow = None
        if device.ai_mode == "shadow":
            src, ml_exec, ai_ml_shadow = result
        else:
            src, ml_exec = result

        dose_payload = {
            "A":       round(ml_exec[0], 2),
            "B":       round(ml_exec[1], 2),
            "PH_UP":   round(ml_exec[2], 2),
            "PH_DOWN": round(ml_exec[3], 2),
            "src":     src,
            "phase":   device.phase,
        }

        # ==== SIMPAN LOG HANYA KALAU NPK VALID + cooldown 10 detik ====
        if npk_valid:
            # Cek cooldown: ambil log terbaru untuk device ini
            last_log = (DoseLog.query.filter_by(device_id=device_id)
                        .order_by(DoseLog.timestamp.desc()).first())
            elapsed = 999
            if last_log:
                elapsed = (datetime.utcnow() - last_log.timestamp).total_seconds()
            
            if elapsed >= 10:  # Simpan maksimum setiap 10 detik
                log_id = _log_dose(device_id, src, device.phase, x_vec, ml_exec, ai_ml_shadow)
                if log_id:
                    dose_payload["log_id"] = log_id
                    dose_payload["logged"] = True
            else:
                dose_payload["logged"] = False
                dose_payload["skip_reason"] = f"cooldown ({int(elapsed)}s < 10s)"
        else:
            dose_payload["logged"] = False
            dose_payload["skip_reason"] = "npk_zero"

    # --- Manual Commands ---
    manual_commands = []
    if device.ai_mode == "manual":
        pending_commands = ManualCommand.query.filter_by(device_id=device_id, status='pending').all()
        for cmd in pending_commands:
            manual_commands.append({
                "id": cmd.id,
                "pump": cmd.pump,
                "ml": cmd.ml
            })

    return jsonify({
        "relay":         target_relay,
        "dose":          dose_payload,
        "ai_mode":       device.ai_mode,
        "model_version": ai_model.current_version(device_id),
        "phase":         device.phase,
        "npk_valid":     npk_valid,   # info tambahan untuk client
        "manual_commands": manual_commands
    })
    
# =====================================================================
#  3.5. MANUAL ENDPOINTS
# =====================================================================

@app.route('/api/manual/command', methods=['POST'])
def add_manual_command():
    data = request.json
    if not data or 'device_id' not in data or 'pump' not in data or 'ml' not in data:
        return jsonify({"error": "Bad Request"}), 400

    cmd = ManualCommand(
        device_id=data['device_id'],
        pump=data['pump'],
        ml=float(data['ml'])
    )
    db.session.add(cmd)
    db.session.commit()
    
    # Log the activity
    log = ActivityLog(
        event_type="Manual Command",
        description=f"Manual dosing queue added for {cmd.pump} with {cmd.ml} ml",
        details=f"Device: {cmd.device_id}, Command ID: {cmd.id}"
    )
    db.session.add(log)
    db.session.commit()

    return jsonify({"success": True, "command_id": cmd.id}), 201

@app.route('/api/manual/ack', methods=['POST'])
def ack_manual_command():
    data = request.json
    if not data or 'id' not in data or 'success' not in data:
        return jsonify({"error": "Bad Request"}), 400

    cmd_id = data['id']
    success = data['success']
    reason = data.get('reason', '')

    cmd = db.session.get(ManualCommand, cmd_id)
    if not cmd:
        return jsonify({"error": "Command not found"}), 404

    cmd.status = 'executed' if success else 'failed'
    db.session.commit()

    return jsonify({"success": True}), 200

# =====================================================================
#  4. FLUTTER APP ENDPOINTS (existing, tidak berubah)
# =====================================================================
@app.route('/api/dashboard/live', methods=['GET'])
def get_dashboard_live():
    device_id = request.args.get('device_id', 'esp32_greenhouse_01')
    device = db.session.get(DeviceState, device_id)
    if not device:
        return jsonify({"error": "Device not found"}), 404

    is_online = (datetime.utcnow() - device.last_seen).total_seconds() < 15

    return jsonify({
        "device_id": device.id,
        "is_online": is_online,
        "uptime":    device.uptime,
        "last_seen": device.last_seen.isoformat() + "Z",
        "sensors": {
            "air_suhu":     device.air_suhu,
            "air_hum":      device.air_hum,
            "tanah_suhu":   device.tanah_suhu,
            "tanah_lembap": device.tanah_lembap,
            "ph":           device.ph,
            "ec":           device.ec,
            "n":            device.n,
            "p":            device.p,
            "k":            device.k,
            "soil_ok":      device.soil_ok,
        },
        "relays":        device.relay_state,
        "target_relays": device.target_relay_state,
        # Tambahan AI (backward-compatible)
        "ai": {
            "mode":          device.ai_mode,
            "phase":         device.phase,
            "ec_setpoint":   device.ec_setpoint,
            "model_version": ai_model.current_version(device_id),
        },
    })


@app.route('/api/relay/toggle', methods=['POST'])
def toggle_relay():
    data = request.json
    device_id    = data.get('device_id', 'esp32_greenhouse_01')
    relay_index  = data.get('relay_index')
    target_state = data.get('target_state')

    if relay_index is None or target_state is None:
        return jsonify({"error": "Missing parameters"}), 400

    device = db.session.get(DeviceState, device_id)
    if not device:
        return jsonify({"error": "Device not found"}), 404

    current_targets = device.target_relay_state
    if not (0 <= relay_index < 6):
        return jsonify({"error": "Invalid relay index"}), 400

    current_targets[relay_index] = bool(target_state)
    device.target_relay_state = current_targets

    log = ActivityLog(
        event_type="Manual",
        description=f"Manual override Relay {relay_index}",
        details=f"Set to {'ON' if target_state else 'OFF'}",
    )
    db.session.add(log)
    db.session.commit()

    return jsonify({"success": True, "target_relays": current_targets})


@app.route('/api/relay/timer', methods=['POST'])
def set_relay_timer():
    """
    Menyalakan relay selama X detik, kemudian otomatis mematikannya kembali.
    Body: { device_id, relay_index, duration }
    """
    data = request.json or {}
    device_id   = data.get('device_id', 'esp32_greenhouse_01')
    relay_index = data.get('relay_index')
    duration    = int(data.get('duration', 60))

    if relay_index is None or not (0 <= relay_index < 6):
        return jsonify({"error": "relay_index tidak valid (harus 0-5)"}), 400

    device = db.session.get(DeviceState, device_id)
    if not device:
        return jsonify({"error": "Device tidak ditemukan"}), 404

    targets = device.target_relay_state
    targets[relay_index] = True
    device.target_relay_state = targets

    log = ActivityLog(
        event_type="Timer",
        description=f"Relay {relay_index} aktif via timer ({duration}s)",
        details=f"device={device_id} duration={duration}s",
    )
    db.session.add(log)
    db.session.commit()

    import threading
    def _auto_turn_off():
        import time as _time
        _time.sleep(duration)
        with app.app_context():
            dev = db.session.get(DeviceState, device_id)
            if dev:
                t = dev.target_relay_state
                t[relay_index] = False
                dev.target_relay_state = t
                db.session.commit()

    threading.Thread(target=_auto_turn_off, daemon=True).start()

    return jsonify({
        "success": True,
        "relay_index": relay_index,
        "duration": duration,
        "target_relays": targets
    })



@app.route('/api/analytics/chart', methods=['GET'])
def get_analytics_chart():
    device_id      = request.args.get('device_id', 'esp32_greenhouse_01')
    metric         = request.args.get('metric', 'air_suhu')
    hours          = int(request.args.get('hours', 24))
    start_date_str = request.args.get('start_date')
    end_date_str   = request.args.get('end_date')

    query = Telemetry.query.filter(Telemetry.device_id == device_id)

    if start_date_str and end_date_str:
        start_date = datetime.fromisoformat(start_date_str.replace('Z', '+00:00')).replace(tzinfo=None)
        end_date   = datetime.fromisoformat(end_date_str.replace('Z', '+00:00')).replace(tzinfo=None)
        query = query.filter(Telemetry.timestamp >= start_date,
                             Telemetry.timestamp <= end_date)
    else:
        query = query.filter(Telemetry.timestamp >= datetime.utcnow() - timedelta(hours=hours))

    records = query.order_by(Telemetry.timestamp.asc()).all()

    data, values = [], []
    for r in records:
        val = getattr(r, metric, None)
        if val is not None:
            data.append({"timestamp": r.timestamp.isoformat() + "Z", "value": val})
            values.append(val)

    kpi = {
        "avg": sum(values) / len(values) if values else 0.0,
        "max": max(values) if values else 0.0,
        "min": min(values) if values else 0.0,
    }
    return jsonify({"metric": metric, "kpi": kpi, "data": data})


@app.route('/api/analytics/export', methods=['GET'])
def export_analytics():
    device_id      = request.args.get('device_id', 'esp32_greenhouse_01')
    format_type    = request.args.get('format', 'pdf')
    start_date_str = request.args.get('start_date')
    end_date_str   = request.args.get('end_date')

    query = Telemetry.query.filter(Telemetry.device_id == device_id)
    if start_date_str and end_date_str:
        try:
            start_date = datetime.fromisoformat(start_date_str.replace('Z', '+00:00'))
            end_date   = datetime.fromisoformat(end_date_str.replace('Z', '+00:00'))
            query = query.filter(Telemetry.timestamp >= start_date,
                                 Telemetry.timestamp <= end_date)
        except ValueError:
            pass

    records = query.order_by(Telemetry.timestamp.desc()).limit(1000).all()

    if format_type == 'csv':
        si = StringIO()
        cw = csv.writer(si)
        cw.writerow(['timestamp', 'air_suhu', 'air_hum', 'tanah_suhu',
                     'tanah_lembap', 'ph', 'ec', 'n', 'p', 'k'])
        for r in records:
            cw.writerow([r.timestamp.isoformat(), r.air_suhu, r.air_hum,
                         r.tanah_suhu, r.tanah_lembap, r.ph, r.ec, r.n, r.p, r.k])
        return Response(
            si.getvalue(), mimetype='text/csv',
            headers={"Content-Disposition": "attachment;filename=analytics_export.csv"},
        )

    # PDF
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
        from reportlab.lib.styles import getSampleStyleSheet
        from reportlab.lib import colors

        buffer = BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=30, leftMargin=30,
                                topMargin=30, bottomMargin=18)
        elements, styles = [], getSampleStyleSheet()

        elements.append(Paragraph("Greenhouse Analytics Export", styles['Heading1']))
        if start_date_str and end_date_str:
            elements.append(Paragraph(f"Periode: {start_date_str} s/d {end_date_str}", styles['Normal']))
        else:
            elements.append(Paragraph(f"Menampilkan {len(records)} riwayat terakhir", styles['Normal']))
        elements.append(Spacer(1, 12))

        data = [["Waktu", "Suhu (°C)", "Hum (%)", "pH", "EC", "NPK (mg/kg)"]]
        for r in records[:500]:
            data.append([
                r.timestamp.strftime('%Y-%m-%d %H:%M'),
                f"{r.air_suhu:.1f}", f"{r.air_hum:.1f}",
                f"{r.ph:.1f}", f"{r.ec:.1f}",
                f"{r.n},{r.p},{r.k}",
            ])

        t = Table(data, colWidths=[120, 70, 70, 60, 60, 100])
        t.setStyle(TableStyle([
            ('BACKGROUND',    (0, 0), (-1, 0), colors.HexColor("#2C614F")),
            ('TEXTCOLOR',     (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN',         (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME',      (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE',      (0, 0), (-1, 0), 10),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND',    (0, 1), (-1, -1), colors.beige),
            ('GRID',          (0, 0), (-1, -1), 1, colors.black),
            ('FONTSIZE',      (0, 1), (-1, -1), 9),
        ]))
        elements.append(t)
        doc.build(elements)
        buffer.seek(0)
        return send_file(buffer, as_attachment=True,
                         download_name='analytics_export.pdf',
                         mimetype='application/pdf')
    except ImportError:
        # Fallback aman ke CSV jika reportlab belum terinstall
        si = StringIO()
        cw = csv.writer(si)
        cw.writerow(['timestamp', 'air_suhu', 'air_hum', 'tanah_suhu',
                     'tanah_lembap', 'ph', 'ec', 'n', 'p', 'k'])
        for r in records:
            cw.writerow([r.timestamp.isoformat(), r.air_suhu, r.air_hum,
                         r.tanah_suhu, r.tanah_lembap, r.ph, r.ec, r.n, r.p, r.k])
        return Response(
            si.getvalue(), mimetype='text/csv',
            headers={"Content-Disposition": "attachment;filename=analytics_export.csv"},
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/api/analytics/logs', methods=['GET'])
def get_activity_logs():
    limit = int(request.args.get('limit', 20))
    logs = ActivityLog.query.order_by(ActivityLog.timestamp.desc()).limit(limit).all()
    return jsonify([{
        "id":          log.id,
        "timestamp":   log.timestamp.isoformat() + "Z",
        "event_type":  log.event_type,
        "description": log.description,
        "details":     log.details,
    } for log in logs])


@app.route('/api/automation/rules', methods=['GET', 'POST'])
def handle_automation_rules():
    if request.method == 'GET':
        rules = AutomationRule.query.all()
        return jsonify([{
            "id": r.id, "name": r.name,
            "sensor_target": r.sensor_target, "operator": r.operator,
            "threshold": r.threshold, "duration": r.duration,
            "actuator_target": r.actuator_target, "is_active": r.is_active,
            "last_triggered": r.last_triggered.isoformat() + "Z" if r.last_triggered else None,
        } for r in rules])

    data = request.json
    new_rule = AutomationRule(
        name=data.get('name'),
        sensor_target=data.get('sensor_target'),
        operator=data.get('operator'),
        threshold=data.get('threshold'),
        duration=data.get('duration'),
        actuator_target=data.get('actuator_target'),
        is_active=data.get('is_active', True),
    )
    db.session.add(new_rule)
    db.session.add(ActivityLog(event_type="System",
                               description="New automation rule created",
                               details=f"Rule: {new_rule.name}"))
    db.session.commit()
    return jsonify({"success": True, "id": new_rule.id}), 201


@app.route('/api/automation/rules/<int:rule_id>', methods=['PUT', 'DELETE'])
def handle_automation_rule(rule_id):
    rule = db.session.get(AutomationRule, rule_id)
    if not rule:
        return jsonify({"error": "Rule not found"}), 404

    if request.method == 'PUT':
        data = request.json
        for field in ('name', 'sensor_target', 'operator', 'threshold',
                      'duration', 'actuator_target', 'is_active'):
            if field in data:
                setattr(rule, field, data[field])
        db.session.add(ActivityLog(event_type="System",
                                   description="Automation rule updated",
                                   details=f"Rule ID: {rule.id}"))
        db.session.commit()
        return jsonify({"success": True})

    db.session.delete(rule)
    db.session.add(ActivityLog(event_type="System",
                               description="Automation rule deleted",
                               details=f"Rule ID: {rule.id}"))
    db.session.commit()
    return jsonify({"success": True})


@app.route('/api/settings', methods=['GET', 'PUT'])
def handle_settings():
    setting = AppSettings.query.first()
    if not setting:
        setting = AppSettings()
        db.session.add(setting)
        db.session.commit()

    if request.method == 'GET':
        return jsonify({
            "user_name":              setting.user_name,
            "user_role":              setting.user_role,
            "avatar_url":             setting.avatar_url,
            "wifi_signal":            setting.wifi_signal,
            "firmware_version":       setting.firmware_version,
            "ip_address":             setting.ip_address,
            "api_key":                setting.api_key,
            "notif_critical_alert":   setting.notif_critical_alert,
            "notif_daily_report":     setting.notif_daily_report,
            "notif_haptic_feedback":  setting.notif_haptic_feedback,
            "notif_high_contrast":    setting.notif_high_contrast,
        })

    data = request.json
    for field in ('user_name', 'user_role', 'avatar_url',
                  'notif_critical_alert', 'notif_daily_report',
                  'notif_haptic_feedback', 'notif_high_contrast'):
        if field in data:
            setattr(setting, field, data[field])

    if data.get('regenerate_api_key') is True:
        setting.api_key = "live_sec_agri_" + secrets.token_hex(4)

    db.session.commit()
    return jsonify({"success": True, "api_key": setting.api_key})


@app.route('/api/upload_avatar', methods=['POST'])
def upload_avatar():
    if 'avatar' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    file = request.files['avatar']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    filename = secure_filename(file.filename)
    filename = f"{int(time.time())}_{filename}"
    file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
    url = request.host_url + 'static/uploads/' + filename
    return jsonify({'url': url})


# =====================================================================
#  5. AI MODEL ENDPOINTS
# =====================================================================
@app.route('/api/ai/model', methods=['POST'])
def upload_ai_model():
    """Upload bobot dari Colab. Body: {device_id, W1,B1,W2,B2, max_out?, r2?}."""
    data = request.json or {}
    device_id = data.get('device_id', 'esp32_greenhouse_01')

    required = ('W1', 'B1', 'W2', 'B2')
    if not all(k in data for k in required):
        return jsonify({"error": f"Body harus punya {required}"}), 400

    try:
        W1, B1 = data['W1'], data['B1']
        W2, B2 = data['W2'], data['B2']
        assert len(W1) == ai_model.N_HID and len(W1[0]) == ai_model.N_IN
        assert len(B1) == ai_model.N_HID
        assert len(W2) == ai_model.N_OUT and len(W2[0]) == ai_model.N_HID
        assert len(B2) == ai_model.N_OUT
    except (AssertionError, IndexError, TypeError):
        return jsonify({"error": "Dimensi bobot tidak valid"}), 400

    last = (AIModel.query.filter_by(device_id=device_id)
            .order_by(AIModel.version.desc()).first())
    new_ver = (last.version + 1) if last else 1

    row = AIModel(
        device_id=device_id, version=new_ver,
        W1_json=_json.dumps(W1), B1_json=_json.dumps(B1),
        W2_json=_json.dumps(W2), B2_json=_json.dumps(B2),
        max_out_json=_json.dumps(data.get('max_out', [200, 200, 30, 30])),
        r2=float(data.get('r2', 0.0)),
        source=data.get('source', 'colab'),
    )
    db.session.add(row)
    db.session.commit()

    _load_ai_model_for(device_id)

    db.session.add(ActivityLog(
        event_type="AI",
        description=f"Model AI v{new_ver} diupload",
        details=f"device={device_id} r2={row.r2:.3f}",
    ))
    db.session.commit()

    return jsonify({"success": True, "version": new_ver})


@app.route('/api/ai/model', methods=['GET'])
def get_ai_model():
    """ESP32 unduh bobot terbaru bila versi berbeda."""
    device_id = request.args.get('device_id', 'esp32_greenhouse_01')
    row = (AIModel.query.filter_by(device_id=device_id)
           .order_by(AIModel.version.desc()).first())
    if not row:
        return jsonify({"error": "Model belum tersedia"}), 404
    return jsonify({
        "device_id": device_id,
        "version":   row.version,
        "W1": _json.loads(row.W1_json),
        "B1": _json.loads(row.B1_json),
        "W2": _json.loads(row.W2_json),
        "B2": _json.loads(row.B2_json),
        "max_out": _json.loads(row.max_out_json) if row.max_out_json else [200, 200, 30, 30],
        "r2": row.r2,
    })


@app.route('/api/ai/model', methods=['DELETE'])
def delete_ai_models():
    """Reset semua model device (debug)."""
    device_id = request.args.get('device_id', 'esp32_greenhouse_01')
    n = AIModel.query.filter_by(device_id=device_id).delete()
    db.session.commit()
    ai_model.clear_cache()
    return jsonify({"deleted": n})


@app.route('/api/ai/mode', methods=['GET', 'PUT'])
def ai_mode_endpoint():
    """Baca/ubah mode AI + phase + ec_setpoint."""
    device_id = request.args.get('device_id', 'esp32_greenhouse_01')

    if request.method == 'GET':
        d = db.session.get(DeviceState, device_id)
        if not d:
            return jsonify({"error": "Device tidak ditemukan"}), 404
        return jsonify({
            "ai_mode":       d.ai_mode,
            "phase":         d.phase,
            "ec_setpoint":   d.ec_setpoint,
            "model_version": ai_model.current_version(device_id),
        })

    data = request.json or {}
    d = db.session.get(DeviceState, device_id)
    if not d:
        return jsonify({"error": "Device tidak ditemukan"}), 404

    if 'ai_mode' in data:
        if data['ai_mode'] not in ('off', 'shadow', 'auto', 'manual'):
            return jsonify({"error": "ai_mode harus off|shadow|auto|manual"}), 400
        d.ai_mode = data['ai_mode']
    if 'phase' in data:
        d.phase = max(0, min(3, int(data['phase'])))
    if 'ec_setpoint' in data:
        d.ec_setpoint = float(data['ec_setpoint'])

    db.session.commit()
    return jsonify({
        "success": True,
        "ai_mode":     d.ai_mode,
        "phase":       d.phase,
        "ec_setpoint": d.ec_setpoint,
    })


@app.route('/api/ai/dose', methods=['GET'])
def list_ai_doses():
    """Riwayat dosis AI/expert dengan filter, sort, dan pagination."""
    device_id   = request.args.get('device_id', 'esp32_greenhouse_01')
    limit       = int(request.args.get('limit', 50))
    filter_src  = request.args.get('src')           # 'ai' | 'expert' | 'expert_shadow'
    sort_by     = request.args.get('sort', 'desc')  # 'desc' | 'asc'
    date_from   = request.args.get('date_from')     # ISO8601
    date_to     = request.args.get('date_to')       # ISO8601

    q = DoseLog.query.filter_by(device_id=device_id)

    if filter_src:
        q = q.filter(DoseLog.src == filter_src)
    if date_from:
        try:
            q = q.filter(DoseLog.timestamp >= datetime.fromisoformat(date_from))
        except ValueError:
            pass
    if date_to:
        try:
            q = q.filter(DoseLog.timestamp <= datetime.fromisoformat(date_to))
        except ValueError:
            pass

    if sort_by == 'asc':
        q = q.order_by(DoseLog.timestamp.asc())
    else:
        q = q.order_by(DoseLog.timestamp.desc())

    rows = q.limit(limit).all()

    return jsonify([{
        "id":        r.id,
        "timestamp": r.timestamp.isoformat() + "Z",
        "src":       r.src,
        "phase":     r.phase,
        "x":         _json.loads(r.x_json or "[]"),
        "ml":        _json.loads(r.ml_json or "{}"),
        "ai_ml":     _json.loads(r.ai_ml_json) if r.ai_ml_json else None,
        "rating":    r.rating,
    } for r in rows])


@app.route('/api/ai/dose', methods=['DELETE'])
def clear_ai_doses():
    """Hapus riwayat dosis. Opsional: filter berdasarkan src atau sebelum tanggal."""
    device_id     = request.args.get('device_id', 'esp32_greenhouse_01')
    filter_src    = request.args.get('src')        # hanya hapus src tertentu
    before_date   = request.args.get('before')     # ISO8601, hapus sebelum tanggal ini

    q = DoseLog.query.filter_by(device_id=device_id)
    if filter_src:
        q = q.filter(DoseLog.src == filter_src)
    if before_date:
        try:
            q = q.filter(DoseLog.timestamp <= datetime.fromisoformat(before_date))
        except ValueError:
            pass

    deleted = q.delete()
    db.session.commit()
    return jsonify({"success": True, "deleted": deleted})


@app.route('/api/ai/dose/<int:log_id>', methods=['PATCH'])
def rate_ai_dose(log_id):
    """Petani menilai dosis: body {"good": true|false}."""
    data = request.json or {}
    good = bool(data.get('good', False))
    row  = db.session.get(DoseLog, log_id)
    if not row:
        return jsonify({"error": "Log tidak ditemukan"}), 404
    row.rating = 1 if good else -1
    db.session.commit()
    return jsonify({"success": True, "rating": row.rating})


@app.route('/api/ai/latest-dose', methods=['GET'])
def get_latest_ai_dose():
    """Ambil rekomendasi AI terbaru dari model tanpa eksekusi."""
    device_id = request.args.get('device_id', 'esp32_greenhouse_01')
    device = db.session.get(DeviceState, device_id)
    if not device:
        return jsonify({"error": "Device tidak ditemukan"}), 404

    _load_ai_model_for(device_id)
    if not ai_model.has_model(device_id):
        return jsonify({"error": "Model AI belum dimuat"}), 404

    x_vec = ai_model.build_features(
        sensor={
            "ec": device.ec, "ph": device.ph,
            "tanah_lembap": device.tanah_lembap,
            "air_suhu": device.air_suhu,
        },
        phase=device.phase,
        ec_setpoint=device.ec_setpoint or 2.0,
    )
    # Always compute in 'auto' mode to get raw AI values
    result = ai_model.decide(x_vec, 'auto', True)
    _src, ml_exec = result

    return jsonify({
        "phase":   device.phase,
        "A":       round(ml_exec[0], 2),
        "B":       round(ml_exec[1], 2),
        "PH_UP":   round(ml_exec[2], 2),
        "PH_DOWN": round(ml_exec[3], 2),
        "sensors": {
            "ec": device.ec, "ph": device.ph,
            "tanah_lembap": device.tanah_lembap,
            "air_suhu": device.air_suhu,
        }
    })


# Relay index mapping: 0-indexed (Sinkron dengan firmware ESP32)
# Relay 1 (idx 0) = Dosing Nutrisi A
# Relay 2 (idx 1) = Dosing Nutrisi B
# Relay 3 (idx 2) = pH Up
# Relay 4 (idx 3) = pH Down
# Relay 5 (idx 4) = Exhaust Blower
# Relay 6 (idx 5) = Pompa Irigasi
_DOSING_HEAD_RELAY = {
    "A":       0,
    "B":       1,
    "PH_UP":   2,
    "PH_DOWN": 3,
}


@app.route('/api/ai/relay/run', methods=['POST'])
def run_dosing_head():
    """
    Eksekusi manual satu head dosing dari Flutter.
    Body: { device_id, head: "A"|"B"|"PH_UP"|"PH_DOWN", duration_sec: int }
    Mengeset target relay ON selama duration_sec detik, lalu OFF.
    """
    data = request.json or {}
    device_id    = data.get('device_id', 'esp32_greenhouse_01')
    head         = data.get('head', '')
    duration_sec = int(data.get('duration_sec', 10))

    if head not in _DOSING_HEAD_RELAY:
        return jsonify({"error": f"head harus salah satu dari {list(_DOSING_HEAD_RELAY)}"}), 400

    device = db.session.get(DeviceState, device_id)
    if not device:
        return jsonify({"error": "Device tidak ditemukan"}), 404

    relay_idx = _DOSING_HEAD_RELAY[head]
    targets = device.target_relay_state

    # Nyalakan relay
    targets[relay_idx] = True
    device.target_relay_state = targets
    device.target_relay_state_updated = datetime.utcnow()

    db.session.add(ActivityLog(
        event_type="AI_Manual",
        description=f"Manual Run Head {head}",
        details=f"device={device_id} relay={relay_idx+1} duration={duration_sec}s",
    ))
    db.session.commit()

    # Jadwalkan OFF setelah durasi menggunakan threading
    import threading
    def _turn_off():
        import time as _time
        _time.sleep(duration_sec)
        with app.app_context():
            dev = db.session.get(DeviceState, device_id)
            if dev:
                t = dev.target_relay_state
                t[relay_idx] = False
                dev.target_relay_state = t
                db.session.commit()

    threading.Thread(target=_turn_off, daemon=True).start()

    return jsonify({
        "success":      True,
        "head":         head,
        "relay_index":  relay_idx,
        "duration_sec": duration_sec,
        "message":      f"Relay {relay_idx+1} ({head}) ON selama {duration_sec} detik"
    })


@app.route('/api/ai/status', methods=['GET'])
def ai_status():
    """Status ringkas model AI untuk device."""
    device_id = request.args.get('device_id', 'esp32_greenhouse_01')
    last = (AIModel.query.filter_by(device_id=device_id)
            .order_by(AIModel.version.desc()).first())

    n_total = DoseLog.query.filter_by(device_id=device_id).count()
    n_good  = DoseLog.query.filter_by(device_id=device_id, rating=1).count()

    return jsonify({
        "model_loaded":     ai_model.has_model(device_id),
        "cached_version":   ai_model.current_version(device_id),
        "db_version":       last.version if last else 0,
        "db_r2":            last.r2 if last else None,
        "db_created_at":    last.created_at.isoformat() + "Z" if last else None,
        "dose_logs_total":  n_total,
        "dose_logs_good":   n_good,
        "ready_for_retrain": n_good >= 20,
    })

# =====================================================================
#  5b. AI PERFORMANCE ANALYSIS ENDPOINTS
# =====================================================================
def _compute_ai_performance(device_id, hours=24):
    """Hitung metrik performa AI dari dose_logs (shadow mode)."""
    now = datetime.utcnow()
    period_end = now
    period_start = now - timedelta(hours=hours)

    logs = (DoseLog.query
            .filter_by(device_id=device_id)
            .filter(DoseLog.ai_ml_json.isnot(None))
            .filter(DoseLog.timestamp >= period_start)
            .filter(DoseLog.timestamp <= period_end)
            .order_by(DoseLog.timestamp.asc())
            .all())

    heads = ["A", "B", "PH_UP", "PH_DOWN"]
    max_vals = {"A": 200.0, "B": 200.0, "PH_UP": 30.0, "PH_DOWN": 30.0}

    if not logs:
        return None

    errors = {h: [] for h in heads}

    for log in logs:
        try:
            expert_ml = _json.loads(log.ml_json or "{}")
            ai_ml = _json.loads(log.ai_ml_json or "[]")
            if isinstance(ai_ml, list) and len(ai_ml) >= 4:
                for i, h in enumerate(heads):
                    ev = float(expert_ml.get(h, 0))
                    av = float(ai_ml[i])
                    errors[h].append(ev - av)
        except (ValueError, KeyError, TypeError):
            continue

    n_samples = len(errors[heads[0]])
    if n_samples == 0:
        return None

    stats = {}
    total_score = 0.0
    for h in heads:
        errs = errors[h]
        abs_errs = [abs(e) for e in errs]
        mae = sum(abs_errs) / len(abs_errs)
        rmse = (sum(e ** 2 for e in errs) / len(errs)) ** 0.5
        # Skor: normalize MAE terhadap max_output,
        # 0% error → 100, ≥20% error → 0
        norm_mae = mae / max_vals[h] if max_vals[h] > 0 else 0
        score = max(0.0, min(100.0, 100.0 * (1.0 - norm_mae * 5.0)))
        stats[h] = {
            "mae": round(mae, 2),
            "rmse": round(rmse, 2),
            "score": round(score, 1),
        }
        total_score += score

    overall_score = round(total_score / len(heads), 1)

    if overall_score >= 85:
        verdict = "excellent"
    elif overall_score >= 70:
        verdict = "good"
    elif overall_score >= 50:
        verdict = "fair"
    else:
        verdict = "poor"

    # Rekomendasi
    recs = []
    if verdict == "poor":
        recs.append("Model AI perlu di-retrain dengan data terbaru.")
    elif verdict == "fair":
        recs.append("Pertimbangkan retrain model untuk meningkatkan akurasi.")

    worst = min(stats, key=lambda h: stats[h]["score"])
    if stats[worst]["score"] < 70:
        recs.append(
            f"Head {worst} paling lemah (skor {stats[worst]['score']}), "
            f"MAE={stats[worst]['mae']:.1f} mL — perlu perhatian."
        )

    if n_samples < 20:
        recs.append(
            f"Baru {n_samples} sampel shadow. "
            f"Jalankan mode shadow lebih lama untuk analisa akurat."
        )

    if not recs:
        recs.append("Model AI bekerja baik. Lanjutkan monitoring.")

    return {
        "period_start": period_start,
        "period_end": period_end,
        "window_hours": hours,
        "stats": stats,
        "n_samples": n_samples,
        "overall_score": overall_score,
        "verdict": verdict,
        "recommendation": " ".join(recs),
    }


@app.route('/api/ai/performance', methods=['GET'])
def get_ai_performance():
    """Hitung performa AI real-time (tanpa menyimpan)."""
    device_id = request.args.get('device_id', 'esp32_greenhouse_01')
    hours = int(request.args.get('hours', 24))

    result = _compute_ai_performance(device_id, hours)
    if result is None:
        return jsonify({
            "error": "Belum ada data shadow untuk window ini",
            "n_samples": 0,
        }), 404

    return jsonify({
        "device_id":    device_id,
        "period_start": result["period_start"].isoformat() + "Z",
        "period_end":   result["period_end"].isoformat() + "Z",
        "window_hours": result["window_hours"],
        "stats":        result["stats"],
        "n_samples":    result["n_samples"],
        "overall_score": result["overall_score"],
        "verdict":      result["verdict"],
        "recommendation": result["recommendation"],
    })


@app.route('/api/ai/performance/history', methods=['GET'])
def get_ai_performance_history():
    """Riwayat analisa performa yang sudah tersimpan."""
    device_id = request.args.get('device_id', 'esp32_greenhouse_01')
    limit = int(request.args.get('limit', 20))

    rows = (AIPerformance.query
            .filter_by(device_id=device_id)
            .order_by(AIPerformance.timestamp.desc())
            .limit(limit).all())

    return jsonify([{
        "id":             r.id,
        "timestamp":      r.timestamp.isoformat() + "Z",
        "period_start":   r.period_start.isoformat() + "Z" if r.period_start else None,
        "period_end":     r.period_end.isoformat() + "Z" if r.period_end else None,
        "window_hours":   r.window_hours,
        "stats":          _json.loads(r.stats_json or "{}"),
        "n_samples":      r.n_samples,
        "overall_score":  r.overall_score,
        "verdict":        r.verdict,
        "recommendation": r.recommendation,
    } for r in rows])


@app.route('/api/ai/performance/compute', methods=['POST'])
def compute_ai_performance():
    """Trigger komputasi manual & simpan ke tabel ai_performance."""
    data = request.json or {}
    device_id = data.get('device_id', 'esp32_greenhouse_01')
    hours = int(data.get('hours', 24))

    result = _compute_ai_performance(device_id, hours)
    if result is None:
        return jsonify({
            "error": "Tidak ada data shadow untuk dihitung",
            "n_samples": 0,
        }), 404

    row = AIPerformance(
        device_id=device_id,
        period_start=result["period_start"],
        period_end=result["period_end"],
        window_hours=result["window_hours"],
        stats_json=_json.dumps(result["stats"]),
        n_samples=result["n_samples"],
        overall_score=result["overall_score"],
        verdict=result["verdict"],
        recommendation=result["recommendation"],
    )
    db.session.add(row)
    db.session.add(ActivityLog(
        event_type="AI",
        description=f"Analisa performa AI dihitung ({result['verdict']})",
        details=f"device={device_id} score={result['overall_score']} "
                f"samples={result['n_samples']} window={hours}h",
    ))
    db.session.commit()

    return jsonify({
        "success": True,
        "id":             row.id,
        "device_id":      device_id,
        "period_start":   result["period_start"].isoformat() + "Z",
        "period_end":     result["period_end"].isoformat() + "Z",
        "window_hours":   result["window_hours"],
        "stats":          result["stats"],
        "n_samples":      result["n_samples"],
        "overall_score":  result["overall_score"],
        "verdict":        result["verdict"],
        "recommendation": result["recommendation"],
    }), 201



if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    _warmup_ai_cache()
    app.run(
        host=os.environ.get('HOST', '0.0.0.0'),
        port=int(os.environ.get('PORT', '5000')),
        debug=os.environ.get('FLASK_DEBUG', '0') == '1',
    )