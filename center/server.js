require('dotenv').config();
console.log("🔥 THIS IS THE NEW SERVER FILE");
/* =========================
   IMPORTS
========================= */
const express = require('express');
const { Pool } = require('pg');
const mqtt = require('mqtt');
const cors = require('cors');

/* =========================
   APP SETUP
========================= */
const app = express();
app.use(express.json());
app.use(cors());

/* =========================
   CONFIG
========================= */
const DEVICE_ID = "esp32_lockrrr_01";
const COMMAND_TOPIC = `lockrrr/${DEVICE_ID}/command`;
const STATUS_TOPIC = `lockrrr/${DEVICE_ID}/status`;
const PACKAGE_TOPIC = `lockrrr/${DEVICE_ID}/package`;
const BOX_ID = 1;

/* =========================
   DATABASE (USE .env)
========================= */
const db = new Pool({
    user: process.env.DB_USER,
    host: "127.0.0.1",
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: 5432,
});

/* =========================
   MQTT CONNECTION
========================= */
const mqttClient = mqtt.connect('mqtt://127.0.0.1:1883');

mqttClient.on('connect', () => {
    console.log("✅ MQTT connected");

    mqttClient.subscribe(
        [STATUS_TOPIC, PACKAGE_TOPIC],
        (err) => {
                if (err) {
                console.error("❌ Subscribe failed:", err);
                } else {
                console.log("📡 Subscribed to:");
                console.log("   ", STATUS_TOPIC);
                console.log("   ", PACKAGE_TOPIC);
                }
        }
     );
});

mqttClient.on('error', (err) => {
    console.error("❌ MQTT error:", err.message);
});

mqttClient.on('offline', () => {
    console.log("⚠️ MQTT offline")
});

mqttClient.on('reconnect', () => {
    console.log("🔄 MQTT reconnecting...");
});

/* =========================
   HANDLE ESP32 STATUS
========================= */
mqttClient.on('message', async (topic, message) => {
if (topic === PACKAGE_TOPIC) {

    const data = JSON.parse(message.toString());

    console.log("📦 PACKAGE RECEIVED:", data);

    await db.query(
        `UPDATE box_state
         SET has_package = true,
             last_updated = NOW()
         WHERE box_id = $1`,
        [1]
    );

    console.log("✅ box_state updated");

    return;
}
    try {
        const data = JSON.parse(message.toString());
        console.log("📩 STATUS RECEIVED:", data);

        if (!data) return;

        const { status, event, delta } = data;

        let event_type = null;
        let value = null;

        // Lock/unlock events
        if (status) {
            event_type = status === "LOCKED" ? "lock" : "unlock";
        }

        // Weight events
        if (event === "weight_change") {
            event_type = "weight_change";
            value = delta;
        }

        if (!event_type) {
            console.log("⚠️ Unknown event type:", data);
            return;
        }

        /* ===== INSERT EVENT ===== */
        await db.query(
            "INSERT INTO box_events (box_id, event_type, value) VALUES ($1, $2, $3)",
            [BOX_ID, event_type, value]
        );

        console.log("✅ Stored in DB");

        /* ===== UPDATE STATE ===== */

        // Lock/unlock state
        if (event_type === "lock" || event_type === "unlock") {
            const is_locked = event_type === "lock";

            await db.query(
                `UPDATE box_state
                 SET is_locked = $1, last_updated = NOW()
                 WHERE box_id = $2`,
                [is_locked, BOX_ID]
            );
        }

        // Package detection
        if (event_type === "weight_change") {
            const has_package = value > 0.2; // threshold to avoid noise

            await db.query(
                `UPDATE box_state
                 SET has_package = $1, last_updated = NOW()
                 WHERE box_id = $2`,
                [has_package, BOX_ID]
            );
        }

    } catch (err) {
        console.error("❌ MQTT ERROR:", err);
    }
});

/* =========================
   SEND COMMANDS TO ESP32
========================= */
function sendCommand(action) {
    const message = JSON.stringify({ action });

    console.log("📤 Publishing:", COMMAND_TOPIC, message);

    mqttClient.publish(COMMAND_TOPIC, message);
}

/* =========================
   API ROUTES
========================= */

// 🔓 Unlock (secured)
app.post("/api/unlock", (req, res) => {
    if (req.headers['x-api-key'] !== process.env.API_KEY) {
        return res.status(403).send("Forbidden");
    }

    sendCommand("UNLOCK");
    res.json({ status: "unlock command sent" });
});

// 🔒 Lock
app.post("/api/lock", (req, res) => {
    sendCommand("LOCK");
    res.json({ status: "lock command sent" });
});

/* =========================
   GET ALERTS
========================= */
app.get("/api/alerts", async (req, res) => {
    try {
        const result = await db.query(
            `SELECT event_type, value, timestamp
             FROM box_events
             WHERE box_id = $1
             ORDER BY timestamp DESC
             LIMIT 20`,
            [BOX_ID]
        );

        const alerts = result.rows.map(event => {
            let message = "";

            if (event.event_type === "lock") {
                message = "🔒 Box locked";
            }

            if (event.event_type === "unlock") {
                message = "🔓 Box unlocked";
            }

            if (event.event_type === "weight_change") {
                if (event.value > 0) {
                    message = "📦 Package detected";
                } else {
                    message = "📭 Package removed";
                }
            }

            return {
                message,
                timestamp: event.timestamp
            };
        });

        res.json(alerts);

    } catch (err) {
        console.error(err);
        res.status(500).send("Error fetching alerts");
    }
});

/* =========================
   GET BOX STATE
========================= */
app.get("/api/box-state", async (req, res) => {
    try {
        const result = await db.query(
            `SELECT is_locked, has_package, last_updated
             FROM box_state
             WHERE box_id = $1`,
            [BOX_ID]
        );

        res.json(result.rows[0]);

    } catch (err) {
        console.error("❌ Error fetching box state:", err);
        res.status(500).send("Error fetching box state");
    }
});


//test
app.get("/test", (req, res) => {
    res.send("TEST WORKS");
});
/* =========================
   START SERVER
========================= */
app.listen(3000, () => {
    console.log("🚀 Server running on port 3000");
});
