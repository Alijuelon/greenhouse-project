from database import db, AutomationRule, ActivityLog, DeviceState
from datetime import datetime
import json

def evaluate_rules(device_id: str):
    """
    Evaluates all active automation rules against the current state of a device.
    If a rule's condition is met, it updates the target_relay_state and logs the activity.
    """
    device = db.session.get(DeviceState, device_id)
    if not device:
        return

    active_rules = AutomationRule.query.filter_by(is_active=True).all()
    if not active_rules:
        return

    target_relay = device.target_relay_state
    state_changed = False

    for rule in active_rules:
        # Get the sensor value from the device state based on rule.sensor_target
        # Example sensor targets: "ph", "air_suhu", "tanah_lembap", "ec"
        try:
            sensor_value = getattr(device, rule.sensor_target.lower())
        except AttributeError:
            continue # Invalid sensor target

        if sensor_value is None:
            continue

        condition_met = False
        if rule.operator == '<':
            condition_met = sensor_value < rule.threshold
        elif rule.operator == '>':
            condition_met = sensor_value > rule.threshold
        elif rule.operator == '=':
            condition_met = sensor_value == rule.threshold

        if condition_met:
            # Check cooldown or simply trigger
            # For simplicity, if we trigger, we turn the relay ON.
            # (In a real system, we'd schedule it to turn OFF after `duration` seconds.
            # Here we just set it to True, and assume a separate task or the ESP32 handles duration,
            # or we turn it off on the next pass if condition no longer met).
            # To keep it simple: if met, relay ON. 
            
            relay_index = rule.actuator_target
            if 0 <= relay_index < 6:
                if not target_relay[relay_index]:
                    target_relay[relay_index] = True
                    state_changed = True
                    
                    # Log the activity
                    log = ActivityLog(
                        event_type="Automation",
                        description=f"Rule '{rule.name}' triggered",
                        details=f"{rule.sensor_target} {rule.operator} {rule.threshold} (Actual: {sensor_value}). Relay {relay_index} turned ON for {rule.duration}s."
                    )
                    db.session.add(log)
                    
                    rule.last_triggered = datetime.utcnow()

    # Note: Turning relays OFF when conditions are NOT met is a common pattern for thermostats, 
    # but for dosing, it's usually a one-shot duration.
    # For now, we just implement the trigger-ON logic. 

    if state_changed:
        device.target_relay_state = target_relay
        db.session.commit()
