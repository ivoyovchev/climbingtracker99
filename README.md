# ClimbingTracker99

A comprehensive iOS/macOS app for tracking climbing training progress, health metrics, and nutrition.

## Version 1.0.3

### Features
- Training tracking with customizable exercises
- Weight and health metrics monitoring
- Nutrition tracking
- Photo gallery for training moments
- Widget support for quick progress viewing
- Data visualization with charts and progress bars

### Recent Updates
- Improved exercise recording interface
- Enhanced grade selection for Limit Bouldering
- Consistent header layout across all tabs
- Centered and larger titles
- Improved spacing and visual hierarchy
- Enhanced widget UI

### Requirements
- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### Installation
1. Clone the repository
2. Open `climbingtracker99.xcodeproj` in Xcode
3. Build and run the project

### License
This project is licensed under the MIT License - see the LICENSE file for details.

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

## Author

Ivo Yovchev - [GitHub](https://github.com/ivoyovchev) 