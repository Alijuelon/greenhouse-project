// ===================================================================
//  DASHBOARD GREEN HOUSE v7.3 — WiFi + Flask AI + Manual + Buffer
//  DHT11 + Soil 7-in-1 (RS485) + Relay 6ch + TFT ILI9488 + AI Dose OTA
// ===================================================================
//  MODE OPERASI:
//    off    → expert rule (relay target dari server)
//    shadow → expert eksekusi, AI cuma dicatat
//    auto   → AI eksekusi penuh (dengan safety delay)
//    manual → tunggu perintah user dari Flask API
// ===================================================================
//  MANUAL MODE — endpoint Flask yang dipakai:
//    ESP32 polling /api/sensor → response berisi manual_commands[]
//    ESP32 eksekusi → POST /api/manual/ack {id, ok}
// ===================================================================

#include "DHT.h"
#include <ArduinoJson.h>
#include <ModbusMaster.h>
#include <HardwareSerial.h>
#include <SPI.h>
#include <TFT_eSPI.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <math.h>
#include "model_weights.h"

// ---- Guard ----
#ifndef MODEL_TRAINED
  #define MODEL_TRAINED 0
#endif
#ifndef N_IN
  #define N_IN  8
  #define N_HID 10
  #define N_OUT 4
#endif
#ifndef MAX_A
  #define MAX_A       200.0f
  #define MAX_B       200.0f
  #define MAX_PH_UP   30.0f
  #define MAX_PH_DOWN 30.0f
#endif

// ===================== DEBUG =====================
#define DEBUG_RAW_SOIL  1
#define DEBUG_SAMPLE    1
#define DEBUG_MANUAL    1

// ===================== KONFIGURASI WIFI =====================
const char* WIFI_SSID     = "Selese_3";
const char* WIFI_PASSWORD = "Seleseselese";

// ===================== KONFIGURASI FLASK API =====================
// Server produksi (hosting HTTPS). Ganti ke "http://192.168.0.151:5000"
// bila ingin memakai server Flask di LAN saat pengembangan.
const char* API_HOST          = "https://api-greenhouse.andanafarm.web.id";
const char* API_URL           = "https://api-greenhouse.andanafarm.web.id/api/sensor";
const char* API_MODEL_URL     = "https://api-greenhouse.andanafarm.web.id/api/ai/model";
const char* API_MANUAL_ACK    = "https://api-greenhouse.andanafarm.web.id/api/manual/ack";
const char* API_KEY           = "live_sec_agri_46d0bb18";
const char* DEVICE_ID         = "esp32_greenhouse_01";

// ===================== TLS / HTTPS =====================
// Server memakai HTTPS, jadi HTTPClient WAJIB diberi WiFiClientSecure.
//   1 = setInsecure()  → TIDAK memvalidasi sertifikat. Paling praktis,
//                        tetap terenkripsi (tidak bisa disadap), tapi bisa
//                        diarahkan ke server palsu (MITM).
//   0 = setCACert()    → validasi penuh rantai sertifikat sampai
//                        ISRG Root X1 (Let's Encrypt). Lebih aman.
#define TLS_INSECURE 1

// Sertifikat root Let's Encrypt (ISRG Root X1) — hanya dipakai bila TLS_INSECURE 0.
static const char ISRG_ROOT_X1[] PROGMEM = R"ROOTCA(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
)ROOTCA";

// Helper: buka koneksi HTTP atau HTTPS secara otomatis.
// HTTPClient::begin(url) biasa TIDAK mendukung TLS, jadi untuk https://
// harus memakai WiFiClientSecure yang diberikan eksplisit.
void httpBegin(HTTPClient &http, const String &url) {
  if (url.startsWith("https://")) {
    static WiFiClientSecure tlsClient;
    static bool tlsReady = false;
    if (!tlsReady) {
#if TLS_INSECURE
      tlsClient.setInsecure();
      Serial.println("[TLS] Mode insecure (sertifikat tidak divalidasi)");
#else
      tlsClient.setCACert(ISRG_ROOT_X1);
      Serial.println("[TLS] Validasi sertifikat aktif (ISRG Root X1)");
#endif
      tlsReady = true;
    }
    http.begin(tlsClient, url);
  } else {
    http.begin(url);
  }
}

// ===================== PERANGKAT =====================
#define DHTPIN            13
#define DHTTYPE           DHT11
#define SENSOR_BAUD       4800
#define SENSOR_SLAVE_ID   1
#define MAX485_RE_DE      25
#define LED_HIJAU         19

// ===================== KONFIGURASI LAYAR TFT =====================
// Rotasi layar ILI9488 (nilai 0..3, karena 360° = 0°):
//   0 = portrait          1 = landscape (nilai lama)
//   2 = portrait 180°     3 = landscape 180°  ← dipakai (LCD terpasang terbalik)
// Kalau tampilan masih terbalik/berbeda, cukup ubah angka di bawah ini saja.
#define TFT_ROTATION 3

// ===================== OBJEK =====================
DHT dht(DHTPIN, DHTTYPE);
HardwareSerial SerialPort(2);
ModbusMaster node;
TFT_eSPI tft = TFT_eSPI();
Preferences prefs;

// ===================== WARNA =====================
#define BG_COLOR       0x0861
#define CARD_BG        0x18E3
#define CARD_LINE      0x39E7
#define TEXT_WHITE     0xFFFF
#define TEXT_GREY      0x8410
#define TEXT_DIM       0x4A49
#define C_CYAN         0x07FF
#define C_GREEN        0x4FEA
#define C_ORANGE       0xFDA0
#define C_PURPLE       0xB81F
#define C_YELLOW       0xFFE0
#define C_RED          0xF9C6
#define C_BLUE         0x4D7F
#define C_TEAL         0x2E7F

// ===================== RELAY =====================
const int relayPins[6] = {22, 21, 5, 14, 27, 26};
bool relayState[6]     = {false, false, false, false, false, false};
const char* relayLabel[6] = {
  "Dosing A", "Dosing B", "pH Up", "pH Down", "Blower", "Pompa"
};

const float ML_PER_SEC[4] = {5.0f, 5.0f, 3.0f, 3.0f};
const unsigned long PUMP_MAX_DUR_MS = 60000UL;

// ===================== BUFFER & SAFETY =====================
#define SAMPLE_SIZE           5
#define SAMPLE_INTERVAL_MS    2000UL
#define SAFETY_DELAY_MS       5000UL
#define MIN_SAMPLES_TO_ACT    3
#define COOLDOWN_AFTER_ACT_MS 30000UL
#define STD_TOLERANCE_PCT     5.0f

// ===================== MANUAL MODE =====================
#define MANUAL_MAX_QUEUE      8          // max command sekaligus
#define MANUAL_COOLDOWN_MS    3000UL     // jeda antar command manual
#define MANUAL_MAX_ML         200.0f     // batas keras per command

const unsigned long DOSE_COOLDOWN_MS = 30000UL;

// ===================== DATA SENSOR =====================
float dhtTemp = NAN, dhtHum = NAN;
float soilMoist = NAN, soilTemp = NAN;
float soilPH = NAN, soilEC = NAN;
int   soilN = 0, soilP = 0, soilK = 0;
bool  soilOk = false;
uint8_t lastSoilErr = 0;
int soilOkCount = 0, soilFailCount = 0;

// ===================== WIFI/API STATE =====================
bool wifiConnected = false;
int  httpOkCount = 0;
int  httpFailCount = 0;
String lastHttpStatus = "idle";
bool prevWifiStatus = false;

// ===================== AI MODEL STATE =====================
int    local_model_version = 0;
int    server_model_version = 0;
String current_ai_mode = "off";
int    current_phase = 1;
String last_dose_src = "none";
float  last_dose_ml[4] = {0, 0, 0, 0};

float W1_act[N_HID][N_IN]   = {{0}};
float B1_act[N_HID]         = {0};
float W2_act[N_OUT][N_HID]  = {{0}};
float B2_act[N_OUT]         = {0};

