from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import json

db = SQLAlchemy()

class DeviceState(db.Model):
    __tablename__ = 'device_state'
    id = db.Column(db.String(50), primary_key=True) # e.g. "esp32_greenhouse_01"
    
    # Air
    air_suhu = db.Column(db.Float, default=0.0)
    air_hum = db.Column(db.Float, default=0.0)
    
    # Soil
    tanah_suhu = db.Column(db.Float, default=0.0)
    tanah_lembap = db.Column(db.Float, default=0.0)
    ph = db.Column(db.Float, default=0.0)
    ec = db.Column(db.Float, default=0.0)
    n = db.Column(db.Integer, default=0)
    p = db.Column(db.Integer, default=0)
    k = db.Column(db.Integer, default=0)
    soil_ok = db.Column(db.Boolean, default=False)
    
    # AI Feature Support
    ai_mode = db.Column(db.String(20), default='off') # 'off', 'shadow', 'auto'
    phase = db.Column(db.Integer, default=0)
    ec_setpoint = db.Column(db.Float, default=2.0)
    
    # System
    uptime = db.Column(db.Integer, default=0)
    last_seen = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relay Current State (as reported by ESP32)
    # Stored as JSON string: "[false, false, false, false, false, false]"
    relay_state_json = db.Column(db.Text, default='[false, false, false, false, false, false]')
    
    # Target Relay State (commanded by Flutter/Automation)
    target_relay_state_json = db.Column(db.Text, default='[false, false, false, false, false, false]')

    @property
    def relay_state(self):
        return json.loads(self.relay_state_json)

    @relay_state.setter
    def relay_state(self, val):
        self.relay_state_json = json.dumps(val)

    @property
    def target_relay_state(self):
        return json.loads(self.target_relay_state_json)

    @target_relay_state.setter
    def target_relay_state(self, val):
        self.target_relay_state_json = json.dumps(val)


class Telemetry(db.Model):
    __tablename__ = 'telemetry'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    device_id = db.Column(db.String(50), db.ForeignKey('device_state.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    
    air_suhu = db.Column(db.Float)
    air_hum = db.Column(db.Float)
    tanah_suhu = db.Column(db.Float)
    tanah_lembap = db.Column(db.Float)
    ph = db.Column(db.Float)
    ec = db.Column(db.Float)
    n = db.Column(db.Integer)
    p = db.Column(db.Integer)
    k = db.Column(db.Integer)


class AutomationRule(db.Model):
    __tablename__ = 'automation_rule'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(100))
    sensor_target = db.Column(db.String(50)) # e.g. "ph", "suhu"
    operator = db.Column(db.String(5))       # e.g. "<", ">", "="
    threshold = db.Column(db.Float)
    duration = db.Column(db.Integer)         # in seconds
    actuator_target = db.Column(db.Integer)  # Relay index 0-5
    is_active = db.Column(db.Boolean, default=True)
    
    # Cooldown logic (optional future expansion, keep it simple for now)
    last_triggered = db.Column(db.DateTime, nullable=True)


class ActivityLog(db.Model):
    __tablename__ = 'activity_log'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    event_type = db.Column(db.String(50)) # "Automation", "Manual", "System", "AI"
    description = db.Column(db.String(255))
    details = db.Column(db.Text, nullable=True)


class AppSettings(db.Model):
    __tablename__ = 'app_settings'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    # Profile
    user_name = db.Column(db.String(100), default="Ir. Sarah Jenkins")
    user_role = db.Column(db.String(100), default="Kepala Agronomist - Greenhouse Tech")
    avatar_url = db.Column(db.Text, default="https://lh3.googleusercontent.com/aida-public/AB6AXuBSm_-JCeBJPLykbjXLD5-lpnte3f7Lt8m_kkB2xp9MBcjPky4feLj1OPSSgIeH-pkeumQhLY6ld0SnXId_HFT2v8JFSAdR02zVhMLjBYfAB8XsmxDg4zopulvtEKjI8cURb2GydDmLtzjY--eEKvGd9SSlrczth5u9BxzjZ539OYxA5YKmPp08X-44Sbm9i14r9nOSk1g86KAKbFPAMOwrf0a6t3SPMQ9Kgskc1L7PObBer-7Sedwu")
    
    # Hardware
    wifi_signal = db.Column(db.String(50), default="-58 dBm")
    firmware_version = db.Column(db.String(50), default="v2.4.1-rc")
    ip_address = db.Column(db.String(50), default="192.168.1.145")
    api_key = db.Column(db.String(100), default="live_sec_agri_89f2")
    
    # Notifications
    notif_critical_alert = db.Column(db.Boolean, default=True)
    notif_daily_report = db.Column(db.Boolean, default=True)
    notif_haptic_feedback = db.Column(db.Boolean, default=True)
    notif_high_contrast = db.Column(db.Boolean, default=False)


class AIModel(db.Model):
    __tablename__ = 'ai_model'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    device_id = db.Column(db.String(50), db.ForeignKey('device_state.id'))
    version = db.Column(db.Integer, nullable=False)
    W1_json = db.Column(db.Text, nullable=False)
    B1_json = db.Column(db.Text, nullable=False)
    W2_json = db.Column(db.Text, nullable=False)
    B2_json = db.Column(db.Text, nullable=False)
    max_out_json = db.Column(db.Text, nullable=True)
    r2 = db.Column(db.Float, default=0.0)
    source = db.Column(db.String(50), default='colab')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class DoseLog(db.Model):
    __tablename__ = 'dose_log'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    device_id = db.Column(db.String(50), db.ForeignKey('device_state.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    src = db.Column(db.String(20)) # e.g. "expert", "ai"
    phase = db.Column(db.Integer)
    x_json = db.Column(db.Text)
    ml_json = db.Column(db.Text)
    ai_ml_json = db.Column(db.Text, nullable=True)
    rating = db.Column(db.Integer, default=0) # -1, 0, 1


class AIPerformance(db.Model):
    __tablename__ = 'ai_performance'

    id         = db.Column(db.Integer, primary_key=True)
    device_id  = db.Column(db.String(64), db.ForeignKey('device_state.id'),
                           nullable=False, index=True)
    timestamp  = db.Column(db.DateTime, default=datetime.utcnow, index=True)

    period_start = db.Column(db.DateTime)
    period_end   = db.Column(db.DateTime)
    window_hours = db.Column(db.Float)

    stats_json     = db.Column(db.Text)   # JSON: statistik per head
    n_samples      = db.Column(db.Integer)
    overall_score  = db.Column(db.Float)      # 0..100
    verdict        = db.Column(db.String(32)) # excellent|good|fair|poor
    recommendation = db.Column(db.Text)

class ManualCommand(db.Model):
    __tablename__ = 'manual_command'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    device_id = db.Column(db.String(50), db.ForeignKey('device_state.id'))
    pump = db.Column(db.String(20))
    ml = db.Column(db.Float)
    queued_at = db.Column(db.DateTime, default=datetime.utcnow)
    status = db.Column(db.String(20), default='pending') # pending, executed, failed
