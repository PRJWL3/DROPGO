# DropGo (TaxiTown) 🚕

A premium ride-booking application inspired by Ola/Uber/Rapido/BlaBla, built with Flutter, Riverpod, and Google Maps API.

> [!IMPORTANT]
> **Developer Mode Notice**: This application is currently in active development / developer mode. Some configurations, mock simulations, and APIs are tailored for development testing.

---

## 🚀 Features

- **Draggable Bottom Sheets**: Rapido/Uber-style draggable sheets for home search, category selection, and live tracking.
- **Dual-Field Search**: Completely separate inputs for Pickup and Destination with real-time autocompletes, custom markers, and recent paths.
- **Real Road Routing**: Uses Google Directions/Routes API to draw true road paths and polylines rather than basic straight lines.
- **Dynamic Camera Fitting**: Autocenter and fit map camera bounds to cover the rider, driver, and destination.
- **Live Simulator**: Integrates driver live-tracking simulation, updates trip status, and triggers support SOS features.

---

## 🛠️ Tech Stack

- **Framework**: Flutter (Web & Mobile support)
- **State Management**: Riverpod
- **Map & Routing**: Google Maps SDK & Google Directions Service JS interop (Web)
- **Styling**: Modern premium design tokens (white-and-blue theme, custom pins, soft shadows)

---

## ⚙️ Setup & Run

### 1. Prerequisites
Ensure you have the Flutter SDK installed on your machine.
- [Flutter SDK Installation Guide](https://docs.flutter.dev/get-started/install)

### 2. Dependencies
Clone the repository and fetch the pub packages:
```bash
flutter pub get
```

### 3. Run the App
To run the app locally on your development server (e.g. Chrome / Web):
```bash
flutter run -d chrome
```

For production builds:
```bash
flutter build web
```

---

## 🧑‍💻 Repository State & Contribution

This application is in **Developer Mode**. Mock services are utilized for route computations and driver tracking simulation profiles.