// ===================== BUFFER SENSOR =====================
struct SensorSample {
  float air_suhu, air_hum;
  float tanah_suhu, tanah_lembap;
  float ph, ec;
  int   n, p, k;
  bool  valid;
};
SensorSample sampleBuf[SAMPLE_SIZE];
int  sampleCount = 0;
unsigned long lastSampleMs = 0;

// ===================== PENDING DOSE (AUTO MODE) =====================
struct PendingDose {
  bool  active;
  float ml[4];
  String src;
  unsigned long set_at;
};
PendingDose pending = { false, {0,0,0,0}, "", 0 };
unsigned long last_act_ms = 0;

// ===================== MANUAL COMMAND QUEUE =====================
struct ManualCommand {
  int    id;           // ID dari server
  int    pump_idx;     // 0=A, 1=B, 2=PH_UP, 3=PH_DOWN, -1=STOP
  float  ml;
  unsigned long queued_at;
};
ManualCommand manualQueue[MANUAL_MAX_QUEUE];
int manualCount = 0;
unsigned long last_manual_exec_ms = 0;

// ===================== TIMING =====================
unsigned long lastDHTRead   = 0;
unsigned long lastWifiCheck = 0;
unsigned long lastClockTick = 0;
unsigned long uptimeSeconds = 0;

const unsigned long DHT_INTERVAL  = 2500;
const unsigned long WIFI_CHECK    = 5000;

// ===================== FORWARD DECLARATIONS =====================
void  preTransmission();
void  postTransmission();
float mapFloat(float x, float in_min, float in_max, float out_min, float out_max);
void  drawProgressBar(int x, int y, int w, int h, float pct, uint16_t color);
void  drawStatusLed(int x, int y, bool on, uint16_t onColor);

void  printBanner();
void  printDivider();
void  printSectionHeader(const char* s);
void  printSystemInfo();
void  printNetworkInfo();
void  printModelInfo();
void  printSensorStatus();
void  printAirData();
void  printSoilData();
void  printRelayStatus();
void  printQuickSummary();
void  printManualQueue();
void  printFullReport();

void  connectWiFi();
void  checkWiFi();

void  loadModelFromNVS();
void  useCompiledModel();
void  saveModelToNVS(int ver);
bool  fetchModelFromServer();

float medianOf(float arr[], int n);
void  computeStats(float arr[], int n, float& avg, float& stddev);
struct Summary;
Summary getSummary();
void  takeSample();
void  clearBuffer();

void  sendToFlaskAPI();
void  handleApiResponse(const String& response);
bool  sendManualAck(int command_id, bool success, const char* reason);

void  runPumpML(int idx, float ml);
void  executeDose(float mlA, float mlB, float mlUP, float mlDN);

void  setPendingDose(float mlA, float mlB, float mlUP, float mlDN, const String& src);
void  cancelPendingDose(const char* reason);
void  checkAndExecutePending();

int   mapPumpNameToIdx(const String& name);
void  parseManualCommands(JsonArray arr);
void  executeManualBatch();
void  emergencyStop(const char* reason);

void  readDHT11();
void  readSoilSensor();
void  setRelay(int idx, bool state);
void  handleSerialInput();

void  drawStaticLayout();
void  drawAllDynamic();
void  drawHeaderStatus();
void  drawAirCard();
void  drawSoilCards();
void  drawMiniValue(int x, int y, int w, int h, float val, int decimals,
                    uint16_t color, const char* unit);
void  drawRelayBox(int idx);
void  drawFooter();
void  drawCardFrame(int x, int y, int w, int h, const char* title, uint16_t accent);
void  drawMiniFrame(int x, int y, int w, int h, const char* title, uint16_t accent);

// ===================================================================
//  RS485 CALLBACK
// ===================================================================
void preTransmission()  { digitalWrite(MAX485_RE_DE, HIGH); delayMicroseconds(100); }
void postTransmission() { delayMicroseconds(100); digitalWrite(MAX485_RE_DE, LOW); }

// ===================================================================
//  HELPERS
// ===================================================================
float mapFloat(float x, float in_min, float in_max, float out_min, float out_max) {
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

void drawProgressBar(int x, int y, int w, int h, float pct, uint16_t color) {
  tft.drawRoundRect(x, y, w, h, h / 2, CARD_LINE);
  int fillW = (int)((w - 4) * constrain(pct, 0, 100) / 100.0f);
  if (fillW > 0) {
    tft.fillRoundRect(x + 2, y + 2, fillW, h - 4, (h - 4) / 2, color);
  }
}

void drawStatusLed(int x, int y, bool on, uint16_t onColor) {
  if (on) {
    tft.fillCircle(x, y, 4, onColor);
    tft.drawCircle(x, y, 4, TEXT_WHITE);
  } else {
    tft.fillCircle(x, y, 4, 0x3186);
    tft.drawCircle(x, y, 4, CARD_LINE);
  }
}

// ===================================================================
//  SERIAL MONITOR
// ===================================================================
void printBanner() {
  Serial.println();
  Serial.println("╔══════════════════════════════════════════════════════════╗");
  Serial.println("║   GREEN HOUSE MONITOR v7.3 — AI + Manual Control Ed.     ║");
  Serial.println("╚══════════════════════════════════════════════════════════╝");
}

void printDivider() { Serial.println("──────────────────────────────────────────────────────────"); }
void printSectionHeader(const char* s) { Serial.printf("\n▶ %s\n", s); }

void printSystemInfo() {
  printSectionHeader("SYSTEM INFO");
  Serial.printf("  Chip          : %s rev %d\n", ESP.getChipModel(), ESP.getChipRevision());
  Serial.printf("  CPU Freq      : %d MHz\n", ESP.getCpuFreqMHz());
  Serial.printf("  Free Heap     : %d bytes\n", ESP.getFreeHeap());
  Serial.printf("  Uptime        : %lu s\n", uptimeSeconds);
}

void printNetworkInfo() {
  printSectionHeader("NETWORK");
  if (wifiConnected) {
    Serial.printf("  WiFi SSID     : %s\n", WIFI_SSID);
    Serial.printf("  IP Address    : %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("  RSSI          : %d dBm\n", WiFi.RSSI());
    Serial.printf("  API Status    : %s  (OK:%d FAIL:%d)\n",
                  lastHttpStatus.c_str(), httpOkCount, httpFailCount);
  } else {
    Serial.println("  WiFi          : ✗ DISCONNECTED");
  }
}

void printModelInfo() {
  printSectionHeader("AI MODEL");
  Serial.printf("  Local version : %d\n", local_model_version);
  Serial.printf("  Server version: %d\n", server_model_version);
  Serial.printf("  AI Mode       : %s\n", current_ai_mode.c_str());
  Serial.printf("  Phase         : %d\n", current_phase);
  Serial.printf("  Last dose src : %s\n", last_dose_src.c_str());
  Serial.printf("  Last dose mL  : A=%.1f B=%.1f UP=%.1f DN=%.1f\n",
                last_dose_ml[0], last_dose_ml[1], last_dose_ml[2], last_dose_ml[3]);
}

void printSensorStatus() {
  printSectionHeader("SENSOR STATUS");
  Serial.printf("  DHT11         : %s\n",
                (!isnan(dhtTemp) && !isnan(dhtHum)) ? "✓ OK" : "✗ FAIL");
  if (soilOk) {
    Serial.printf("  Soil 7in1     : ✓ OK  (OK:%d FAIL:%d)\n", soilOkCount, soilFailCount);
  } else {
    Serial.printf("  Soil 7in1     : ✗ FAIL Err=0x%02X  (OK:%d FAIL:%d)\n",
                  lastSoilErr, soilOkCount, soilFailCount);
  }
  Serial.printf("  Buffer        : %d/%d sample\n", sampleCount, SAMPLE_SIZE);
}

void printAirData() {
  printSectionHeader("DHT11 — UDARA");
  if (!isnan(dhtTemp) && !isnan(dhtHum)) {
    Serial.printf("  Suhu          : %.1f °C\n", dhtTemp);
    Serial.printf("  Kelembapan    : %.1f %%RH\n", dhtHum);
  }
}

void printSoilData() {
  printSectionHeader("SOIL SENSOR — TANAH");
  if (!soilOk) return;
  Serial.printf("  Suhu Tanah    : %.1f °C\n", soilTemp);
  Serial.printf("  Kelembapan    : %.1f %%\n", soilMoist);
  Serial.printf("  pH            : %.2f\n", soilPH);
  Serial.printf("  EC            : %.0f µS/cm\n", soilEC);
  Serial.printf("  N/P/K         : %d / %d / %d mg/kg\n", soilN, soilP, soilK);
}

void printRelayStatus() {
  printSectionHeader("RELAY STATUS");
  for (int i = 0; i < 6; i++) {
    Serial.printf("  R%d %-12s : %s  (GPIO%d)\n",
                  i + 1, relayLabel[i], relayState[i] ? "ON " : "OFF", relayPins[i]);
  }
}

void printManualQueue() {
  printSectionHeader("MANUAL COMMAND QUEUE");
  Serial.printf("  Mode          : %s\n", current_ai_mode.c_str());
  Serial.printf("  Pending       : %d/%d\n", manualCount, MANUAL_MAX_QUEUE);
  for (int i = 0; i < manualCount; i++) {
    Serial.printf("  [%d] id=%d pump=%d ml=%.1f\n",
                  i, manualQueue[i].id, manualQueue[i].pump_idx, manualQueue[i].ml);
  }
}

void printQuickSummary() {
  printDivider();
  Serial.printf("[UP %5lus] ", uptimeSeconds);
  if (!isnan(dhtTemp)) Serial.printf("AIR:%.1fC/%.1f%% ", dhtTemp, dhtHum);
  if (soilOk) Serial.printf("SOIL:%.1fC/%.0f%% pH:%.1f EC:%.0f ",
                            soilTemp, soilMoist, soilPH, soilEC);
  Serial.printf("| BUF:%d/%d ", sampleCount, SAMPLE_SIZE);
  Serial.printf("| AI:%s v%d", current_ai_mode.c_str(), local_model_version);
  if (manualCount > 0) Serial.printf(" | MANUAL:%d", manualCount);
  Serial.printf(" | %s\n", lastHttpStatus.c_str());
}

void printFullReport() {
  printBanner();
  printSystemInfo();
  printNetworkInfo();
  printModelInfo();
  printSensorStatus();
  printAirData();
  printSoilData();
  printRelayStatus();
  printManualQueue();
  printDivider();
}

// ===================================================================
//  WIFI
// ===================================================================
void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) { wifiConnected = true; return; }

  Serial.printf("\n[WiFi] Connecting to '%s' ...\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
    delay(500); Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    Serial.printf("[WiFi] ✓ Connected! IP=%s RSSI=%d dBm\n",
                  WiFi.localIP().toString().c_str(), WiFi.RSSI());
  } else {
    wifiConnected = false;
    Serial.println("[WiFi] ✗ Gagal konek. Retry 5 detik.");
  }
}

