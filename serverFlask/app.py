
import os
import json
import uuid
from datetime import datetime, timezone, timedelta
from functools import wraps
from urllib.parse import quote

import firebase_admin
from firebase_admin import credentials, firestore, auth
from flask import Flask, request, jsonify
from supabase import create_client

app = Flask(__name__)

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

# Run Flask server
if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 5000))
    )
