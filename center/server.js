require('dotenv').config();

console.log("ENV CHECK:");
console.log(process.cwd());
console.log(process.env.DB_USER);
console.log(process.env.DB_PASSWORD);
console.log(process.env.DB_NAME);

const express = require('express');
const { Pool } = require('pg');
const mqtt = require('mqtt');

const app = express();
app.use(express.json());

const cors = require('cors');
app.use(cors());
/* =========================
   CONFIG
========================= */
const DEVICE_ID = "esp32_lockrrr_01";
const COMMAND_TOPIC = `lockrrr/${DEVICE_ID}/command`;
const STATUS_TOPIC = `lockrrr/${DEVICE_ID}/status`;

/* =========================
   DATABASE
========================= */
const db = new Pool({
    user: "zach",
    host: "127.0.0.1",
    database: "lockrr_db",
    password: "Knights04##1",
    port: 5432,
});

/* =========================
   MQTT CONNECTION
========================= */
const mqttClient = mqtt.connect('mqtt://127.0.0.1:1883');

mqttClient.on('connect', () => {
    console.log("✅ MQTT connected");
        const topic = "lockrrr/esp32_lockrrr_01/status"
        mqttClient.subscribe(topic, (err) => {
        if (err) {
            console.error("❌ Subscribe failed:", err);
        } else {
            console.log("📡 Subscribed to", topic);
        }
    });
});

mqttClient.on('error', (err) => {
    console.error("❌ MQTT error:", err.message);
});

mqttClient.on('offline', () => {
    console.log("⚠️ MQTT offline");
});

mqttClient.on('reconnect', () => {
    console.log("🔄 MQTT reconnecting...");
});
/* =========================
   HANDLE ESP32 STATUS
========================= */
mqttClient.on('message', async (topic, message) => {
    try {
        const data = JSON.parse(message.toString());

        console.log("📩 STATUS RECEIVED:", data);

        const { deviceId, status } = data;

        // Translate to your DB format
        const event_type = status === "LOCKED" ? "lock" : "unlock";

        await db.query(
            "INSERT INTO box_events (box_id, event_type) VALUES ($1, $2)",
            [1, event_type]
        );

        console.log("✅ Stored in DB");

    } catch (err) {
        console.error("❌ MQTT ERROR:", err);
    }
});

/* =========================
   SEND COMMANDS TO ESP32
========================= */
function sendCommand(action) {
    const topic = "lockrrr/esp32_lockrrr_01/command";
    const message = JSON.stringify({ action: action });

    console.log("Publishing:", topic, message);

    mqttClient.publish(topic, message);
}

/* =========================
   API ROUTES (FOR TESTING)
========================= */

// Unlock endpoint
app.post("/api/unlock", (req, res) => {
    sendCommand("UNLOCK");
    res.json({ status: "unlock command sent" });
});
app.post("/api/unlock", (req, res) => {
    if (req.headers['x-api-key'] !== "ayeyoulockingthatbadboyup67") {
        return res.status(403).send("Forbidden");
    }

    sendCommand("UNLOCK");
    res.json({ status: "unlock command sent" });
});

// Lock endpoint
app.post("/api/lock", (req, res) => {
    sendCommand("LOCK");
    res.json({ status: "lock command sent" });
});

/* =========================
   START SERVER
========================= */
app.listen(3000, () => {
    console.log("🚀 Server running on port 3000");
});
