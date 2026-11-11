# On-device food model

The Recognise tile on the add-food screen uses Google's AIY
"Vision Classifier Food V1": a MobileNet image classifier for 2,023 foods
and dishes, TFLite with label metadata, licensed Apache 2.0.

The files are not committed. `.github/workflows/build-personal-apk.yml`
downloads them here before building:

- `aiy_food_v1.tflite` — the model
- `aiy_food_v1_labelmap.csv` — its label list (a fallback if the model's
  metadata has no names)

For a local build, put the two files here yourself. Without them the app
still builds; Recognise then only reads the brand and name printed on packs.

Model card: https://www.kaggle.com/models/google/aiy/tfLite/vision-classifier-food-v1
