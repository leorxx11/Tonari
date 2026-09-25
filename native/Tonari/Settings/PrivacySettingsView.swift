import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage(PrivacyShield.preferenceKey) private var blur = true

    var body: some View {
        List {
            Toggle(isOn: $blur) {
                Text("后台模糊")
                Text("多任务界面里不显示内容")
            }
        }
        .navigationTitle("隐私")
        .navigationBarTitleDisplayMode(.inline)
    }
}
