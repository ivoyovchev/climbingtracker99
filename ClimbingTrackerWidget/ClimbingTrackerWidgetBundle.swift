//
//  ClimbingTrackerWidgetBundle.swift
//  ClimbingTrackerWidget
//
//  Created by Ivo Yovchev on 17/04/2025.
//

import WidgetKit
import SwiftUI

@main
struct ClimbingTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClimbingTrackerWidget()
        ClimbingTrackerWidgetControl()
        ClimbingTrackerWidgetLiveActivity()
        RunningLiveActivity()
    }
}