void checkWiFi() {
  bool wasConnected = wifiConnected;
  wifiConnected = (WiFi.status() == WL_CONNECTED);
  if (!wifiConnected && wasConnected) {
    Serial.println("[WiFi] ⚠ Koneksi hilang, reconnect...");
  }
  if (!wifiConnected) connectWiFi();
}

// ===================================================================
//  AI MODEL — NVS & OTA
// ===================================================================
void loadModelFromNVS() {
  prefs.begin("model", true);
  int v = prefs.getInt("version", 0);
  size_t sz = prefs.getBytesLength("W1");
  if (v > 0 && sz == sizeof(W1_act)) {
    prefs.getBytes("W1", W1_act, sizeof(W1_act));
    prefs.getBytes("B1", B1_act, sizeof(B1_act));
    prefs.getBytes("W2", W2_act, sizeof(W2_act));
    prefs.getBytes("B2", B2_act, sizeof(B2_act));
    local_model_version = v;
    Serial.printf("[MODEL] Loaded v%d dari NVS\n", v);
  } else {
    Serial.println("[MODEL] NVS kosong / corrupt.");
  }
  prefs.end();
}

void useCompiledModel() {
#if MODEL_TRAINED
  memcpy(W1_act, W1_ai, sizeof(W1_act));
  memcpy(B1_act, B1_ai, sizeof(B1_act));
  memcpy(W2_act, W2_ai, sizeof(W2_act));
  memcpy(B2_act, B2_ai, sizeof(B2_act));
  local_model_version = 0;
  Serial.println("[MODEL] Pakai bobot compiled dari header");
#else
  Serial.println("[MODEL] Tidak ada model — fallback ke expert di server");
#endif
}

void saveModelToNVS(int ver) {
  prefs.begin("model", false);
  prefs.putInt("version", ver);
  prefs.putBytes("W1", W1_act, sizeof(W1_act));
  prefs.putBytes("B1", B1_act, sizeof(B1_act));
  prefs.putBytes("W2", W2_act, sizeof(W2_act));
  prefs.putBytes("B2", B2_act, sizeof(B2_act));
  prefs.end();
  local_model_version = ver;
  Serial.printf("[MODEL] Disimpan v%d ke NVS\n", ver);
}

bool fetchModelFromServer() {
  if (!wifiConnected) return false;
  HTTPClient http;
  String url = String(API_MODEL_URL) + "?device_id=" + DEVICE_ID;
  httpBegin(http, url);
  http.setTimeout(8000);
  if (strlen(API_KEY) > 0) http.addHeader("X-API-Key", API_KEY);
  int code = http.GET();
  if (code != 200) { http.end(); return false; }
  String resp = http.getString();
  http.end();

  DynamicJsonDocument doc(8192);
  if (deserializeJson(doc, resp)) return false;

  int newVer = doc["version"] | 0;
  JsonArray w1 = doc["W1"], b1 = doc["B1"], w2 = doc["W2"], b2 = doc["B2"];
  if ((int)w1.size() != N_HID || (int)w2.size() != N_OUT) return false;

  for (int j = 0; j < N_HID; j++) {
    for (int i = 0; i < N_IN; i++) W1_act[j][i] = w1[j][i].as<float>();
    B1_act[j] = b1[j].as<float>();
  }
  for (int k = 0; k < N_OUT; k++) {
    for (int j = 0; j < N_HID; j++) W2_act[k][j] = w2[k][j].as<float>();
    B2_act[k] = b2[k].as<float>();
  }
  saveModelToNVS(newVer);
  Serial.printf("[MODEL] ✓ Downloaded v%d dari server\n", newVer);
  return true;
}

// ===================================================================
//  BUFFER SAMPLING
// ===================================================================
float medianOf(float arr[], int n) {
  if (n <= 0) return 0;
  float tmp[SAMPLE_SIZE];
  for (int i = 0; i < n; i++) tmp[i] = arr[i];
  for (int i = 0; i < n - 1; i++)
    for (int j = i + 1; j < n; j++)
      if (tmp[j] < tmp[i]) { float t = tmp[i]; tmp[i] = tmp[j]; tmp[j] = t; }
  return (n % 2 == 0) ? (tmp[n/2 - 1] + tmp[n/2]) / 2.0f : tmp[n/2];
}

void computeStats(float arr[], int n, float& avg, float& stddev) {
  avg = 0; stddev = 0;
  if (n <= 0) return;
  for (int i = 0; i < n; i++) avg += arr[i];
  avg /= n;
  if (n > 1) {
    float var = 0;
    for (int i = 0; i < n; i++) { float d = arr[i] - avg; var += d * d; }
    stddev = sqrtf(var / (n - 1));
  }
}

struct Summary {
  float air_suhu, air_hum;
  float tanah_suhu, tanah_lembap;
  float ph, ec;
  int   n, p, k;
  float std_ph, std_ec, std_lembap;
  int   count;
};

