# Endura 🏃‍♂️

**Endura** is a comprehensive fitness tracking application built with Flutter. Monitor and analyze your outdoor activities with real-time GPS mapping, detailed performance metrics, and an intuitive user interface. Track running, cycling, walking, hiking, and riding workouts with precision.

## 📋 Features

### Activity Tracking
- **Multiple Activity Types**: Running 🏃, Cycling 🚴, Walking 🚶, Hiking 🥾, Riding 🏍️
- **Real-time GPS Tracking**: Live route mapping with precise location data
- **Comprehensive Metrics**: 
  - Distance (in kilometers)
  - Duration and elapsed time
  - Calories burned (calculated based on activity type)
  - Elevation gain
  - Average speed/pace
- **Pause & Resume**: Start, pause, and resume your workouts seamlessly
- **Live Notifications**: Real-time progress notifications during active workouts

### Activity Management
- **Activity History**: View all your past activities with detailed summaries
- **Activity Details**: Comprehensive breakdowns of each workout including stats and route visualization
- **Route Exploration**: Interactive map view to explore all your recorded routes
- **Activity Filtering**: Organize and view activities by type

### User Features
- **Authentication**: Secure sign-in and sign-up system with local authentication
- **User Profiles**: Personalized user profiles with workout statistics
- **Dark/Light Theme**: Theme customization based on preferences
- **Local Storage**: Efficient offline storage using Hive database

### Map & Exploration
- **Interactive Mapping**: Multi-source tile support for different map styles
- **Route Visualization**: View polylines and markers for your activity routes
- **Map Centering**: Auto-follow and manual recenter during tracking

## 🛠️ Tech Stack

**Framework & State Management:**
- Flutter 3.11+ with Dart
- Riverpod for reactive state management and dependency injection

**Data & Storage:**
- Hive for local-first database architecture
- Cached activities and user data with sync capabilities

**Location & Maps:**
- Geolocator for precise GPS tracking
- Flutter Map with configurable tile sources
- Latlong2 for geographic calculations

**Core Features:**
- Flutter Local Notifications for workout alerts
- Image Picker & Camera for media capture
- Local Auth with biometric support
- UUID for unique identifiers

## 📱 Supported Platforms

- ✅ Android
- ✅ iOS

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (version ^3.11.0)
- Dart (included with Flutter)
- Android Studio / Xcode (for mobile development)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd endure_app
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
- Ensure Android SDK is installed
- Configure signing for release builds in `android/app/build.gradle.kts`
- Grant location and camera permissions in AndroidManifest

#### iOS
- Run `flutter pub get` from the `ios/` directory
- Pod dependencies will be installed automatically
- Configure signing in Xcode (Runner project)

## 📁 Project Structure

```
lib/
├── main.dart              # App entry point and auth gate
├── constants.dart         # Global constants and theme colors
├── signin.dart           # Sign in screen
├── signup.dart           # Sign up screen
├── core/
│   ├── providers/        # State management providers
│   ├── storage/          # Hive database setup and configuration
│   ├── theme/            # App theming (colors, styles)
│   ├── notifications/    # Workout notification service
│   ├── maps/             # Map utilities and tile sources
│   └── utils/            # Helper utilities (formatters, location service)
├── features/
│   ├── home/             # Home screen and activity feed
│   ├── tracking/         # Active workout tracking and map
│   ├── activity/         # Activity details and summary
│   ├── explore/          # Route exploration and visualization
│   ├── profile/          # User profile management
│   └── settings/         # App settings
└── shared/
    └── models/           # Shared data models (CachedActivity, etc.)
```

## 🎯 Architecture

### Activity Tracking Pipeline
The app implements a real-time location tracking pipeline with:
- Configurable distance filters (3m default) to reduce noise and improve accuracy
- GPS accuracy threshold filtering (>20m rejected)
- Per-activity speed validation to eliminate outliers
- Real-time metric calculation: distance, elevation gain, calories, and average pace
- Location history persisted with activity metadata

### State Management Architecture
- **Riverpod Notifier Pattern**: `ActiveWorkoutController` manages workout state
- **WorkoutStatus Enum**: Tracks idle, tracking, and paused states
- **Reactive Listeners**: UI rebuilds only on relevant state changes
- **Timer-based Calculations**: One-second precision timing for duration tracking

### Data Persistence Strategy
- **Hive BoxStore Pattern**: Type-safe local storage with automatic serialization
- **Activity Caching**: In-memory cache with disk persistence
- **Offline-First**: All data operations are synchronous with async sync layer ready
- **Future Backend Integration**: Sync status tracking prepared for cloud API integration

## ⚙️ Configuration

### Dependencies Versions
- `flutter_riverpod`: ^2.0.0
- `hive_flutter`: ^1.1.0
- `flutter_map`: ^7.0.2
- `geolocator`: ^13.0.2
- `image_picker`: ^1.1.2
- `local_auth`: ^2.3.0
- `flutter_local_notifications`: Latest

See `pubspec.yaml` for the complete list of dependencies.

## 🔐 Permissions Required

### Android
- `ACCESS_FINE_LOCATION` - GPS tracking
- `ACCESS_COARSE_LOCATION` - Approximate location
- `CAMERA` - Photo capture
- `READ_EXTERNAL_STORAGE` - Access media
- `WRITE_EXTERNAL_STORAGE` - Save media

### iOS
- `NSLocationWhenInUseUsageDescription` - Location during use
- `NSCameraUsageDescription` - Camera access
- `NSPhotoLibraryUsageDescription` - Photo library access

## 🧪 Testing

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📝 Development Guidelines

### Feature Development
1. Organize features using the Multi-Package Architecture pattern
2. Separate concerns: presentation (UI), application (state/logic), and domain (models)
3. Implement Riverpod providers as immutable services
4. Use sealed classes for discriminated union types in state models
5. Leverage Hive for all persistent data requirements

### Code Quality Standards
- Follow Dart style guide and Effective Dart practices
- Maintain strict null safety across the codebase
- Use const constructors and immutable data classes
- Apply linting rules from `analysis_options.yaml`
- Implement comprehensive error handling and validation

## 🐛 Known Issues & Limitations

- Offline-first design means data syncing requires backend implementation
- Map tile rendering depends on internet connectivity
- Location accuracy varies by device and environment
- Battery consumption is significant during active tracking

## 🔄 Future Enhancements

- [ ] Backend API integration for cloud sync
- [ ] Social feed and community features
- [ ] Challenge system and leaderboards
- [ ] Advanced analytics and insights
- [ ] Wearable device integration
- [ ] AR mode for route visualization
- [ ] Voice coaching during workouts
- [ ] Integration with health apps (Apple Health, Google Fit)

## 📞 Support & Contribution

For issues, feature requests, or contributions, please open an issue or submit a pull request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📚 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [Hive Database](https://docs.hivedb.dev/)
- [Flutter Map](https://github.com/fleaflet/flutter_map)
- [Geolocator Plugin](https://pub.dev/packages/geolocator)

---

Built with ❤️ using Flutter
