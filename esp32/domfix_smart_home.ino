/**
 * DomFix ESP32 Smart Home Controller
 * Production-ready firmware for IoT device control
 * 
 * Hardware:
 * - ESP32 Dev Board
 * - 2-Channel 5V Relay Module
 * - Servo Motor (SG90)
 * - DHT11 Temperature/Humidity Sensor
 * - LDR Light Sensor
 * - 220V Lamp
 * - Fan
 * 
 * Features:
 * - Real-time Firebase sync
 * - Auto WiFi reconnect
 * - Heartbeat monitoring
 * - Safe relay control
 * - Sensor data streaming
 * 
 * @version 1.0.0
 * @author DomFix Team
 */

#include <WiFi.h>
#include <FirebaseESP32.h>
#include <ESP32Servo.h>
#include <DHT.h>

// WiFi credentials
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Firebase credentials
#define FIREBASE_HOST "YOUR_PROJECT_ID.firebaseio.com"
#define FIREBASE_AUTH "YOUR_FIREBASE_DATABASE_SECRET"
#define USER_ID "YOUR_USER_ID"

// Hardware pins
#define RELAY_LIGHT_PIN 25      // Relay 1 - Living Room Light
#define RELAY_FAN_PIN 26        // Relay 2 - Bedroom Fan
#define SERVO_PIN 27            // Servo - Main Door
#define DHT_PIN 14              // DHT11 - Temperature Sensor
#define LDR_PIN 34              // LDR - Light Sensor (analog)

// Device IDs (match with Firestore document IDs)
String lightDeviceId = "DEVICE_ID_LIGHT";
String fanDeviceId = "DEVICE_ID_FAN";
String doorDeviceId = "DEVICE_ID_DOOR";
String tempDeviceId = "DEVICE_ID_TEMP";
String ldrDeviceId = "DEVICE_ID_LDR";

// Configuration
#define HEARTBEAT_INTERVAL 10000
#define SENSOR_READ_INTERVAL 5000
#define DOOR_OPEN_ANGLE 90
#define DOOR_CLOSE_ANGLE 0

// Firebase objects
FirebaseData firebaseData;
FirebaseAuth auth;
FirebaseConfig config;

// Hardware objects
Servo doorServo;
DHT dht(DHT_PIN, DHT11);

// State variables
bool lightState = false;
bool fanState = false;
bool doorState = false;
unsigned long lastHeartbeat = 0;
unsigned long lastSensorRead = 0;

void setup() {
  Serial.begin(115200);
  Serial.println("\n================================");
  Serial.println("DomFix ESP32 Smart Home");
  Serial.println("================================\n");

  initHardware();
  connectWiFi();
  initFirebase();
  
  dht.begin();
  
  Serial.println("System ready!");
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
    return;
  }

  checkDeviceStates();
  
  if (millis() - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    sendHeartbeat();
    lastHeartbeat = millis();
  }
  
  if (millis() - lastSensorRead >= SENSOR_READ_INTERVAL) {
    readSensors();
    lastSensorRead = millis();
  }
  
  delay(100);
}

void initHardware() {
  Serial.println("Initializing hardware...");
  
  pinMode(RELAY_LIGHT_PIN, OUTPUT);
  pinMode(RELAY_FAN_PIN, OUTPUT);
  
  digitalWrite(RELAY_LIGHT_PIN, LOW);
  digitalWrite(RELAY_FAN_PIN, LOW);
  
  doorServo.attach(SERVO_PIN);
  doorServo.write(DOOR_CLOSE_ANGLE);
  
  Serial.println("Hardware ready");
}

void connectWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi failed!");
  }
}

void initFirebase() {
  Serial.println("Connecting to Firebase...");
  
  Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
  Firebase.reconnectWiFi(true);
  
  Serial.println("Firebase connected!");
}

void checkDeviceStates() {
  String basePath = "smart_devices/" + String(USER_ID) + "/devices/";
  
  if (Firebase.getBool(firebaseData, basePath + lightDeviceId + "/isOn")) {
    bool newState = firebaseData.boolData();
    if (newState != lightState) {
      lightState = newState;
      digitalWrite(RELAY_LIGHT_PIN, lightState ? HIGH : LOW);
      Serial.printf("Light: %s\n", lightState ? "ON" : "OFF");
    }
  }
  
  if (Firebase.getBool(firebaseData, basePath + fanDeviceId + "/isOn")) {
    bool newState = firebaseData.boolData();
    if (newState != fanState) {
      fanState = newState;
      digitalWrite(RELAY_FAN_PIN, fanState ? HIGH : LOW);
      Serial.printf("Fan: %s\n", fanState ? "ON" : "OFF");
    }
  }
  
  if (Firebase.getBool(firebaseData, basePath + doorDeviceId + "/isOn")) {
    bool newState = firebaseData.boolData();
    if (newState != doorState) {
      doorState = newState;
      controlDoor(doorState);
      Serial.printf("Door: %s\n", doorState ? "OPEN" : "CLOSED");
    }
  }
}

void controlDoor(bool open) {
  if (open) {
    for (int angle = DOOR_CLOSE_ANGLE; angle <= DOOR_OPEN_ANGLE; angle++) {
      doorServo.write(angle);
      delay(15);
    }
  } else {
    for (int angle = DOOR_OPEN_ANGLE; angle >= DOOR_CLOSE_ANGLE; angle--) {
      doorServo.write(angle);
      delay(15);
    }
  }
}

void readSensors() {
  String basePath = "smart_devices/" + String(USER_ID) + "/devices/";
  
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  
  if (!isnan(temperature)) {
    Firebase.setFloat(firebaseData, basePath + tempDeviceId + "/value", temperature);
    Serial.printf("Temp: %.1fC, Humidity: %.1f%%\n", temperature, humidity);
  }
  
  int ldrValue = analogRead(LDR_PIN);
  int brightness = map(ldrValue, 0, 4095, 0, 1000);
  
  Firebase.setInt(firebaseData, basePath + ldrDeviceId + "/value", brightness);
  Serial.printf("Brightness: %d lux\n", brightness);
}

void sendHeartbeat() {
  String basePath = "smart_devices/" + String(USER_ID) + "/devices/";
  
  Firebase.setBool(firebaseData, basePath + lightDeviceId + "/isOnline", true);
  Firebase.setBool(firebaseData, basePath + fanDeviceId + "/isOnline", true);
  Firebase.setBool(firebaseData, basePath + doorDeviceId + "/isOnline", true);
  Firebase.setBool(firebaseData, basePath + tempDeviceId + "/isOnline", true);
  Firebase.setBool(firebaseData, basePath + ldrDeviceId + "/isOnline", true);
  
  Serial.println("Heartbeat sent");
}