Summary getSummary() {
  Summary out{};
  out.count = sampleCount;
  if (sampleCount == 0) return out;
  float tmp[SAMPLE_SIZE];
  int n = sampleCount;

  #define MED(field, target) \
    for (int i = 0; i < n; i++) tmp[i] = sampleBuf[i].field; \
    target = medianOf(tmp, n);

  MED(air_suhu,     out.air_suhu)
  MED(air_hum,      out.air_hum)
  MED(tanah_suhu,   out.tanah_suhu)
  MED(tanah_lembap, out.tanah_lembap)
  MED(ph,           out.ph)
  MED(ec,           out.ec)
  MED(n,            out.n)
  MED(p,            out.p)
  MED(k,            out.k)
  #undef MED

  float avg;
  for (int i = 0; i < n; i++) tmp[i] = sampleBuf[i].ph;
  computeStats(tmp, n, avg, out.std_ph);
  for (int i = 0; i < n; i++) tmp[i] = sampleBuf[i].ec;
  computeStats(tmp, n, avg, out.std_ec);
  for (int i = 0; i < n; i++) tmp[i] = sampleBuf[i].tanah_lembap;
  computeStats(tmp, n, avg, out.std_lembap);
  return out;
}

void takeSample() {
  if (sampleCount >= SAMPLE_SIZE) return;
  SensorSample s;
  s.air_suhu = dhtTemp; s.air_hum = dhtHum;
  s.tanah_suhu = soilTemp; s.tanah_lembap = soilMoist;
  s.ph = soilPH; s.ec = soilEC;
  s.n = soilN; s.p = soilP; s.k = soilK;
  s.valid = soilOk && !isnan(dhtTemp);
  sampleBuf[sampleCount++] = s;

#if DEBUG_SAMPLE
  Serial.printf("[SAMPLE] %d/%d  soil=%.1f%% pH=%.2f EC=%.0f N=%d\n",
                sampleCount, SAMPLE_SIZE, s.tanah_lembap, s.ph, s.ec, s.n);
#endif
}

void clearBuffer() {
  sampleCount = 0;
#if DEBUG_SAMPLE
  Serial.println("[BUFFER] Direset");
#endif
}

// ===================================================================
//  HTTP POST SENSOR
// ===================================================================
void sendToFlaskAPI() {
  if (!wifiConnected) { lastHttpStatus = "no wifi"; httpFailCount++; return; }
  if (sampleCount < MIN_SAMPLES_TO_ACT) { lastHttpStatus = "waiting sample"; return; }

  Summary sm = getSummary();

  StaticJsonDocument<1024> doc;
  doc["device_id"]    = DEVICE_ID;
  doc["uptime"]       = uptimeSeconds;
  doc["air_suhu"]     = round(sm.air_suhu * 10.0) / 10.0;
  doc["air_hum"]      = round(sm.air_hum * 10.0) / 10.0;
  doc["tanah_suhu"]   = round(sm.tanah_suhu * 10.0) / 10.0;
  doc["tanah_lembap"] = round(sm.tanah_lembap * 10.0) / 10.0;
  doc["ph"]           = round(sm.ph * 10.0) / 10.0;
  doc["ec"]           = (int)sm.ec;
  doc["n"]            = sm.n; doc["p"] = sm.p; doc["k"] = sm.k;
  doc["soil_ok"]      = soilOk;
  doc["sample_count"] = sm.count;
  doc["std_ph"]       = round(sm.std_ph * 100.0) / 100.0;
  doc["std_ec"]       = round(sm.std_ec * 10.0) / 10.0;
  doc["std_lembap"]   = round(sm.std_lembap * 10.0) / 10.0;

  JsonArray relayArr = doc.createNestedArray("relay");
  for (int i = 0; i < 6; i++) relayArr.add(relayState[i]);

  String body;
  serializeJson(doc, body);

  HTTPClient http;
  httpBegin(http, String(API_URL));
  http.setTimeout(5000);
  http.addHeader("Content-Type", "application/json");
  if (strlen(API_KEY) > 0) http.addHeader("X-API-Key", API_KEY);

  int httpCode = http.POST(body);

  if (httpCode > 0) {
    if (httpCode == 200 || httpCode == 201) {
      httpOkCount++;
      lastHttpStatus = "OK";
      Serial.printf("[HTTP] ✓ POST %d  samples=%d  ok:%d fail:%d\n",
                    httpCode, sm.count, httpOkCount, httpFailCount);

      String response = http.getString();
      if (response.length() > 0 && response.length() < 4096) {
        handleApiResponse(response);
      }
      clearBuffer();
    } else {
      httpFailCount++;
      lastHttpStatus = "HTTP " + String(httpCode);
      Serial.printf("[HTTP] ✗ POST gagal code=%d\n", httpCode);
    }
  } else {
    httpFailCount++;
    lastHttpStatus = "conn err";
    Serial.printf("[HTTP] ✗ Error: %s\n", http.errorToString(httpCode).c_str());
  }
  http.end();
}

// ===================================================================
//  HANDLE RESPONSE — termasuk MANUAL COMMANDS
// ===================================================================
void handleApiResponse(const String& response) {
  DynamicJsonDocument res(6144);
  DeserializationError err = deserializeJson(res, response);
  if (err) { Serial.printf("[API] JSON err: %s\n", err.c_str()); return; }

  String prev_mode = current_ai_mode;

  if (res.containsKey("ai_mode"))       current_ai_mode = res["ai_mode"].as<String>();
  if (res.containsKey("phase"))         current_phase = res["phase"] | 1;
  if (res.containsKey("model_version")) server_model_version = res["model_version"] | 0;

  // Download model baru kalau versi beda
  if (server_model_version > local_model_version) {
    Serial.printf("[MODEL] Server v%d > lokal v%d → download\n",
                  server_model_version, local_model_version);
    fetchModelFromServer();
  }

  // Deteksi perubahan mode
  if (prev_mode != current_ai_mode) {
    Serial.printf("[MODE] Berubah: %s → %s\n", prev_mode.c_str(), current_ai_mode.c_str());
    if (pending.active) cancelPendingDose("mode berubah");
    if (current_ai_mode != "manual" && manualCount > 0) {
      manualCount = 0;
      Serial.println("[MANUAL] Queue dikosongkan (keluar dari mode manual)");
    }
  }

  // ===== RELAY TARGET (untuk mode off) =====
  if (res.containsKey("relay")) {
    JsonArray arr = res["relay"];
    for (int i = 0; i < 6 && i < (int)arr.size(); i++) {
      // Di mode auto: R1..R4 dikendalikan dose, skip relay target
      if (current_ai_mode == "auto" && i < 4) continue;
      // Di mode manual: R1..R4 dikendalikan user, skip relay target
      if (current_ai_mode == "manual" && i < 4) continue;

      bool target = arr[i].as<bool>();
      if (relayState[i] != target) {
        setRelay(i, target);
        Serial.printf("[API CMD] R%d %s → %s\n",
                      i + 1, relayLabel[i], target ? "ON" : "OFF");
      }
    }
  }

  // ===== DOSE (AI/EXPERT) =====
  if (res.containsKey("dose") && !res["dose"].isNull() && current_ai_mode != "manual") {
    JsonObject d = res["dose"];
    float mlA  = d["A"]       | 0.0f;
    float mlB  = d["B"]       | 0.0f;
    float mlUP = d["PH_UP"]   | 0.0f;
    float mlDN = d["PH_DOWN"] | 0.0f;
    String src = d["src"]     | "expert";
    int    ph  = d["phase"]   | 1;
    bool   verified = d["verified"] | true;

    last_dose_src = src;
    last_dose_ml[0] = mlA; last_dose_ml[1] = mlB;
    last_dose_ml[2] = mlUP; last_dose_ml[3] = mlDN;
    current_phase = ph;

    Serial.printf("[DOSE %s] A=%.1f B=%.1f UP=%.1f DN=%.1f (ph=%d, ver=%s)\n",
                  src.c_str(), mlA, mlB, mlUP, mlDN, ph, verified ? "ya" : "tidak");

    if (pending.active) cancelPendingDose("dose baru datang");

    if (current_ai_mode == "auto" && verified) {
      setPendingDose(mlA, mlB, mlUP, mlDN, src);
    } else if (current_ai_mode == "shadow") {
      Serial.println("[DOSE] Shadow — hanya log, tidak aktuasi");
    }
  }

  // ===== MANUAL COMMANDS (BARU) =====
  if (res.containsKey("manual_commands")) {
    JsonArray cmds = res["manual_commands"];
    if (cmds.size() > 0) {
      parseManualCommands(cmds);
    }
  }
}

