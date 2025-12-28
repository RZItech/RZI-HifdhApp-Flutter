# Hifdh App

A Flutter application to help memorize Islamic texts.

## How to use

1.  Create a zip file with the following structure:

    ```
    example.zip
    ├── audio
    │   └── chapter_1.mp3
    │   └── chapter_2.mp3
    │   └── ...
    └── data.yml
    ```

2.  The `data.yml` file should have the following structure:

    ```yaml
    name: The Conditions Of Salah
    chapter_1:
      name: Introduction
      arabic: |
        شُرُوطُ الصَّلَاةِ تِسْعَةٌ
        الإسلام
        ...
      translation: |
        The conditions of Salah are nine.
        Islam;
        ...
      audio: audio/chapter_1.mp3
    ```

3.  **Sherpa ONNX Arabic Speech Recognition Model:**
    *   Download the Arabic Sherpa ONNX ASR model (e.g., `sherpa-onnx-conformer-transducer-bpe-20m-ar-2023-01-09.tar.bz2`) from the official Sherpa ONNX GitHub releases: [https://github.com/k2-fsa/sherpa-onnx/releases](https://github.com/k2-fsa/sherpa-onnx/releases)
    *   Extract the downloaded archive. You should find `encoder.onnx`, `decoder.onnx`, `joiner.onnx`, and `tokens.txt` files inside.
    *   Place these four files inside the `assets/models/sherpa_onnx/` directory of this project. The paths should look like `your_project/assets/models/sherpa_onnx/encoder.onnx`, etc.

4.  Run the app and press the '+' button to import the zip file.

## How to run the app

1.  Install dependencies:
    ```
    flutter pub get
    ```
2.  Run the app:
    ```
    flutter run
    ```
