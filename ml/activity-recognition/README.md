# Activity Recognition (CNN-LSTM)

This model will recognize abnormal activities, such as fighting and assault, from short sequences of video frames captured by the Raqeeb wearable device. It will run alongside the weapon detection model, so the device can detect threats that do not involve a visible weapon.

## Status

Planned for the second semester (Release 2). The model has not been trained yet, and this folder will hold its notebook and trained weights once development starts.

## Planned approach

- A CNN extracts visual features from each frame.
- An LSTM analyzes the sequence of features to recognize the activity, because an activity such as fighting can only be identified from movement across several frames, not from a single image.

## Dataset

UCF-Crime: 1,900 real-world surveillance videos (about 128 hours) covering 13 anomaly categories in addition to normal activity. Raqeeb will use seven of its categories (Assault, Fighting, Shooting, Road Accidents, Vandalism, Explosion and Arson) together with normal videos. The dataset is released for academic research use and will not be stored in this repository.
