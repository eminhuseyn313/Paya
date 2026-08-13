import WidgetKit
import SwiftUI

@main
struct PayaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RecoveryWidget()
        NutritionWidget()
        HydrationWidget()
        TrainingWidget()
        PayaSessionLiveActivity()
    }
}
