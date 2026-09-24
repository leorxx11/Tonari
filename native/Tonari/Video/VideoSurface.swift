import MDKPlayer
import SwiftUI
import UIKit

struct VideoSurface: UIViewRepresentable {
    let player: MDKPlayer

    func makeUIView(context: Context) -> SurfaceView {
        SurfaceView(player: player)
    }

    func updateUIView(_ view: SurfaceView, context: Context) {}

    final class SurfaceView: UIView {
        private let player: MDKPlayer

        init(player: MDKPlayer) {
            self.player = player
            super.init(frame: .zero)
            backgroundColor = .black
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            let scale = window?.screen.scale ?? traitCollection.displayScale
            player.attach(
                surface: self,
                width: Int32(bounds.width * scale),
                height: Int32(bounds.height * scale)
            )
        }
    }
}