// ===================================================================
//  MANUAL COMMAND — parsing & eksekusi
// ===================================================================
int mapPumpNameToIdx(const String& name) {
  String n = name;
  n.toUpperCase();
  n.trim();
  if (n == "A" || n == "DOSING_A")   return 0;
  if (n == "B" || n == "DOSING_B")   return 1;
  if (n == "PH_UP" || n == "UP")     return 2;
  if (n == "PH_DOWN" || n == "DOWN") return 3;
  if (n == "STOP" || n == "EMERGENCY") return -1;
  if (n == "STOP_ALL") return -1;
  return -2;  // unknown
}

void parseManualCommands(JsonArray arr) {
  // Kosongkan queue lama kalau sudah penuh
  if (manualCount >= MANUAL_MAX_QUEUE) {
    Serial.println("[MANUAL] Queue penuh, skip command baru");
    return;
  }

  for (JsonVariant v : arr) {
    if (manualCount >= MANUAL_MAX_QUEUE) break;

    JsonObject c = v.as<JsonObject>();
    int    id   = c["id"]   | -1;
    String pump = c["pump"] | "";
    float  ml   = c["ml"]   | 0.0f;

    // Emergency stop
    if (pump == "STOP" || pump == "EMERGENCY" || pump == "STOP_ALL") {
      emergencyStop("command dari server");
      manualQueue[manualCount].id = id;
      manualQueue[manualCount].pump_idx = -1;
      manualQueue[manualCount].ml = 0;
      manualQueue[manualCount].queued_at = millis();
      manualCount++;
      Serial.printf("[MANUAL] + STOP (id=%d)\n", id);
      continue;
    }

    int pump_idx = mapPumpNameToIdx(pump);
    if (pump_idx < 0) {
      Serial.printf("[MANUAL] ✗ Unknown pump '%s' (id=%d)\n", pump.c_str(), id);
      sendManualAck(id, false, "unknown pump");
      continue;
    }

    if (ml <= 0.5f) {
      Serial.printf("[MANUAL] ✗ ml terlalu kecil: %.1f (id=%d)\n", ml, id);
      sendManualAck(id, false, "ml too small");
      continue;
    }

    // Clamp berdasarkan MAX_OUT
    float maxv = (pump_idx == 0) ? MAX_A :
                 (pump_idx == 1) ? MAX_B :
                 (pump_idx == 2) ? MAX_PH_UP : MAX_PH_DOWN;
    if (ml > maxv) {
      Serial.printf("[MANUAL] ⚠ Clamp ml %.1f → %.1f (id=%d)\n", ml, maxv, id);
      ml = maxv;
    }
    if (ml > MANUAL_MAX_ML) ml = MANUAL_MAX_ML;

    manualQueue[manualCount].id        = id;
    manualQueue[manualCount].pump_idx  = pump_idx;
    manualQueue[manualCount].ml        = ml;
    manualQueue[manualCount].queued_at = millis();
    manualCount++;

    Serial.printf("[MANUAL] + id=%d pump=%s ml=%.1f\n",
                  id, pump.c_str(), ml);
  }
}

void executeManualBatch() {
  if (manualCount == 0) return;

  // Cek cooldown antar command
  if (millis() - last_manual_exec_ms < MANUAL_COOLDOWN_MS) return;

  // Ambil command pertama (FIFO)
  ManualCommand cmd = manualQueue[0];

  // Geser queue
  for (int i = 1; i < manualCount; i++) manualQueue[i-1] = manualQueue[i];
  manualCount--;

  // Emergency stop
  if (cmd.pump_idx == -1) {
    emergencyStop("manual stop");
    sendManualAck(cmd.id, true, "stopped");
    last_manual_exec_ms = millis();
    return;
  }

  Serial.printf("[MANUAL EXEC] id=%d idx=%d ml=%.1f\n",
                cmd.id, cmd.pump_idx, cmd.ml);

  // Eksekusi
  runPumpML(cmd.pump_idx, cmd.ml);

  // ACK ke server
  sendManualAck(cmd.id, true, "executed");

  last_manual_exec_ms = millis();
}

void emergencyStop(const char* reason) {
  Serial.printf("[ESTOP] 🛑 Emergency stop: %s\n", reason);

  // Matikan semua relay 0..3 (pompa)
  for (int i = 0; i < 4; i++) {
    digitalWrite(relayPins[i], LOW);
    relayState[i] = false;
    drawRelayBox(i);
  }

  // Cancel pending dose
  if (pending.active) cancelPendingDose("emergency stop");

  // Clear queue
  manualCount = 0;
}

// ===================================================================
//  MANUAL ACK — lapor ke server
// ===================================================================
bool sendManualAck(int command_id, bool success, const char* reason) {
  if (!wifiConnected) return false;
  if (command_id < 0) return false;

  HTTPClient http;
  httpBegin(http, String(API_MANUAL_ACK));
  http.setTimeout(3000);
  http.addHeader("Content-Type", "application/json");
  if (strlen(API_KEY) > 0) http.addHeader("X-API-Key", API_KEY);

  StaticJsonDocument<256> doc;
  doc["device_id"]  = DEVICE_ID;
  doc["command_id"] = command_id;
  doc["ok"]         = success;
  doc["reason"]     = reason;

  String body;
  serializeJson(doc, body);

  int code = http.POST(body);
  http.end();

  if (code == 200 || code == 201) {
    Serial.printf("[MANUAL ACK] id=%d ok=%d\n", command_id, success);
    return true;
  }
  Serial.printf("[MANUAL ACK] ✗ Gagal HTTP %d\n", code);
  return false;
}

// ===================================================================
//  AKTUASI
// ===================================================================
void runPumpML(int idx, float ml) {
  if (idx < 0 || idx > 3 || ml < 0.5f) return;

  float maxv = (idx == 0) ? MAX_A :
               (idx == 1) ? MAX_B :
               (idx == 2) ? MAX_PH_UP : MAX_PH_DOWN;
  if (ml > maxv) ml = maxv;

  unsigned long durMs = (unsigned long)(ml / ML_PER_SEC[idx] * 1000.0f);
  if (durMs > PUMP_MAX_DUR_MS) durMs = PUMP_MAX_DUR_MS;

  digitalWrite(relayPins[idx], HIGH);
  relayState[idx] = true;
  drawRelayBox(idx);

  Serial.printf("  → R%d %s %.1f mL (%lu ms)\n",
                idx + 1, relayLabel[idx], ml, durMs);

  unsigned long t0 = millis();
  while (millis() - t0 < durMs) delay(10);

  digitalWrite(relayPins[idx], LOW);
  relayState[idx] = false;
  drawRelayBox(idx);
}

void executeDose(float mlA, float mlB, float mlUP, float mlDN) {
  if (mlA > 0.5f) runPumpML(0, mlA);
  if (mlB > 0.5f) { delay(500); runPumpML(1, mlB); }
  if (mlUP > 0.5f) { delay(500); runPumpML(2, mlUP); }
  if (mlDN > 0.5f) { delay(500); runPumpML(3, mlDN); }
}

// ===================================================================
//  PENDING DOSE (AUTO)
// ===================================================================
void setPendingDose(float mlA, float mlB, float mlUP, float mlDN, const String& src) {
  pending.ml[0]=mlA; pending.ml[1]=mlB; pending.ml[2]=mlUP; pending.ml[3]=mlDN;
  pending.src = src;
  pending.set_at = millis();
  pending.active = true;
  Serial.printf("[PENDING] Disimpan (%.1f,%.1f,%.1f,%.1f) — tunggu %lu ms\n",
                mlA, mlB, mlUP, mlDN, SAFETY_DELAY_MS);
}

