
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
from google.api_core import exceptions as google_exceptions
from google.api_core.exceptions import Conflict

app = Flask(__name__)
# Allow Flutter Web development requests to read incidents.
# Authentication is still required by the endpoint.

CORS(
    app,
    resources={
        r"/auth/employee-login": {
            "origins": [
                r"^http\://localhost(:[0-9]+)?$",
                r"^http\://127\.0\.0\.1(:[0-9]+)?$",
            ],
            "methods": ["POST", "OPTIONS"],
            "allow_headers": ["Content-Type"],
        },
        r"/officer/device-status": {
    "origins": [r"^http://localhost(:[0-9]+)?$", r"^http://127\.0\.0\.1(:[0-9]+)?$"],
    "methods": ["GET", "OPTIONS"],
    "allow_headers": ["Authorization", "Content-Type"],
},
        r"/incidents(?:/[^/]+/(?:video-url|action))?": {
            "origins": [
                r"^http://localhost(:[0-9]+)?$",
                r"^http://127\.0\.0\.1(:[0-9]+)?$",
            ],
            "methods": ["GET", "POST", "OPTIONS"],
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

# Get the assigned device status for the authenticated officer
@app.route("/officer/device-status", methods=["GET"])
@require_officer_auth
def get_officer_device_status():
    officer_doc = db.collection("Users").document(
        request.officer_uid
    ).get()

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

    device_doc = db.collection("devices").document(device_id).get()

    if not device_doc.exists:
        return jsonify({
            "success": True,
            "deviceId": device_id,
            "online": False,
            "detectionStatus": "unknown"
        }), 200

    device_data = device_doc.to_dict() or {}
    last_seen = device_data.get("lastSeen")

    online = False

    if isinstance(last_seen, datetime):
        if last_seen.tzinfo is None:
            last_seen = last_seen.replace(tzinfo=timezone.utc)

        elapsed = datetime.now(timezone.utc) - last_seen
        online = timedelta(0) <= elapsed <= timedelta(seconds=45)

    return jsonify({
        "success": True,
        "deviceId": device_id,
        "online": online,
        "detectionStatus": device_data.get(
            "detectionStatus", "unknown"
        )
    }), 200
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
    "status": "confirmed",
    "readAt": None,
    "dismissedAt": None,
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

    
    incident_ref = db.collection("incidents").document(event_id)

    try:
        incident_ref.update({
            "videoPath": video_path,
            "bucket": SUPABASE_BUCKET,
        })
    except google_exceptions.NotFound:
        return jsonify({
            "success": False,
            "message": "Incident not found. Start incident first."
        }), 404


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
            "status": (
    "dismissed"
    if data.get("status") == "dismissed"
    else "confirmed"
),
"readAt": (
    data["readAt"].isoformat()
    if data.get("readAt") else None
),
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

# Allow an officer to open or dismiss an assigned incident
@app.route("/incidents/<event_id>/action", methods=["POST"])
@require_officer_auth
def update_incident_action(event_id):
    officer_uid = request.officer_uid
    data = request.get_json(silent=True) or {}
    action = data.get("action")

    if action not in ("open", "dismiss"):
        return jsonify({
            "success": False,
            "message": "Invalid action"
        }), 400

    officer_doc = db.collection("Users").document(officer_uid).get()

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


    incident_ref = db.collection("incidents").document(event_id)

    @firestore.transactional
    def apply_action(transaction):
        incident_doc = incident_ref.get(transaction=transaction)

        if not incident_doc.exists:
            return "not_found"

        incident = incident_doc.to_dict() or {}

        if incident.get("deviceId") != device_id:
            return "forbidden"

        if incident.get("status") == "dismissed":
            return "already_dismissed"

        if action == "open":
            if incident.get("readAt") is None:
                transaction.update(incident_ref, {
                    "readAt": firestore.SERVER_TIMESTAMP
                })

        elif action == "dismiss":
            transaction.update(incident_ref, {
                "status": "dismissed",
                "dismissedAt": firestore.SERVER_TIMESTAMP
            })

        return "success"

    transaction = db.transaction()
    result = apply_action(transaction)

    if result == "not_found":
        return jsonify({
            "success": False,
            "message": "Incident not found"
        }), 404

    if result == "forbidden":
        return jsonify({
            "success": False,
            "message": "Access denied"
        }), 403

    if result == "already_dismissed":
        return jsonify({
            "success": False,
            "message": "Incident already dismissed"
        }), 409

    return jsonify({
        "success": True,
        "eventId": event_id,
        "action": action
    }), 200


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

# Log in with employee ID + password, retaining the SAME Firebase user/UID.
# Requires FIREBASE_WEB_API_KEY in the server environment.
# Firebase Authentication is the authority for password verification.
@app.route("/auth/employee-login", methods=["POST"])
def login_by_employee_id():
    from urllib.request import Request, urlopen
    from urllib.error import HTTPError, URLError

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"success": False, "message": "Invalid request"}), 400

    employee_id = str(payload.get("employeeId") or "").strip()
    password = payload.get("password")
    if (not employee_id.isascii() or not employee_id.isdigit()
            or not 1 <= len(employee_id) <= 20
            or not isinstance(password, str) or not password
            or len(password) > 1024):
        return jsonify({"success": False, "message": "Invalid credentials"}), 401

    firebase_api_key = os.environ.get("FIREBASE_WEB_API_KEY")
    if not firebase_api_key:
        app.logger.error("FIREBASE_WEB_API_KEY is not configured")
        return jsonify({"success": False, "message": "Login unavailable"}), 503

    try:
        matches = list(db.collection("Users")
                       .where("employeeId", "==", employee_id)
                       .limit(2).stream())
        if len(matches) != 1:
            return jsonify({"success": False, "message": "Invalid credentials"}), 401

        officer = matches[0].to_dict() or {}
        if officer.get("role") != "officer":
            return jsonify({"success": False, "message": "Invalid credentials"}), 401

        uid = matches[0].id
        # Read the canonical email from Auth, not a user-editable Firestore field.
        auth_user = auth.get_user(uid)
        if auth_user.disabled or not auth_user.email:
            return jsonify({"success": False, "message": "Invalid credentials"}), 401

        verify_url = (
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
            f"?key={firebase_api_key}"
        )
        verify_body = json.dumps({
            "email": auth_user.email,
            "password": password,
            "returnSecureToken": True,
        }).encode("utf-8")
        verify_request = Request(
            verify_url, data=verify_body,
            headers={"Content-Type": "application/json"}, method="POST",
        )
        try:
            with urlopen(verify_request, timeout=12) as response:
                verified = json.load(response)
        except HTTPError:
            return jsonify({"success": False, "message": "Invalid credentials"}), 401
        except (URLError, TimeoutError):
            return jsonify({"success": False, "message": "Login temporarily unavailable"}), 503

        id_token = verified.get("idToken")
        if not isinstance(id_token, str):
            return jsonify({"success": False, "message": "Invalid credentials"}), 401
        verified_uid = auth.verify_id_token(id_token).get("uid")
        if verified_uid != uid:
            return jsonify({"success": False, "message": "Invalid credentials"}), 401

        # Flutter signs into the existing Firebase account using this custom token.
        custom_token = auth.create_custom_token(uid)
        if isinstance(custom_token, bytes):
            custom_token = custom_token.decode("utf-8")
        response = jsonify({"success": True, "customToken": custom_token})
        response.headers["Cache-Control"] = "no-store"
        return response, 200
    except Exception:
        app.logger.exception("Employee login backend error")
        return jsonify({"success": False, "message": "Login temporarily unavailable"}), 503


# Run Flask server
if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 5000))
    )
