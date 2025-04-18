# ClimbingTracker99

A comprehensive iOS app for tracking climbing training progress, nutrition, and health metrics. Built with SwiftUI and SwiftData.

## Features

### Training Tracking
- Record and manage climbing training sessions
- Track exercise progress and statistics
- Set and monitor weekly training goals
- View training history and trends

### Health Monitoring
- Track weight changes over time
- Visualize weight progress with graphs
- Set and monitor weight goals
- Record detailed health metrics

### Nutrition Management
- Log daily nutrition entries
- Create and manage custom meals
- Track macronutrients (protein, carbs, fat)
- Monitor calorie intake

### Widget Support
- Home screen widget showing key metrics
- Real-time updates for training and weight progress
- Compact and informative design

## Technical Details

- Built with SwiftUI and SwiftData
- iOS 17.0+ compatible
- Uses WidgetKit for widget functionality
- Implements app groups for data sharing between app and widget

## Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- Swift 5.9 or later

### Installation
1. Clone the repository
```bash
git clone https://github.com/ivoyovchev/climbingtracker99.git
```

2. Open the project in Xcode
```bash
cd climbingtracker99
open climbingtracker99.xcodeproj
```

3. Build and run the project

### Widget Setup
1. Add the widget to your home screen
2. Grant necessary permissions when prompted
3. The widget will automatically sync with the main app

## Project Structure

```
climbingtracker99/
├── Models/              # Data models and SwiftData schemas
├── Views/               # SwiftUI views
├── Widgets/             # Widget extension code
├── Assets.xcassets/     # App assets and resources
└── climbingtracker99App.swift  # App entry point
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

Ivo Yovchev - [GitHub](https://github.com/ivoyovchev) 