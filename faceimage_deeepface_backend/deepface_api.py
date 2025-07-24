from flask import Flask, request, jsonify
from deepface import DeepFace
import numpy as np
import cv2

app = Flask(__name__)

@app.route("/verify", methods=["POST"])
def verify():
    try:
        # Read uploaded images
        img1 = request.files["img1"]
        img2 = request.files["img2"]

        # Convert bytes to OpenCV images (NumPy arrays)
        img1_np = cv2.imdecode(np.frombuffer(img1.read(), np.uint8), cv2.IMREAD_COLOR)
        img2_np = cv2.imdecode(np.frombuffer(img2.read(), np.uint8), cv2.IMREAD_COLOR)

        # Verify faces
        result = DeepFace.verify(img1_np, img2_np, enforce_detection=False)
        return jsonify(result)
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
