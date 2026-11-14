
import os
import json
import uuid
from datetime import datetime, timezone, timedelta
from functools import wraps
from urllib.parse import quote

import firebase_admin
from firebase_admin import credentials, firestore, auth, messaging
from flask import Flask, request, jsonify
from flask_cors import CORS
from supabase import create_client
from google.api_core.exceptions import Conflict

app = Flask(__name__)
# Allow Flutter Web development requests to read incidents.
# Authentication is still required by the endpoint.
CORS(
    app,
    resources={
r"/incidents(?:/[^/]+/video-url)?": {            "origins": [
                r"^http://localhost(:[0-9]+)?$",
                r"^http://127\.0\.0\.1(:[0-9]+)?$",
            ],
            "methods": ["GET", "OPTIONS"],
            "allow_headers": ["Authorization", "Content-Type"],
        }
    },
)
# Environment variables
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SECRET_KEY = os.environ.get("SUPABASE_SECRET_KEY")
SUPABASE_BUCKET = os.environ.get("SUPABASE_BUCKET", "incident-videos")
DEVICE_API_TOKEN = os.environ.get("DEVICE_API_TOKEN")
FIREBASE_SERVICE_ACCOUNT = os.environ.get("FIREBASE_SERVICE_ACCOUNT")

# Check required variables
required_variables = {
    "SUPABASE_URL": SUPABASE_URL,
    "SUPABASE_SECRET_KEY": SUPABASE_SECRET_KEY,
    "DEVICE_API_TOKEN": DEVICE_API_TOKEN,
    "FIREBASE_SERVICE_ACCOUNT": FIREBASE_SERVICE_ACCOUNT,
}

missing_variables = [
    name for name, value in required_variables.items() if not value
]

if missing_variables:
    raise RuntimeError(
        "Missing environment variables: " + ", ".join(missing_variables)
    )

# Firebase connection
firebase_info = json.loads(FIREBASE_SERVICE_ACCOUNT)

if not firebase_admin._apps:
    firebase_credential = credentials.Certificate(firebase_info)
    firebase_admin.initialize_app(firebase_credential)

db = firestore.client()

# Send FCM alerts to officers assigned to the wearable device
def send_incident_notifications(device_id, event_id, detection_type):
    officers = (
        db.collection("Users")
        .where("deviceId", "==", device_id)
        .stream()
    )

    notifications_sent = 0

    for officer in officers:
        officer_data = officer.to_dict() or {}

        if officer_data.get("role") != "officer":
            continue

        fid = officer_data.get("fcmInstallationId")

        if not isinstance(fid, str) or not fid.strip():
            continue

        message = messaging.Message(
            fid=fid.strip(),
            data={
                "incidentId": str(event_id),
                "title": "Raqeeb Alert",
                "body": f"Weapon detected: {detection_type}",
                "type": str(detection_type),
                "sentAt": str(
                    int(datetime.now(timezone.utc).timestamp() * 1000)
                ),
            },
            android=messaging.AndroidConfig(
                priority="high"
            ),
        )

        try:
            messaging.send(message)
            notifications_sent += 1
            app.logger.info(
                "FCM alert sent for incident %s", event_id
            )
        except Exception:
            app.logger.exception(
                "FCM failed for incident %s", event_id
            )

    return notifications_sent


# Supabase connection
supabase = create_client(
    SUPABASE_URL,
    SUPABASE_SECRET_KEY
)

# Device authentication
def require_device_token(function):
    @wraps(function)
    def wrapper(*args, **kwargs):
        provided_token = request.headers.get("X-Device-Token")

        if provided_token != DEVICE_API_TOKEN:
            return jsonify({
                "success": False,
                "message": "Unauthorized"
            }), 401

        return function(*args, **kwargs)

    return wrapper

# Officer authentication using Firebase ID Token
def require_officer_auth(function):
    @wraps(function)
    def wrapper(*args, **kwargs):
        authorization = request.headers.get("Authorization", "")

        if not authorization.startswith("Bearer "):
            return jsonify({
                "success": False,
                "message": "Authentication required"
            }), 401

        token = authorization.removeprefix("Bearer ").strip()

        try:
            decoded_token = auth.verify_id_token(token)
        except Exception:
            return jsonify({
                "success": False,
                "message": "Invalid or expired token"
            }), 401

        request.officer_uid = decoded_token["uid"]
        return function(*args, **kwargs)

    return wrapper

# Home
@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "success": True,
        "message": "Raqeeb Flask Server is running!"
    })


# Health check
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "online",
        "server": "Raqeeb"
    })


