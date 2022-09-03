import Charts
import SwiftUI

struct Player: Identifiable {
    var id: String { name }
    let name: String
    let score: Int
}

let players: [Player] = [
    .init(name: "Mark", score: 6),
    .init(name: "Tami", score: 9),
    .init(name: "Amanda", score: 7),
    .init(name: "Jeremy", score: 10)
]

struct PlayerChartView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Chart(players) { player in
                BarMark(
                    x: .value("Name", player.name),
                    y: .value("Score", player.score)
                )
            }
        }
    }
}

struct PlayerChartView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerChartView()
    }
}
