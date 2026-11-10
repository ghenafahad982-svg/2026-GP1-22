// Raqeeb - Device Heartbeat
// Local Firebase Emulator Testing

const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");
admin.initializeApp();

exports.deviceHeartbeat = onRequest(async (req, res) => {

  if (req.method !== "POST") {
    return res.status(405).send("Method not allowed");
  }

  const {deviceId, detectionStatus} = req.body || {};

  if (deviceId !== "raqeeb-001") {
    return res.status(400).send("Invalid device ID");
  }

  if (!["running", "stopped"].includes(detectionStatus)) {
    return res.status(400).send("Invalid detection status");
  }

  try {
    await admin.firestore()
        .collection("devices")
        .doc(deviceId)
        .set({
          deviceId: deviceId,
          detectionStatus: detectionStatus,
          lastSeen: FieldValue.serverTimestamp(),
        }, {merge: true});

    return res.status(200).json({
      success: true,
      message: "Heartbeat received",
    });

  } catch (error) {
    console.error(error);
    return res.status(500).send("Server error");
  }
});


// Raqeeb - Check Device Connection Status

exports.getDeviceStatus = onRequest(async (req, res) => {
  if (req.method !== "GET") {
    return res.status(405).send("Method not allowed");
  }

  try {
    const device = await admin.firestore()
        .collection("devices")
        .doc("raqeeb-001")
        .get();

    if (!device.exists) {
      return res.status(404).send("Device not found");
    }

    const data = device.data();
    const lastSeen = data.lastSeen;

    if (!lastSeen) {
      return res.status(200).json({
        deviceId: "raqeeb-001",
        status: "offline",
      });
    }

    const currentTime = Date.now();
    const lastSeenTime = lastSeen.toMillis();

    const difference = currentTime - lastSeenTime;

    const status = difference >= 30000
        ? "offline"
        : "online";

    return res.status(200).json({
      deviceId: "raqeeb-001",
      status: status,
      lastSeen: lastSeen.toDate().toISOString(),
    });

  } catch (error) {
    console.error(error);
    return res.status(500).send("Server error");
  }
});
