import Charts
import SwiftUI

struct HeartChartView: View {
    @StateObject var vm = HealthKitViewModel.shared

    var body: some View {
        VStack {
            Text("Heart Rate (\(vm.heartRate.count))")
                .fontWeight(.bold)

            Chart(vm.heartRate) { heart in
                LineMark(
                    x: .value("Date", heart.date),
                    y: .value("BPM", heart.value)
                )
            }

            /*
            List {
                ForEach(vm.heartRate) { heart in
                    Text("\(heart.date) \(heart.ms) \(heart.value)")
                }
            }
            */
        }
        .padding()
        .task {
            await HealthKitViewModel.shared.load()
        }
    }
}

struct HeartChartView_Previews: PreviewProvider {
    static var previews: some View {
        HeartChartView()
    }
}
