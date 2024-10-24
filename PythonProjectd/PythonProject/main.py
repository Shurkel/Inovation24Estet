from flask import Flask, request, jsonify
import os
import math
import librosa
import numpy as np
from keras.models import load_model
from spafe.features.gfcc import gfcc
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes


data = {
    "mapping": ["normal", "sick"],
    "gfcc": [],
    "labels": [],
    "patient": []
}

# Helper function to extract patient number from filename
def get_patient_number_from_name(filename):
    dp = filename.split("_")[0]
    if dp[0].isalpha():
        return int(dp[2:])
    else:
        return int(dp)

# Function to calculate spectral centroid
def get_spectral_centroid(signal, sr, frame_size=2048, hop_length=512):
    sc = librosa.feature.spectral_centroid(y=signal, sr=sr, n_fft=frame_size, hop_length=hop_length)[0]
    return sc

# Function to save GFCC features
def save_gfcc(file_path, patient_no):
    signal, sr = librosa.load(file_path, sr=4000)
    duration = librosa.get_duration(y=signal, sr=sr)
    no_of_cycles = math.floor(duration / 2.5 - 1)

    sc = get_spectral_centroid(signal, sr=sr, frame_size=1024, hop_length=512)
    max_times = []
    v_starts = []
    v_ends = []
    while len(max_times) < no_of_cycles:
        ind_max = np.argmax(sc)
        t_max = librosa.frames_to_time(ind_max, sr=sr, hop_length=512)
        if t_max - 0.8 < 0 or t_max + 1.7 > duration:
            sc[ind_max] = -100
        else:
            max_times.append(t_max)
            v_starts.append(t_max - 0.8)
            v_ends.append(t_max + 1.7)
            start = math.floor((t_max - 0.8) * sr)
            finish = math.floor((t_max + 1.7) * sr)
            segment = signal[start:finish]
            gfccs = gfcc(sig=segment, fs=sr, num_ceps=20, nfft=512)
            data["gfcc"].append(gfccs.tolist())
            data["patient"].append(patient_no)
            indices = range(ind_max - 5, ind_max + 12)
            for i in indices:
                sc[i] = -100

# Function to predict based on GFCC features
def predict_new(file_path, patient_number):
    data["gfcc"].clear()
    data["labels"].clear()
    data["patient"].clear()

    save_gfcc(file_path=file_path, patient_no=patient_number)

    model = load_model("./models/model.keras")
    results = (model.predict(np.array(data["gfcc"])) > 0.5).astype(int)

    ct1 = sum(1 for result in results if result[0] == 1)
    ct0 = len(results) - ct1

    if len(results) > 0:
        if ct1 > ct0:
            confidence = (ct1 * 100.0) / len(results)  # Calculate confidence
            return {"result":  "Dr. Ai Bot is {0:.2f}% sure that the patient is sick".format(confidence)}
        else:
            confidence = (ct0 * 100.0) / len(results)  # Calculate confidence
            return {"result":  "Dr. Ai Bot is {0:.2f}% sure that the patient is healthy".format(confidence)}
    else:
        return {"result": "No prediction could be made. Please check the input."}


# Endpoint to upload the .wav file and get the prediction
@app.route('/predict', methods=['POST'])
def predict():
    if 'file' not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files['file']
    filename = file.filename
    patient_no = get_patient_number_from_name(filename)

    filepath = os.path.join("./uploaded_files", filename)
    file.save(filepath)

    try:
        result = predict_new(filepath, patient_no)
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    if not os.path.exists('./uploaded_files'):
        os.makedirs('./uploaded_files')
    app.run(debug=True)