void cancelPendingDose(const char* reason) {
  if (!pending.active) return;
  Serial.printf("[PENDING] ✗ Dibatalkan: %s\n", reason);
  pending.active = false;
}

void checkAndExecutePending() {
  if (!pending.active) return;
  if (millis() - pending.set_at < SAFETY_DELAY_MS) return;

  if (current_ai_mode != "auto") {
    cancelPendingDose("mode bukan auto");
    return;
  }
  if (millis() - last_act_ms < COOLDOWN_AFTER_ACT_MS) {
    pending.active = false;
    return;
  }

  Serial.println("[PENDING] ✓ Waktu aman → EKSEKUSI");
  executeDose(pending.ml[0], pending.ml[1], pending.ml[2], pending.ml[3]);
  last_act_ms = millis();
  pending.active = false;
}

// ===================================================================
//  SETUP
// ===================================================================
void setup() {
  Serial.begin(115200);
  delay(1500);

  printBanner();
  Serial.println("  [BOOT] Inisialisasi sistem...\n");

  pinMode(LED_HIJAU, OUTPUT);
  digitalWrite(LED_HIJAU, LOW);

  printSectionHeader("INIT RELAY");
  for (int i = 0; i < 6; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], LOW);
    Serial.printf("  R%d %-12s → GPIO%d\n", i + 1, relayLabel[i], relayPins[i]);
  }

  printSectionHeader("INIT DHT11");
  pinMode(DHTPIN, INPUT);
  dht.begin();

  printSectionHeader("INIT RS485");
  SerialPort.begin(SENSOR_BAUD, SERIAL_8N1, 16, 17);
  node.begin(SENSOR_SLAVE_ID, SerialPort);
  pinMode(MAX485_RE_DE, OUTPUT);
  digitalWrite(MAX485_RE_DE, LOW);
  node.preTransmission(preTransmission);
  node.postTransmission(postTransmission);

  printSectionHeader("INIT TFT");
  tft.init();
  tft.setRotation(TFT_ROTATION);
  tft.fillScreen(BG_COLOR);
  drawStaticLayout();
  drawAllDynamic();

  printSectionHeader("INIT AI MODEL");
  loadModelFromNVS();
  if (local_model_version == 0) useCompiledModel();
  Serial.printf("  Local version : %d\n", local_model_version);

  printSectionHeader("INIT WIFI");
  connectWiFi();
  if (wifiConnected) fetchModelFromServer();

  printSectionHeader("INIT BUFFER & SAFETY");
  Serial.printf("  Sample size   : %d\n", SAMPLE_SIZE);
  Serial.printf("  Total siklus  : %lu ms\n", SAMPLE_SIZE * SAMPLE_INTERVAL_MS);
  Serial.printf("  Safety delay  : %lu ms\n", SAFETY_DELAY_MS);
  Serial.printf("  Cooldown auto : %lu ms\n", COOLDOWN_AFTER_ACT_MS);
  Serial.printf("  Manual max q  : %d command\n", MANUAL_MAX_QUEUE);
  Serial.printf("  Manual cooldown: %lu ms\n", MANUAL_COOLDOWN_MS);

  Serial.println("\n╔══════════════════════════════════════════════════════════╗");
  Serial.println("║              ✓ SEMUA SISTEM SIAP                         ║");
  Serial.println("╚══════════════════════════════════════════════════════════╝");
  Serial.println("\n  Command: 'R'=report, 'M'=model, 'Q'=queue, 'S'=estop");
}

// ===================================================================
//  LOOP
// ===================================================================
void loop() {
  unsigned long now = millis();

  // Clock
  if (now - lastClockTick >= 1000) {
    lastClockTick = now;
    uptimeSeconds++;
    drawFooter();
    if (uptimeSeconds % 10 == 0) printFullReport();
  }

  // WiFi
  if (now - lastWifiCheck >= WIFI_CHECK) {
    lastWifiCheck = now;
    checkWiFi();
    if (wifiConnected != prevWifiStatus) {
      prevWifiStatus = wifiConnected;
      drawHeaderStatus();
    }
  }

  // LED
  if (wifiConnected) digitalWrite(LED_HIJAU, HIGH);
  else digitalWrite(LED_HIJAU, ((now / 300) % 2) ? HIGH : LOW);

  // DHT
  if (now - lastDHTRead >= DHT_INTERVAL) {
    lastDHTRead = now;
    readDHT11();
    drawAirCard();
  }

  // Soil + sample
  if (now - lastSampleMs >= SAMPLE_INTERVAL_MS) {
    lastSampleMs = now;
    readSoilSensor();
    drawSoilCards();
    printQuickSummary();
    if (soilOk) takeSample();
  }

  // ===== MANUAL MODE — prioritas tertinggi =====
  if (current_ai_mode == "manual") {
    executeManualBatch();
  } else {
    // Mode lain: cek pending dose
    checkAndExecutePending();
  }

  // HTTP kirim
  if (sampleCount >= SAMPLE_SIZE) {
    sendToFlaskAPI();
  }

  handleSerialInput();
}

// ===================================================================
//  SERIAL INPUT
// ===================================================================
void handleSerialInput() {
  if (!Serial.available()) return;
  String cmd = Serial.readStringUntil('\n');
  cmd.trim();

  if (cmd == "R" || cmd == "r")        printFullReport();
  else if (cmd == "W" || cmd == "w")   printNetworkInfo();
  else if (cmd == "M" || cmd == "m")   printModelInfo();
  else if (cmd == "Q" || cmd == "q")   printManualQueue();
  else if (cmd == "B" || cmd == "b")   {
    Serial.printf("[BUFFER] %d/%d sample\n", sampleCount, SAMPLE_SIZE);
  }
  else if (cmd == "C" || cmd == "c")   clearBuffer();
  else if (cmd == "S" || cmd == "s")   emergencyStop("serial command");
  else if (cmd == "SYNC")               { Serial.println("[MODEL] Manual sync..."); fetchModelFromServer(); }
  else if (cmd == "1" || cmd == "2" || cmd == "3" ||
           cmd == "4" || cmd == "5" || cmd == "6") {
    int idx = cmd.toInt() - 1;
    setRelay(idx, !relayState[idx]);
  }
  else if (cmd == "ALL") {
    bool allOn = true;
    for (int i = 0; i < 6; i++) if (!relayState[i]) allOn = false;
    for (int i = 0; i < 6; i++) setRelay(i, !allOn);
  }
}

// ===================================================================
//  BACA DHT11
// ===================================================================
void readDHT11() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  if (!isnan(h) && !isnan(t)) { dhtHum = h; dhtTemp = t; }
}

