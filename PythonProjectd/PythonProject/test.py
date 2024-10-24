# This is a sample Python script.
import os
import math
import sys

import librosa
import numpy as np
import keras

from spafe.features.gfcc import gfcc

# Press Shift+F10 to execute it or replace it with your code.
# Press Double Shift to search everywhere for classes, files, tool windows, actions, and settings.
data = {
    "mapping": ["normal", "sick"],
    "gfcc": [],
    "labels": [],
    "patient": []
}


def get_patient_number_from_name(filename):
    dp = filename.split("_")[0]
    if dp[0].isalpha():
        return int(dp[2:])
    else:
        return int(dp)


def get_spectral_centroid(signal, sr, frame_size=2048, hop_length=512):
    sc = librosa.feature.spectral_centroid(y=signal, sr=sr, n_fft=frame_size, hop_length=hop_length)[0]
    return sc


def save_gfcc(dataset_path, patient_no):
    print(dataset_path)
    for i, (dirpath, dirnames, filenames) in enumerate(os.walk(dataset_path)):
        print("Processing folder: {}".format(dirpath))
        for f in filenames:
            print(f + patient_no)
            if f.endswith(".wav") and f.startswith(patient_no):

                print("Found file: {}".format(f))
                file_path = os.path.join(dirpath, f)
                signal, sr = librosa.load(file_path, sr=4000)
                duration = librosa.get_duration(y=signal, sr=sr)
                print("Duration: {}".format(duration))
                duration = librosa.get_duration(y=signal, sr=sr)
                no_of_cycles = math.floor(duration / 2.5 - 1)

                print("Number of cycles: {}".format(no_of_cycles))
                sc = get_spectral_centroid(signal, sr=sr, frame_size=1024, hop_length=512)
                max = []
                v_starts = []
                v_ends = []
                while len(max) < no_of_cycles:

                    ind_max = np.argmax(sc)

                    # print(ind_max)
                    t_max = librosa.frames_to_time(ind_max, sr=sr, hop_length=512)
                    if (t_max - 0.8 < 0 or t_max + 1.7 > duration):
                        sc[ind_max] = -100
                    else:
                        max.append(t_max)
                        v_starts.append(t_max - 0.8)
                        v_ends.append(t_max + 1.7)
                        # print("Segment {} from {} to {}".format(len(max)+1, t_max-0.8, t_max+1.7))
                        start = math.floor((t_max - 0.8) * sr)
                        finish = math.floor((t_max + 1.7) * sr)
                        segment = signal[start:finish]
                        gfccs = gfcc(sig=segment, fs=sr, num_ceps=20, nfft=512)
                        # print(gfccs.shape)
                        data["gfcc"].append(gfccs.tolist())
                        data["patient"].append(patient_no)
                        indices = range(ind_max - 5, ind_max + 12)
                        for i in indices:
                            sc[i] = -100


def predict_new(patient_number):
    data["gfcc"].clear()
    data["labels"].clear()
    data["patient"].clear()

    dataset_path = "./audio"
    save_gfcc(dataset_path=dataset_path, patient_no=patient_number)

    # print data shape
    print("Data shape: {}".format(np.array(data["gfcc"]).shape))
    model = keras.models.load_model("./models/model.keras")
    results = (model.predict(data["gfcc"]) > 0.5).astype(int)

    ct1 = 0
    ct0 = 0
    confidence = 0
    for i, label in enumerate(results):
        if results[i][0] == 1:
            ct1 = ct1 + 1
        else:
            ct0 = ct0 + 1

    print("ct1 = {}, ct0={}, result len={}".format(ct1, ct0, len(results)))
    if ct1 > ct0:
        confidence = ct1 * 100 / len(results)
        with open("./result.txt", "w") as fp:
            fp.write("Dr. Ai Bot is {0:.2f}% sure that the patient is sick".format(confidence))
        print("Dr. Ai Bot is {0:.2f}% sure that the patient is sick".format(confidence))
    else:
        confidence = ct0 * 100 / len(results)
        with open("./result.txt", "w") as fp:
            fp.write("Dr. Ai Bot is {0:.2f}% sure that the patient is healthy".format(confidence))
        print("Dr. Ai Bot is {0:.2f}% sure that the patient is healthy".format(confidence))

    return data


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    predict_new(sys.argv[1])
    # predict_new('101')