# Climbing Tracker 99

A comprehensive climbing training and progress tracking app for iOS.

## Version 2.0.0

### Major Features
- **Live Record Training** - Record workouts in real-time with automatic timers
- Track your climbing training sessions
- Record and analyze different types of exercises
- Monitor your weight and health metrics
- Set and track training goals
- Capture and organize climbing moments
- View detailed statistics and progress
- Widget support for quick access to key metrics

### Record Training Feature (v2.0.0)
The new Record Training feature allows you to track workouts live with detailed exercise-specific timers:

- **Live Workout Timer** - Continuous timer that tracks your entire workout session
- **Exercise-Specific Timers:**
  - **Flexibility** - Track time for specific body areas (Arms, Fingers, Back, Legs, Mobility, Core)
  - **Pull-ups** - Track sets with repetitions, added weight, and automatic rest timers
  - **N x Ns** - Track climbing/rest phases with problem completion tracking and grade logging
  - **Board Climbing** - Track routes with board type (MoonBoard, KilterBoard, FrankieBoard), grade, tries, and sent status
  - **Shoulder Lifts** - Track sets with reps, weight, and automatic rest timers with sound cues
  - **Repeaters** - Full countdown timers with hang/rest phases, edge size selection, and sound cues
  - **Edge Pickups** - Similar to Repeaters with grip type selection (Open hand, Half Crimp)
  - **Limit Bouldering** - Track boulder problems with indoor/outdoor type, grade, tries, sent status, and optional names
  - **Max Hangs** - Automatic execution with configurable edge size, hang duration, rest duration, sets, and added weight. Includes 15-second prep timer before first hang
  - **Boulder Campus** - Track sets with number of moves and rest between sets
  - **Deadlifts** - Track sets with weight, repetitions, and rest between sets

- **Full-Screen Recording Interface** - Prevents accidental dismissal with confirmation dialog
- **Automatic Rest Timers** - Configurable rest periods with countdown timers
- **Sound Cues** - Audio feedback for timed exercises (Repeaters, Edge Pickups, Max Hangs)
- **Detailed Set Tracking** - Save and review all sets with complete statistics
- **Progress Tracking** - Summary statistics including totals, averages, and progress metrics

### Previous Updates
- Updated widget UI for a cleaner, flatter design with improved spacing and alignment
- Improved widget design with climbing-specific icons
- Enhanced dashboard view with consistent title styling
- Optimized widget layout for better readability
- Fixed navigation title consistency across tabs
- Improved visual hierarchy in the app

### Requirements
- iOS 17.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Installation
1. Clone the repository
2. Open the project in Xcode
3. Build and run on your device or simulator

### Contributing
Feel free to submit issues and enhancement requests.

### License
This project is licensed under the MIT License - see the LICENSE file for details.

## Features

### Training Tracking
- **Log Training** - Record completed training sessions after the fact
- **Record Training** - Live workout recording with real-time timers and exercise-specific tracking
- Track exercise progress and statistics with detailed metrics
- Set and monitor weekly training goals
- View training history and trends
- Exercise-specific data tracking:
  - Max Hangs: Edge size, hang duration, rest duration, sets, added weight
  - Repeaters/Edge Pickups: Edge size, hang time, rest time, repeats per set, number of sets, grip type (Edge Pickups)
  - Board Climbing: Board type, grade, tries, sent status
  - Limit Bouldering: Boulder type (indoor/outdoor), grade, tries, sent status, optional name
  - Pull-ups/Deadlifts/Shoulder Lifts: Sets, repetitions, weight, rest between sets
  - N x Ns: Problems per set, number of sets, rest duration, grade tracking
  - Boulder Campus: Sets, number of moves, rest between sets
  - Flexibility: Area-specific time tracking (Arms, Fingers, Back, Legs, Mobility, Core)

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