// ===================================================================
//  BACA SOIL SENSOR
// ===================================================================
void readSoilSensor() {
  uint8_t result = node.readHoldingRegisters(0x0000, 7);
  if (result != node.ku8MBSuccess) {
    soilOk = false; lastSoilErr = result; soilFailCount++;
    return;
  }

  uint16_t reg0 = node.getResponseBuffer(0);
  uint16_t reg1 = node.getResponseBuffer(1);
  uint16_t reg2 = node.getResponseBuffer(2);
  uint16_t reg3 = node.getResponseBuffer(3);
  uint16_t reg4 = node.getResponseBuffer(4);
  uint16_t reg5 = node.getResponseBuffer(5);
  uint16_t reg6 = node.getResponseBuffer(6);

#if DEBUG_RAW_SOIL
  Serial.printf("[RAW SOIL] reg0=%u reg1=%u reg2=%u reg3=%u reg4=%u reg5=%u reg6=%u\n",
                reg0, reg1, reg2, reg3, reg4, reg5, reg6);
#endif

  float raw_lembap = reg0 / 10.0f;
  float raw_suhu   = reg1 / 10.0f;
  float raw_ec     = reg2;
  float raw_ph     = reg3 / 10.0f;
  float raw_n      = reg4;
  float raw_p      = reg5;
  float raw_k      = reg6;

  raw_ph = raw_ph + 0.4;

  float adj_ec = constrain(61.0 * (raw_ec / 421.0), 0.0, 90.0); raw_ec += adj_ec;
  float adj_n  = constrain(13.0 * (raw_n / 49.0),   0.0, 20.0); raw_n  += adj_n;
  float adj_p  = constrain(29.0 * (raw_p / 160.0),  0.0, 45.0); raw_p  += adj_p;
  float adj_k  = constrain(34.0 * (raw_k / 153.0),  0.0, 50.0); raw_k  += adj_k;

  if (raw_ec <= 5.0 && raw_lembap <= 5.0) {
    soilMoist = 0; soilTemp = 0; soilPH = 0; soilEC = 0;
    soilN = 0; soilP = 0; soilK = 0;
    soilOk = true; soilOkCount++;
    return;
  }

  if (raw_ec <= 86.0) {
    soilEC = mapFloat(raw_ec, 0.0, 86.0, 163.0, 192.0);
    soilN  = (int)mapFloat(raw_ec, 0.0, 86.0, 64.0, 65.0);
    soilP  = (int)mapFloat(raw_ec, 0.0, 86.0, 0.0, 2.0);
    soilK  = (int)mapFloat(raw_ec, 0.0, 86.0, 35.0, 52.0);
    soilMoist = mapFloat(raw_lembap, 0.0, 30.0, 17.0, 26.0);
  } else if (raw_ec <= 192.0) {
    soilEC = mapFloat(raw_ec, 86.0, 192.0, 192.0, 249.0);
    soilN  = (int)mapFloat(raw_ec, 86.0, 192.0, 65.0, 65.0);
    soilP  = (int)mapFloat(raw_ec, 86.0, 192.0, 2.0, 13.0);
    soilK  = (int)mapFloat(raw_ec, 86.0, 192.0, 52.0, 77.0);
    soilMoist = mapFloat(raw_lembap, 30.0, 60.0, 26.0, 37.0);
  } else if (raw_ec <= 400.0) {
    soilEC = mapFloat(raw_ec, 192.0, 400.0, 249.0, 350.0);
    soilN  = (int)mapFloat(raw_ec, 192.0, 400.0, 65.0, 45.0);
    soilP  = (int)mapFloat(raw_ec, 192.0, 400.0, 13.0, 35.0);
    soilK  = (int)mapFloat(raw_ec, 192.0, 400.0, 77.0, 120.0);
    soilMoist = mapFloat(raw_lembap, 60.0, 100.0, 37.0, 60.0);
  } else {
    soilEC = mapFloat(raw_ec, 400.0, 3000.0, 350.0, 1650.0);
    soilN  = (int)mapFloat(raw_ec, 400.0, 3000.0, 45.0, 250.0);
    soilP  = (int)mapFloat(raw_ec, 400.0, 3000.0, 35.0, 310.0);
    soilK  = (int)mapFloat(raw_ec, 400.0, 3000.0, 120.0, 650.0);
    soilMoist = mapFloat(raw_lembap, 100.0, 300.0, 60.0, 100.0);
  }

  soilTemp = raw_suhu - 1.3;
  soilPH   = raw_ph + 0.7;

  if (soilEC < 0) soilEC = 0;
  if (soilN < 0) soilN = 0; if (soilN > 1999) soilN = 1999;
  if (soilP < 0) soilP = 0; if (soilP > 1999) soilP = 1999;
  if (soilK < 0) soilK = 0; if (soilK > 1999) soilK = 1999;
  if (soilMoist < 0) soilMoist = 0; if (soilMoist > 100) soilMoist = 100;
  if (soilPH < 0) soilPH = 0; if (soilPH > 14) soilPH = 14;

  soilOk = true; soilOkCount++;
}

// ===================================================================
//  SET RELAY
// ===================================================================
void setRelay(int idx, bool state) {
  if (idx < 0 || idx > 5) return;
  relayState[idx] = state;
  digitalWrite(relayPins[idx], state ? HIGH : LOW);
  drawRelayBox(idx);
  Serial.printf("[RELAY] R%d %-12s → %s\n",
                idx + 1, relayLabel[idx], state ? "ON" : "OFF");
}

// ===================================================================
//  TFT LAYOUT (tidak berubah dari v7.2)
// ===================================================================
void drawStaticLayout() {
  tft.fillRect(0, 0, 480, 30, CARD_BG);
  tft.fillRect(0, 30, 480, 2, C_GREEN);

  tft.setTextColor(C_GREEN, CARD_BG);
  tft.setTextSize(2);
  tft.setCursor(8, 6);
  tft.print("GREEN HOUSE MONITOR");

  tft.setTextSize(1);
  tft.setTextColor(TEXT_GREY, CARD_BG);
  tft.setCursor(320, 10);
  tft.print("v7.3");

  drawCardFrame(4,   34, 234, 76, "UDARA (DHT11)", C_ORANGE);
  drawCardFrame(242, 34, 234, 76, "TANAH (RS485)", C_GREEN);

  drawMiniFrame(4,   114, 92, 56, "pH", C_PURPLE);
  drawMiniFrame(100, 114, 92, 56, "EC", C_BLUE);
  drawMiniFrame(196, 114, 92, 56, "N",  C_GREEN);
  drawMiniFrame(292, 114, 92, 56, "P",  C_YELLOW);
  drawMiniFrame(388, 114, 88, 56, "K",  C_ORANGE);

  tft.fillRoundRect(4, 176, 472, 118, 6, CARD_BG);
  tft.drawRoundRect(4, 176, 472, 118, 6, C_GREEN);

  tft.setTextColor(C_GREEN, CARD_BG);
  tft.setTextSize(2);
  tft.setCursor(14, 182);
  tft.print("RELAY CONTROL");

  for (int i = 0; i < 6; i++) drawRelayBox(i);

  tft.fillRect(0, 298, 480, 22, CARD_BG);
  tft.drawFastHLine(0, 298, 480, CARD_LINE);
}

void drawCardFrame(int x, int y, int w, int h, const char* title, uint16_t accent) {
  tft.fillRoundRect(x, y, w, h, 6, CARD_BG);
  tft.drawRoundRect(x, y, w, h, 6, accent);
  tft.drawRoundRect(x + 1, y + 1, w - 2, h - 2, 5, CARD_LINE);
  tft.fillCircle(x + 9, y + 9, 3, accent);
  tft.setTextColor(accent, CARD_BG);
  tft.setTextSize(1);
  tft.setCursor(x + 16, y + 6);
  tft.print(title);
  tft.drawFastHLine(x + 6, y + 20, w - 12, CARD_LINE);
}

void drawMiniFrame(int x, int y, int w, int h, const char* title, uint16_t accent) {
  tft.fillRoundRect(x, y, w, h, 5, CARD_BG);
  tft.drawRoundRect(x, y, w, h, 5, accent);
  tft.fillCircle(x + 8, y + 8, 2, accent);
  tft.setTextColor(accent, CARD_BG);
  tft.setTextSize(1);
  tft.setCursor(x + 14, y + 5);
  tft.print(title);
  tft.drawFastHLine(x + 4, y + 16, w - 8, CARD_LINE);
}

void drawAllDynamic() {
  drawHeaderStatus(); drawAirCard(); drawSoilCards(); drawFooter();
}

void drawHeaderStatus() {
  tft.fillRect(360, 6, 118, 18, CARD_BG);
  uint16_t col = wifiConnected ? C_GREEN : C_RED;
  tft.fillCircle(370, 15, 5, col);
  tft.setTextColor(col, CARD_BG);
  tft.setTextSize(1);
  tft.setCursor(382, 11);
  if (wifiConnected) {
    char buf[20]; snprintf(buf, sizeof(buf), "%d dBm", WiFi.RSSI());
    tft.print(buf);
  } else tft.print("WiFi --");
}

