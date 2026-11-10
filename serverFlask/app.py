
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "success": True,
        "message": "Raqeeb Flask Server is running!"
    })

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "online",
        "server": "Raqeeb"
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
