# Weapon Detection (YOLO11n)

This model detects visible weapons (pistols and knives) in the camera frames of the Raqeeb wearable device. When a weapon is confirmed, the device vibrates to alert the police officer and the incident is sent to the mobile application and the admin dashboard.

## Dataset

- Weapon Detection Dataset from Kaggle (`mehmetcubukcu/weapon-detection`), licensed under CC BY-SA 4.0.
- 6 classes: pistol, knife, smartphone, purse, bill and card. The non-weapon classes help the model tell weapons apart from objects that are commonly held in the hand.
- 5,002 training, 450 validation and 407 test images.
- The dataset is not stored in this repository. The notebook downloads it automatically.

## Model

- YOLO11n, the smallest model in the YOLO11 family, chosen because it runs in real time on the Raspberry Pi 5.
- Fine-tuned from pretrained weights for 50 epochs (image size 640, batch 16) on an NVIDIA T4 GPU in Google Colab, in about 1 hour and 20 minutes.
- Trained weights: `weights/best.pt` (5.5 MB).

## Results on the test set (407 images)

| Class | Precision | Recall | mAP50 | mAP50-95 |
|---|---|---|---|---|
| pistol | 0.853 | 0.971 | 0.983 | 0.856 |
| knife | 0.978 | 0.861 | 0.967 | 0.663 |
| all classes | 0.817 | 0.763 | 0.846 | 0.677 |

## Alert threshold

The device raises an alert when a pistol or knife is detected with a confidence of 0.40 or higher. At this threshold, weapon detection on the test set reached a precision of 0.99 and a recall of 0.95.

## Files

| File | Description |
|---|---|
| `Raqeeb_weapons_DS.ipynb` | Training, evaluation, threshold selection and live camera test |
| `weights/best.pt` | Trained model weights |

## How to run

1. Open the notebook in Google Colab and select a GPU runtime (T4).
2. Run Cell 1 to install the libraries, download the dataset and load the trained model.
3. Run the evaluation cells (Cells 4 to 6) to reproduce the results, or Cell 10 to test the model live with the laptop camera.

## Next steps

- Fine-tuning the model (v1.1) to reduce misclassification in real scenes, such as a weapon detected as a smartphone.
- Adding real-world images captured at chest level to the training data.
-
