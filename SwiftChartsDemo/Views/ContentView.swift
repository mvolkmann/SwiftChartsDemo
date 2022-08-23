import Charts
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            HealthChartView()
        }
        // .background(.yellow)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
