from flask import Flask, request, jsonify
import os
import math
import librosa
import numpy as np
from keras.models import load_model
from spafe.features.gfcc import gfcc
import noisereduce as nr
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

# Save GFCC features with noise reduction
def save_gfcc(file_path, patient_no):
    try:
        signal, sr = librosa.load(file_path, sr=4000)
        print("File loaded successfully.")
        
        # Split the signal into chunks for noise reduction
        chunk_size = sr * 5  # 5-second chunks
        segments = [signal[i:i+chunk_size] for i in range(0, len(signal), chunk_size)]
        reduced_signal = np.concatenate([
            nr.reduce_noise(y=segment, sr=sr) for segment in segments
        ])
        print("Noise reduction applied.")

        duration = librosa.get_duration(y=reduced_signal, sr=sr)
        no_of_cycles = math.floor(duration / 2.5 - 1)

        sc = get_spectral_centroid(reduced_signal, sr=sr, frame_size=1024, hop_length=512)
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
                segment = reduced_signal[start:finish]
                gfccs = gfcc(sig=segment, fs=sr, num_ceps=20, nfft=512)
                data["gfcc"].append(gfccs.tolist())
                data["patient"].append(patient_no)
                indices = range(ind_max - 5, ind_max + 12)
                for i in indices:
                    sc[i] = -100
    except Exception as e:
        print("Error during GFCC extraction or noise reduction:", str(e))
        raise

# Function to predict based on GFCC features
def predict_new(file_path, patient_number):
    data["gfcc"].clear()
    data["labels"].clear()
    data["patient"].clear()

    save_gfcc(file_path=file_path, patient_no=patient_number)

    try:
        model = load_model("./models/model.keras")
        print("Model loaded successfully.")
    except Exception as e:
        print("Error loading model:", str(e))
        raise

    try:
        results = (model.predict(np.array(data["gfcc"])) > 0.5).astype(int)
        print("Prediction results:", results)
    except Exception as e:
        print("Error during model prediction:", str(e))
        raise

    ct1 = sum(1 for result in results if result[0] == 1)
    ct0 = len(results) - ct1

    if len(results) > 0:
        if ct1 > ct0:
            confidence = (ct1 * 100.0) / len(results)  # Calculate confidence
            return {"result": "Dr. Ai Bot is {0:.2f}% sure that the patient is sick".format(confidence)}
        else:
            confidence = (ct0 * 100.0) / len(results)  # Calculate confidence
            return {"result": "Dr. Ai Bot is {0:.2f}% sure that the patient is healthy".format(confidence)}
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
