# Climbing Tracker 99

A comprehensive climbing training and progress tracking app for iOS.

## Version 2.1.0

### Major Features
- **Live Record Training** - Record workouts in real-time with automatic timers
- **Running Tracker** - GPS-based running tracking with live map, pace, distance, and detailed post-run statistics (Strava-style)
- Track your climbing training sessions
- Record and analyze different types of exercises
- Monitor your weight and health metrics
- Set and track training goals (including running goals: runs per week and distance per week)
- Capture and organize climbing moments
- View detailed statistics and progress
- Widget support for quick access to key metrics
- **Activity Tab** - Unified view of all training sessions and runs with filtering and swipe-to-delete

### New Exercises (v2.1.0)
- **Circuit** - Circuit route training with two modes:
  - **Free Climbing**: Set number of sets, difficulty, moves per set, and rest time. Features 15-second countdown timer, move counter, and automatic rest periods
  - **Time Based**: Define custom climb/rest intervals (e.g., 30s climb/10s rest, 45s climb/15s rest) with automatic progression and sound cues
- **Core** - Core strength training with configurable sets, training time per set, and rest time. Features automatic timer progression with sound cues
- **Campusing** - Campus board training with:
  - Configurable sets and rest time
  - 15-second prep timer before each set
  - Hold type selection: Edge Size (mm), Balls (Small), or Balls (Medium)
  - Campus bar selection: Quick selection of bars 1-9 hit during each set

### Full-Screen Workout Experience (v2.1.0)
All exercise timers now use dedicated full-screen views for better focus and distraction-free training:
- **All Exercises** - Every exercise type now opens in a full-screen dedicated view
- **Better Focus** - No distractions from other UI elements during workouts
- **Consistent Experience** - Same immersive experience across all exercise types
- **Improved Pause/Resume** - Configuration settings stay hidden when paused, showing only the timer

### Running Feature (v2.1.0)
Complete GPS-based running tracking system:
- **Live Tracking** - Real-time GPS tracking with map visualization
- **Live Statistics** - Current pace, distance, last 1km pace, calories, elevation
- **Lock Screen Widget** - Live Activity showing distance, time, and pace (similar to Uber arrival times)
- **Post-Run Statistics** - Strava-style detailed view with:
  - Route map with elevation profile
  - Splits (per kilometer/mile)
  - Detailed metrics (pace, speed, elevation gain/loss, calories)
  - Time and distance breakdowns
- **Crash Resilience** - Automatic recovery of partial run data if app crashes or loses GPS signal
- **Auto-Save** - Periodic backup of run progress every 30 seconds

### Record Training Feature (v2.0.0)
The Record Training feature allows you to track workouts live with detailed exercise-specific timers:

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

- **Full-Screen Recording Interface** - All exercises use dedicated full-screen views for better focus
- **Automatic Rest Timers** - Configurable rest periods with countdown timers
- **Sound Cues** - Audio feedback for timed exercises
- **Detailed Set Tracking** - Save and review all sets with complete statistics
- **Progress Tracking** - Summary statistics including totals, averages, and progress metrics

### Version 2.1.0 Updates
- Added Circuit, Core, and Campusing exercises with dedicated workout interfaces
- Converted all exercise timers to full-screen dedicated views
- Added running tracking with GPS, maps, and Live Activities
- Implemented Activity tab to replace Training tab with unified view of all activities
- Enhanced weight goal display: shows remaining kilograms instead of percentage
- Improved pause/resume functionality: configuration hidden during pauses
- Fixed Training calendar scrolling issue on dashboard
- Improved crash resilience for running sessions
- Added running goals (runs per week, distance per week) to dashboard

### Previous Updates (v2.0.0)
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
  - Circuit: Sets, moves per set, difficulty, rest time (Free Climbing mode) or custom climb/rest intervals (Time Based mode)
  - Core: Sets, training time per set, rest time between sets
  - Campusing: Sets, hold type (Edge Size/Balls), campus bars hit (1-9), rest time
  - Running: GPS-tracked runs with distance, pace, elevation, splits, and route maps

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