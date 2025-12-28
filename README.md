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

3.  Run the app and press the '+' button to import the zip file.

## How to run the app

1.  Install dependencies:
    ```
    flutter pub get
    ```
2.  Run the app:
    ```
    flutter run
    ```