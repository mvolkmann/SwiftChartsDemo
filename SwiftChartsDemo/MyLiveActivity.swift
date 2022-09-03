/*
 import ActivityKit
 import SwiftUI
 import WidgetKit

 struct HealthAttributes: ActivityAttributes {
     public typealias LiveData = ContentState

     // This is data the changes in the widget.
     public struct ContentState: Codable, Hashable {
         var stepCount: Int
         var miles: Double
     }

     // This is data that remains constant in the widget.
     var name: String
 }

 struct HealthActivityWidget: Widget {
     var body: some WidgetConfiguration {
         ActivityConfiguration(attributesType: HealthAttributes.self) { context in
             VStack {
                 Text("This is not working yet.")
                 /*
                 Text("Steps: \(context.attributes.stepCount)")
                 Text("Miles: \(context.attributes.miles)")
                 */
             }
             .activityBackgroundTint(.red)
         }
     }
 }
 */