# Raspberry Pi heartbeat
@app.route("/device/heartbeat", methods=["POST"])
@require_device_token
def device_heartbeat():
    data = request.get_json(silent=True) or {}

    device_id = data.get("deviceId")
    detection_status = data.get("detectionStatus")

    if device_id != "raqeeb-001":
        return jsonify({
            "success": False,
            "message": "Invalid device ID"
        }), 400

    if detection_status not in ["running", "stopped"]:
        return jsonify({
            "success": False,
            "message": "Invalid detection status"
        }), 400

    db.collection("devices").document(device_id).set({
        "deviceId": device_id,
        "detectionStatus": detection_status,
        "lastSeen": firestore.SERVER_TIMESTAMP
    }, merge=True)

    return jsonify({
        "success": True,
        "message": "Heartbeat received"
    })


# Raspberry Pi status
@app.route("/device/status", methods=["GET"])
@require_device_token
def device_status():
    device_id = "raqeeb-001"

    document = (
        db.collection("devices")
        .document(device_id)
        .get()
    )

    if not document.exists:
        return jsonify({
            "success": True,
            "deviceId": device_id,
            "online": False,
            "detectionStatus": "unknown"
        })

    device_data = document.to_dict()
    last_seen = device_data.get("lastSeen")
    online = False

    if last_seen:
        current_time = datetime.now(timezone.utc)
        time_difference = current_time - last_seen
        online = time_difference <= timedelta(seconds=90)

    return jsonify({
        "success": True,
        "deviceId": device_id,
        "online": online,
        "detectionStatus": device_data.get(
            "detectionStatus", "unknown"
        )
    })


# Receive a confirmed weapon detection and send an immediate FCM alert
@app.route("/incident/start", methods=["POST"])
@require_device_token
def start_incident():
    data = request.get_json(silent=True) or {}

    event_id = str(data.get("eventId") or "").strip()
    device_id = str(data.get("deviceId") or "").strip()
    detection_type = str(
        data.get("detectionType") or ""
    ).strip().lower()

    if device_id != "raqeeb-001":
        return jsonify({
            "success": False,
            "message": "Invalid device ID"
        }), 400

    try:
        uuid.UUID(event_id)
    except (ValueError, AttributeError):
        return jsonify({
            "success": False,
            "message": "A valid UUID eventId is required"
        }), 400

    if detection_type not in ("pistol", "knife"):
        return jsonify({
            "success": False,
            "message": "Invalid detection type"
        }), 400

    confidence = data.get("confidence")

    if confidence is not None:
        try:
            confidence = float(confidence)
        except (TypeError, ValueError):
            return jsonify({
                "success": False,
                "message": "Invalid confidence"
            }), 400

        if not 0 <= confidence <= 1:
            return jsonify({
                "success": False,
                "message": "Confidence must be between 0 and 1"
            }), 400

    incident_ref = db.collection("incidents").document(event_id)

    try:
        incident_ref.create({
            "eventId": event_id,
            "deviceId": device_id,
            "detectionType": detection_type,
            "confidence": confidence,
            "createdAt": firestore.SERVER_TIMESTAMP,
        })
    except Conflict:
        return jsonify({
            "success": True,
            "eventId": event_id,
            "duplicate": True,
            "notificationsSent": 0
        }), 200

    notifications_sent = send_incident_notifications(
        device_id,
        event_id,
        detection_type
    )

    return jsonify({
        "success": True,
        "eventId": event_id,
        "notificationsSent": notifications_sent
    }), 201

# Create signed video upload URL
@app.route("/video/upload-url", methods=["POST"])
@require_device_token
def create_video_upload_url():
    data = request.get_json(silent=True) or {}

    event_id = data.get("eventId")

    if not event_id:
        event_id = str(uuid.uuid4())

    filename = f"{uuid.uuid4()}.h264"
    video_path = f"incidents/{event_id}/{filename}"

    response = (
        supabase.storage
        .from_(SUPABASE_BUCKET)
        .create_signed_upload_url(video_path)
    )

    upload_token = response.get("token")

    if not upload_token:
        return jsonify({
            "success": False,
            "message": "Could not create upload token"
        }), 500

    upload_url = (
        f"{SUPABASE_URL}/storage/v1/object/upload/sign/"
        f"{SUPABASE_BUCKET}/{quote(video_path, safe='/')}"
        f"?token={quote(upload_token)}"
    )

    return jsonify({
        "success": True,
        "eventId": event_id,
        "bucket": SUPABASE_BUCKET,
        "path": video_path,
        "token": upload_token,
        "uploadUrl": upload_url
    })