void drawAirCard() {
  int x = 4, y = 34, w = 234;
  tft.fillRect(x + 4, y + 24, w - 8, 48, CARD_BG);

  tft.setTextSize(4);
  if (!isnan(dhtTemp)) {
    tft.setTextColor(TEXT_WHITE, CARD_BG);
    tft.setCursor(x + 14, y + 26);
    char buf[8]; snprintf(buf, sizeof(buf), "%.1f", dhtTemp); tft.print(buf);
    tft.setTextSize(2); tft.setTextColor(C_ORANGE, CARD_BG);
    tft.setCursor(x + 100, y + 38); tft.print("C");
  } else {
    tft.setTextColor(C_RED, CARD_BG);
    tft.setCursor(x + 14, y + 26); tft.print("--.-");
  }

  tft.setTextSize(4);
  if (!isnan(dhtHum)) {
    tft.setTextColor(C_CYAN, CARD_BG);
    tft.setCursor(x + 130, y + 26);
    char buf[8]; snprintf(buf, sizeof(buf), "%.0f", dhtHum); tft.print(buf);
    tft.setTextSize(2); tft.setTextColor(C_CYAN, CARD_BG);
    tft.setCursor(x + 200, y + 38); tft.print("%");
  } else {
    tft.setTextColor(C_RED, CARD_BG);
    tft.setCursor(x + 130, y + 26); tft.print("--");
  }

  tft.setTextSize(1); tft.setTextColor(TEXT_GREY, CARD_BG);
  tft.setCursor(x + 14, y + 62);  tft.print("Suhu");
  tft.setCursor(x + 130, y + 62); tft.print("Kelembapan");
}

void drawSoilCards() {
  int x = 242, y = 34, w = 234;
  tft.fillRect(x + 4, y + 24, w - 8, 48, CARD_BG);

  tft.setTextSize(4);
  if (soilOk) {
    tft.setTextColor(TEXT_WHITE, CARD_BG);
    tft.setCursor(x + 14, y + 26);
    char buf[8]; snprintf(buf, sizeof(buf), "%.1f", soilTemp); tft.print(buf);
    tft.setTextSize(2); tft.setTextColor(C_GREEN, CARD_BG);
    tft.setCursor(x + 100, y + 38); tft.print("C");
  } else {
    tft.setTextColor(C_RED, CARD_BG);
    tft.setCursor(x + 14, y + 26); tft.print("ERR");
  }

  tft.setTextSize(3);
  if (soilOk) {
    tft.setTextColor(C_TEAL, CARD_BG);
    tft.setCursor(x + 120, y + 28);
    char buf[8]; snprintf(buf, sizeof(buf), "%.0f%%", soilMoist); tft.print(buf);
    drawProgressBar(x + 120, y + 58, 108, 10, soilMoist, C_TEAL);
  } else {
    tft.setTextColor(C_RED, CARD_BG);
    tft.setCursor(x + 120, y + 28); tft.print("--");
  }

  tft.setTextSize(1); tft.setTextColor(TEXT_GREY, CARD_BG);
  tft.setCursor(x + 14, y + 62);  tft.print("Suhu Tanah");
  tft.setCursor(x + 120, y + 48); tft.print("Kelembapan Tanah");

  drawMiniValue(4,   114, 92, 56, soilOk ? soilPH : NAN, 1, C_PURPLE, "pH");
  drawMiniValue(100, 114, 92, 56, soilOk ? soilEC : NAN, 0, C_BLUE,   "us/cm");
  drawMiniValue(196, 114, 92, 56, soilOk ? soilN  : NAN, 0, C_GREEN,  "mg/kg");
  drawMiniValue(292, 114, 92, 56, soilOk ? soilP  : NAN, 0, C_YELLOW, "mg/kg");
  drawMiniValue(388, 114, 88, 56, soilOk ? soilK  : NAN, 0, C_ORANGE, "mg/kg");
}

void drawMiniValue(int x, int y, int w, int h, float val, int decimals,
                   uint16_t color, const char* unit) {
  tft.fillRect(x + 3, y + 18, w - 6, 36, CARD_BG);
  if (isnan(val)) {
    tft.setTextSize(2); tft.setTextColor(C_RED, CARD_BG);
    tft.setCursor(x + 10, y + 26); tft.print("--");
    return;
  }
  tft.setTextSize(2); tft.setTextColor(TEXT_WHITE, CARD_BG);
  tft.setCursor(x + 6, y + 22);
  char buf[12];
  if (decimals > 0) snprintf(buf, sizeof(buf), "%.*f", decimals, val);
  else              snprintf(buf, sizeof(buf), "%.0f", val);
  tft.print(buf);
  tft.setTextSize(1); tft.setTextColor(color, CARD_BG);
  tft.setCursor(x + 6, y + 42); tft.print(unit);
}

void drawRelayBox(int idx) {
  if (idx < 0 || idx > 5) return;
  int startX = 10, startY = 208;
  int boxW = 148, boxH = 40;
  int gapX = 6, gapY = 6;
  int col = idx % 3, row = idx / 3;
  int x = startX + col * (boxW + gapX);
  int y = startY + row * (boxH + gapY);

  uint16_t boxColor  = relayState[idx] ? 0x1C47 : 0x18E3;
  uint16_t borderCol = relayState[idx] ? C_GREEN : CARD_LINE;
  uint16_t statusCol = relayState[idx] ? C_GREEN : TEXT_DIM;

  tft.fillRoundRect(x, y, boxW, boxH, 4, boxColor);
  tft.drawRoundRect(x, y, boxW, boxH, 4, borderCol);

  tft.setTextSize(1); tft.setTextColor(TEXT_GREY, boxColor);
  tft.setCursor(x + 4, y + 4); tft.printf("R%d", idx + 1);
  tft.setTextColor(TEXT_WHITE, boxColor);
  tft.setCursor(x + 22, y + 4); tft.print(relayLabel[idx]);
  tft.setTextSize(2); tft.setTextColor(statusCol, boxColor);
  tft.setCursor(x + 8, y + 18); tft.print(relayState[idx] ? "ON" : "OFF");

  drawStatusLed(x + boxW - 14, y + boxH / 2, relayState[idx], C_GREEN);
}

void drawFooter() {
  unsigned long h = uptimeSeconds / 3600;
  unsigned long m = (uptimeSeconds % 3600) / 60;
  unsigned long s = uptimeSeconds % 60;

  tft.fillRect(0, 300, 480, 20, CARD_BG);
  tft.setTextSize(1); tft.setTextColor(TEXT_GREY, CARD_BG);
  tft.setCursor(8, 305);
  char buf[80];
  snprintf(buf, sizeof(buf), "UP %02lu:%02lu:%02lu", h, m, s);
  tft.print(buf);

  tft.setCursor(110, 305);
  tft.setTextColor(soilOk ? C_GREEN : C_RED, CARD_BG);
  tft.printf("SOIL %s", soilOk ? "OK" : "ERR");

  tft.setCursor(180, 305);
  tft.setTextColor(wifiConnected ? C_GREEN : C_RED, CARD_BG);
  tft.printf("WiFi %s", wifiConnected ? "OK" : "--");

  uint16_t aiCol = (current_ai_mode == "auto")   ? C_GREEN :
                   (current_ai_mode == "manual") ? C_PURPLE :
                   (current_ai_mode == "shadow") ? C_YELLOW : TEXT_GREY;
  tft.setCursor(240, 305);
  tft.setTextColor(aiCol, CARD_BG);
  tft.printf("AI:%s", current_ai_mode.c_str());

  // Buffer/manual indicator
  tft.setCursor(360, 305);
  if (manualCount > 0) {
    tft.setTextColor(C_PURPLE, CARD_BG);
    tft.printf("M:%d", manualCount);
  } else {
    tft.setTextColor(sampleCount >= SAMPLE_SIZE ? C_GREEN : TEXT_DIM, CARD_BG);
    tft.printf("B:%d/%d", sampleCount, SAMPLE_SIZE);
  }
}