# Weapon Detection (YOLO11n)

This model detects visible weapons (pistols and knives) in the camera frames of the Raqeeb wearable device. When a weapon is detected in 3 consecutive frames, the device vibrates to alert the police officer and the incident is sent to the mobile application and the admin dashboard.

## Dataset

- Weapon Detection Dataset from Kaggle (`mehmetcubukcu/weapon-detection`), licensed under CC BY-SA 4.0.
- 6 classes: pistol, knife, smartphone, purse, bill and card. The non-weapon classes help the model tell weapons apart from objects that are commonly held in the hand.
- 5,002 training, 450 validation and 407 test images.
- The dataset is not stored in this repository. The notebook downloads it automatically.

## Model

YOLO11n, the smallest model in the YOLO11 family, chosen because it runs in real time on the Raspberry Pi 5. It was trained in two stages on an NVIDIA T4 GPU in Google Colab:

1. Base training: the pretrained YOLO11n trained on the dataset for 50 epochs.
2. Fine-tuning for real-world conditions: a higher weight for classification errors and augmentation that imitates the body camera (rotation, scale, perspective and brightness).

Trained weights of the final model: `weights/best.pt` (5.5 MB).

## Results on the test set (407 images)

| Class | Precision | Recall | mAP50 | mAP50-95 |
|---|---|---|---|---|
| pistol | 0.886 | 0.971 | 0.976 | 0.777 |
| knife | 0.984 | 0.871 | 0.957 | 0.634 |
| all classes | 0.867 | 0.796 | 0.891 | 0.667 |

## Alert rule

The device raises an alert when a pistol or knife is detected with a confidence of 0.40 or higher in 3 consecutive frames. At this threshold, weapon detection on the test set reached a precision of 0.97 and a recall of 0.94.

## Files

| File | Description |
|---|---|
| `Raqeeb_weapons_DS.ipynb` | Training, evaluation, threshold selection and live camera test |
| `weights/best.pt` | Final model weights |

## How to run

1. Open the notebook in Google Colab and select a GPU runtime (T4).
2. Run Cell 1 to install the libraries, download the dataset and load the final model.
3. Run Cells 5 to 7 to reproduce the results, or Cell 8 to test the model live with the laptop camera.

## Next steps

- Adding real-world images captured at chest level to the training data.
- Exporting the model to the NCNN format to run on the Raspberry Pi 5.