# Save incident information in Firestore
@app.route("/video/complete", methods=["POST"])
@require_device_token
def complete_video_upload():
    data = request.get_json(silent=True) or {}

    event_id = data.get("eventId")
    video_path = data.get("videoPath")

    if not event_id or not video_path:
        return jsonify({
            "success": False,
            "message": "eventId and videoPath are required"
        }), 400

    if not video_path.startswith(f"incidents/{event_id}/"):
        return jsonify({
            "success": False,
            "message": "Invalid video path"
        }), 400

    event_data = {
        "eventId": event_id,
        "deviceId": "raqeeb-001",
        "videoPath": video_path,
        "bucket": SUPABASE_BUCKET,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "detectionType": data.get("detectionType", "unknown"),
        "confidence": data.get("confidence")
    }

    db.collection("incidents").document(event_id).set(
        event_data,
        merge=True
    )

    return jsonify({
        "success": True,
        "message": "Incident saved",
        "eventId": event_id
    })


# Create signed video download URL
@app.route("/video/download-url", methods=["POST"])
@require_device_token
def create_video_download_url():
    data = request.get_json(silent=True) or {}

    video_path = data.get("videoPath")

    if not video_path:
        return jsonify({
            "success": False,
            "message": "videoPath is required"
        }), 400

    response = (
        supabase.storage
        .from_(SUPABASE_BUCKET)
        .create_signed_url(video_path, 3600)
    )

    signed_url = response.get("signedURL")

    return jsonify({
        "success": True,
        "signedUrl": signed_url
    })

# Get incidents assigned to the authenticated officer
@app.route("/incidents", methods=["GET"])
@require_officer_auth
def get_incidents():
    officer_uid = request.officer_uid

    officer_doc = (
        db.collection("Users")
        .document(officer_uid)
        .get()
    )

    if not officer_doc.exists:
        return jsonify({
            "success": False,
            "message": "Officer profile not found"
        }), 403

    officer = officer_doc.to_dict() or {}

    if officer.get("role") != "officer":
        return jsonify({
            "success": False,
            "message": "Officer access required"
        }), 403

    device_id = officer.get("deviceId")

    if not device_id:
        return jsonify({
            "success": False,
            "message": "No assigned device"
        }), 403

    documents = (
        db.collection("incidents")
        .where("deviceId", "==", device_id)
        .stream()
    )

    incidents = []

    for doc in documents:
        data = doc.to_dict() or {}
        created_at = data.get("createdAt")

        incidents.append({
            "eventId": doc.id,
            "deviceId": data.get("deviceId"),
            "detectionType": data.get(
                "detectionType", "unknown"
            ),
            "confidence": data.get("confidence"),
            "createdAt": (
                created_at.isoformat()
                if created_at else None
            ),
            "status": data.get("status", "pending"),
            "videoAvailable": bool(data.get("videoPath"))
        })

    incidents.sort(
        key=lambda item: item["createdAt"] or "",
        reverse=True
    )

    return jsonify({
        "success": True,
        "incidents": incidents
    })

# Secure incident video playback for officers
@app.route("/incidents/<event_id>/video-url", methods=["GET"])
@require_officer_auth
def get_incident_video_url(event_id):
    officer_uid = request.officer_uid

    officer_doc = (
        db.collection("Users")
        .document(officer_uid)
        .get()
    )

    if not officer_doc.exists:
        return jsonify({
            "success": False,
            "message": "Officer profile not found"
        }), 403

    officer = officer_doc.to_dict() or {}

    if officer.get("role") != "officer":
        return jsonify({
            "success": False,
            "message": "Officer access required"
        }), 403

    device_id = officer.get("deviceId")

    if not device_id:
        return jsonify({
            "success": False,
            "message": "No assigned device"
        }), 403

    incident_doc = (
        db.collection("incidents")
        .document(event_id)
        .get()
    )

    if not incident_doc.exists:
        return jsonify({
            "success": False,
            "message": "Incident not found"
        }), 404

    incident = incident_doc.to_dict() or {}

    # The officer may only access their assigned device.
    if incident.get("deviceId") != device_id:
        return jsonify({
            "success": False,
            "message": "Access denied"
        }), 403

    video_path = incident.get("videoPath")
    bucket = incident.get("bucket")

    if not video_path or bucket != SUPABASE_BUCKET:
        return jsonify({
            "success": False,
            "message": "Video unavailable"
        }), 404

    if not video_path.startswith(f"incidents/{event_id}/"):
        return jsonify({
            "success": False,
            "message": "Invalid video path"
        }), 400

    response = (
        supabase.storage
        .from_(SUPABASE_BUCKET)
        .create_signed_url(video_path, 300)
    )

    signed_url = response.get("signedURL")

    if not signed_url:
        return jsonify({
            "success": False,
            "message": "Could not generate video URL"
        }), 500

    return jsonify({
        "success": True,
        "eventId": event_id,
        "signedUrl": signed_url
    })

# Run Flask server
if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 5000))
    )
