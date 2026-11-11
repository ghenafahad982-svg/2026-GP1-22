import os
import json
import uuid
from datetime import datetime, timezone, timedelta
from functools import wraps
import firebase_admin
from firebase_admin import credentials, firestore
from flask import Flask, request, jsonify
from supabase import create_client
from urllib.parse import quote
# --------------------------------------------------
# 1. تشغيل Flask
# --------------------------------------------------

app = Flask(__name__)


# --------------------------------------------------
# 2. قراءة مفاتيح الخدمات من Render
# --------------------------------------------------

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SECRET_KEY = os.environ.get("SUPABASE_SECRET_KEY")
SUPABASE_BUCKET = os.environ.get("SUPABASE_BUCKET", "incident-videos")

DEVICE_API_TOKEN = os.environ.get("DEVICE_API_TOKEN")
FIREBASE_SERVICE_ACCOUNT = os.environ.get("FIREBASE_SERVICE_ACCOUNT")


# --------------------------------------------------
# 3. التأكد من وجود المفاتيح المطلوبة
# --------------------------------------------------

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


# --------------------------------------------------
# 4. الاتصال بـ Firebase Firestore
# --------------------------------------------------

firebase_info = json.loads(FIREBASE_SERVICE_ACCOUNT)

if not firebase_admin._apps:
    firebase_credential = credentials.Certificate(firebase_info)
    firebase_admin.initialize_app(firebase_credential)

db = firestore.client()


# --------------------------------------------------
# 5. الاتصال بـ Supabase
# --------------------------------------------------

supabase = create_client(
    SUPABASE_URL,
    SUPABASE_SECRET_KEY
)


# --------------------------------------------------
# 6. التحقق من أن الطلب قادم من Raspberry Pi
# --------------------------------------------------

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


# --------------------------------------------------
# 7. الصفحة الرئيسية
# --------------------------------------------------

@app.route("/", methods=["GET"])
def home():

    return jsonify({
        "success": True,
        "message": "Raqeeb Flask Server is running!"
    })


# --------------------------------------------------
# 8. فحص حالة السيرفر
# --------------------------------------------------

@app.route("/health", methods=["GET"])
def health():

    return jsonify({
        "status": "online",
        "server": "Raqeeb"
    })


# --------------------------------------------------
# 9. استقبال Heartbeat من Raspberry Pi
# --------------------------------------------------

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


# --------------------------------------------------
# 10. معرفة حالة Raspberry Pi
# --------------------------------------------------

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


# --------------------------------------------------
# 11. إنشاء رابط مؤقت لرفع فيديو إلى Supabase
# --------------------------------------------------

@app.route("/video/upload-url", methods=["POST"])
@require_device_token
def create_video_upload_url():

    data = request.get_json(silent=True) or {}

    event_id = data.get("eventId")

    if not event_id:
        event_id = str(uuid.uuid4())
    # اسم ملف آمن وبسيط
filename = f"{uuid.uuid4()}.h264"
    video_path = f"incidents/{event_id}/{filename}"
    response = (
        supabase.storage
        .from_(SUPABASE_BUCKET)
        .create_signed_upload_url(video_path)
    )
upload_token = response.get("token")
upload_url = (
    f"{SUPABASE_URL}/storage/v1/object/upload/sign/"
    f"{SUPABASE_BUCKET}/{quote(video_path, safe='/')}"
    f"?token={quote(upload_token)}"
) return jsonify({
        "success": True,
        "eventId": event_id,
        "bucket": SUPABASE_BUCKET,
        "path": video_path,
        "token": upload_token
        "uploadUrl": upload_url,
    })


# --------------------------------------------------
# 12. حفظ بيانات الحادث بعد رفع الفيديو
# --------------------------------------------------

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

    # التأكد أن مسار الفيديو داخل مجلد الحوادث
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


# --------------------------------------------------
# 13. إنشاء رابط مؤقت لمشاهدة فيديو من Supabase
# --------------------------------------------------

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

    # مكتبة Supabase Python ترجع بيانات الرابط ضمن response
    signed_url = response.get("signedURL")

    return jsonify({
        "success": True,
        "signedUrl": signed_url
    })


# --------------------------------------------------
# 14. تشغيل السيرفر محلياً
# --------------------------------------------------

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 5000))
    )
