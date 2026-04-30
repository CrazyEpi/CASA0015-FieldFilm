# FieldFilm

FieldFilm is a specialized digital companion designed for analog film photographers. It seamlessly bridges the gap between traditional chemical photography and modern IoT technology. By acting as a virtual darkroom logbook, it solves the "analog dilemma" — the lack of embedded EXIF data in film cameras.

With a single tap, FieldFilm senses the connected environment, instantly capturing precise GPS coordinates, reverse-geocoded locations, and real-time weather data. It also allows photographers to record voice memos to document exposure settings and lighting conditions without removing their gloves in harsh environments. All data is securely synchronized to a serverless backend.

<p align="center">
  <img width="300" height="300" alt="FieldFilm Logo" src="https://github.com/user-attachments/assets/9850bfcc-180a-4af3-a7ca-1b44e3609eea" />
</p>

## Key Features

*   **1-Tap Context Sensing**: Automatically fetches precise GPS data, location names, and real-time weather conditions via the OpenWeather API.
*   **Audio Memos**: Hands-free voice recording and playback to log camera settings, exposure calculations, and creative thoughts.
*   **Film Stock Management**: Dropdown interface to seamlessly keep track of different film stocks (e.g., Kodak Portra, Fujifilm).
*   **Serverless Cloud Sync**: Secure user authentication and real-time database syncing powered by Firebase.
*   **Darkroom Aesthetic**: A high-contrast, dark-mode UI customized with animated transitions, optimized for outdoor visibility and glove-friendly operation.

### Application Preview

<p align="center">
  <img width="250" alt="Login Screen" src="https://github.com/user-attachments/assets/db086c83-4168-4ee4-be57-55964723075c" style="margin-right: 10px;" />
  <img width="250" alt="Registration Screen" src="https://github.com/user-attachments/assets/ad697ad6-0cb7-4a00-828a-0ae2b7167633" style="margin-right: 10px;" />
  <img width="250" alt="Main Feed Video Poster" src="https://github.com/user-attachments/assets/da94d7fc-9581-4a73-8b68-0f94f795a32a" />
</p>

## Frameworks & Dependencies

This application is built entirely with Flutter using a service-oriented architecture. It relies on the following core plugins and versions:

*   **flutter**: sdk
*   **firebase_core**: ^3.1.1 (Firebase initialization)
*   **firebase_auth**: ^5.1.1 (User authentication)

*   **cloud_firestore**: ^5.0.2 (Serverless NoSQL database)
*   **geolocator**: ^11.0.0 (Hardware GPS sensing)
*   **geocoding**: ^3.0.0 (Reverse geocoding for addresses)
*   **http**: ^1.2.0 (External API requests)
*   **record**: ^6.2.0 (Voice memo audio capturing)
*   **audioplayers**: ^5.2.1 (Audio playback management)
*   **path_provider**: ^2.1.2 (Local file storage for media)
*   **image_picker**: ^1.0.7 (Capturing digital reference photos)
*   **permission_handler**: ^11.3.0 (Robust hardware access management)
*   **flutter_dotenv**: ^5.1.0 (Securing external API keys)
*   **flutter_launcher_icons**: ^0.13.1 (App icon generation)

## Installation and Setup

### Prerequisites

*   Flutter SDK installed.
*   An IDE such as Android Studio or VS Code.
*   Target Device: Tested on Android Emulator (Pixel 9a, API 36/Android 16) and physical Android devices.

### Steps to Run

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/CrazyEpi/CASA0015-FieldFilm.git](https://github.com/CrazyEpi/CASA0015-FieldFilm.git)
    cd CASA0015-FieldFilm
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Environment Variables:**
    Create a `.env` file in the root directory of the project and add your OpenWeather API key:
    ```
    WEATHER_API_KEY=your_openweather_api_key_here
    ```

4.  **Firebase Setup:**
    Ensure you have configured Firebase for your specific application package name. You will need to add your `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) to the respective directories.

5.  **Run the app:**
    ```bash
    flutter run
    ```

## Development Notes

*   **Location Services**: If running on an emulator, native geocoding may occasionally fail. The application includes a fallback mechanism to parse the city name directly from the Weather API response.
*   **Permissions**: The app will request Location and Microphone permissions upon first execution. These are required for core functionality.

## Contact Details

Developed by Haoyu Hu for the UCL CASA0015 Mobile Systems and Interactions module.

If you have any questions regarding the architecture, design, or if you'd like to contribute, feel free to reach out.

*   **GitHub**: [@CrazyEpi](https://github.com/CrazyEpi)
*   **Email**: hhy-cn@outlook.com
*   **Project Page**: [FieldFilm Landing Page](https://crazyepi.github.io/CASA0015-FieldFilm/)
