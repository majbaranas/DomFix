#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>
#include <Firebase_ESP_Client.h>
#include <DHT.h>
#include <ESP32Servo.h>

#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// ================= CONFIGURATION =================
#define WIFI_SSID         "AX-RF"
#define WIFI_PASSWORD     "12345678"

#define API_KEY           "AIzaSyAKlR59P2gbnvVHv9V19QhGvFXA6lpDvV4"
#define DATABASE_URL      "https://domotique-c7923-default-rtdb.firebaseio.com"
#define USER_EMAIL        "aymen@domfix.com"
#define USER_PASSWORD     "12345678"

// ===== ROOT CAUSE FIX =====
// The Flutter app is logged in as a DIFFERENT user than the ESP32.
// Flutter user UID: ibuqXAMkhpbDO22TbRnuvHNEwJP2
// ESP32 auth UID:   cjMcg591lxRHp3brCi4uNbpggjE2 (aymen@domfix.com)
//
// The ESP32 was building its path from its OWN auth UID, so it was
// reading from a completely different RTDB node than where the
// Flutter app writes. We fix this by targeting the Flutter user's UID.
#define FLUTTER_USER_UID  "ibuqXAMkhpbDO22TbRnuvHNEwJP2"

#define LED_PIN   2
#define FAN_PIN   4
#define SERVO_PIN 18
#define DHT_PIN   15
#define LDR_PIN   34
#define TOUCH_PIN 13

#define DHTTYPE DHT11

// ================= OBJECTS =================
DHT dht(DHT_PIN, DHTTYPE);
Servo doorServo;
WebServer server(80);

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

String esp32Uid;       // The ESP32's own auth UID (for logging)
String targetBasePath; // Path targeting the Flutter user's data

bool ledState = false;
bool fanState = false;
bool doorState = false;

bool firebaseReady = false;
bool wifiConnected = false;

// ================= HTML IN FLASH =================
const char index_html[] PROGMEM = R"rawliteral(
<html>
<head>
<title>DomFix ESP32</title>
<style>
body{font-family:monospace;background:#0a0a0a;color:#c8ff00;padding:20px;}
.device{background:#1a1a1a;padding:10px;margin:5px;border-radius:6px;}
</style>
</head>
<body>
<h1>DomFix Smart Home</h1>
<p>ESP32 Local Server</p>
</body>
</html>
)rawliteral";

// ================= WIFI =================
void connectWiFi() {
  WiFi.mode(WIFI_STA);
  Serial.println("Connecting WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi CONNECTED");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
    wifiConnected = true;
  } else {
    Serial.println("WiFi FAILED");
    wifiConnected = false;
  }
}

// ================= HTTP HANDLERS =================
void handleRoot() {
  server.send(200, "text/html", index_html);
}

void handleControl() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"err\":1}");
    return;
  }

  StaticJsonDocument<128> doc;
  deserializeJson(doc, server.arg("plain"));

  String device = doc["device"] | "";
  bool value = doc["value"] | false;

  if (device == "ESP32_LED") {
    ledState = value;
    digitalWrite(LED_PIN, ledState ? HIGH : LOW);
  }
  else if (device == "ESP32_FAN") {
    fanState = value;
    digitalWrite(FAN_PIN, fanState ? HIGH : LOW);
  }
  else if (device == "ESP32_SERVO") {
    doorState = value;
    doorServo.write(doorState ? 90 : 0);
  }

  server.send(200, "application/json", "{\"ok\":1}");
}

void handleStatus() {
  StaticJsonDocument<256> doc;
  doc["led"] = ledState;
  doc["fan"] = fanState;
  doc["door"] = doorState;
  doc["t"] = dht.readTemperature();
  doc["h"] = dht.readHumidity();
  doc["ldr"] = analogRead(LDR_PIN);

  String out;
  serializeJson(doc, out);
  server.send(200, "application/json", out);
}

// ================= FIREBASE INIT =================
void connectFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  // Token status callback (for debugging)
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("[DEBUG] Waiting for Firebase auth...");

  // Wait for auth token
  int attempts = 0;
  while (auth.token.uid == "" && attempts < 20) {
    Serial.print(".");
    delay(500);
    attempts++;
  }
  Serial.println();

  if (auth.token.uid != "") {
    esp32Uid = auth.token.uid.c_str();
    Serial.println("Firebase Connected");
    Serial.print("[DEBUG] ESP32 Auth UID: ");
    Serial.println(esp32Uid);

    // ===== THE FIX =====
    // Use the Flutter user's UID, NOT the ESP32's own auth UID
    targetBasePath = "/smart_devices/";
    targetBasePath += FLUTTER_USER_UID;
    targetBasePath += "/devices";

    Serial.print("[DEBUG] Target basePath: ");
    Serial.println(targetBasePath);

    firebaseReady = true;
  } else {
    Serial.println("Firebase Error: Auth Failed after 10s");
    firebaseReady = false;
  }
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);
  delay(100);

  Serial.println();
  Serial.println("=============================");
  Serial.println("  DomFix ESP32 Smart Home");
  Serial.println("=============================");

  pinMode(LED_PIN, OUTPUT);
  pinMode(FAN_PIN, OUTPUT);
  pinMode(TOUCH_PIN, INPUT);
  digitalWrite(LED_PIN, LOW);

  doorServo.attach(SERVO_PIN);
  dht.begin();

  connectWiFi();

  if (wifiConnected) {
    server.on("/", handleRoot);
    server.on("/control", HTTP_POST, handleControl);
    server.on("/status", handleStatus);
    server.begin();
    Serial.println("[DEBUG] HTTP server started");
  }

  if (wifiConnected) {
    connectFirebase();
  }

  Serial.println("System Ready");
  Serial.println("=============================");
}

// ================= LOOP =================
unsigned long lastFirebaseCheck = 0;
unsigned long pollCount = 0;

void loop() {
  server.handleClient();

  if (!firebaseReady) {
    delay(100);
    return;
  }

  if (!Firebase.ready()) {
    delay(100);
    return;
  }

  // Poll Firebase every 500ms
  if (millis() - lastFirebaseCheck > 500) {
    lastFirebaseCheck = millis();
    pollCount++;

    String path = targetBasePath + "/ESP32_LED/isOn";

    // Debug every 20 polls (~10 seconds)
    if (pollCount % 20 == 1) {
      Serial.print("[POLL #");
      Serial.print(pollCount);
      Serial.print("] Reading: ");
      Serial.println(path);
    }

    if (Firebase.RTDB.getBool(&fbdo, path)) {
      bool targetState = fbdo.boolData();

      // Debug every 20 polls
      if (pollCount % 20 == 1) {
        Serial.print("[POLL #");
        Serial.print(pollCount);
        Serial.print("] Value: ");
        Serial.println(targetState ? "true" : "false");
      }

      if (targetState != ledState) {
        ledState = targetState;
        digitalWrite(LED_PIN, ledState ? HIGH : LOW);

        if (ledState) {
          Serial.println("LED ON");
        } else {
          Serial.println("LED OFF");
        }
      }
    } else {
      Serial.print("[ERROR] Firebase read failed: ");
      Serial.println(fbdo.errorReason());
    }
  }

  delay(2);
}
