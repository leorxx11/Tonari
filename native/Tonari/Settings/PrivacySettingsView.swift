import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage(PrivacyShield.preferenceKey) private var blur = true

    var body: some View {
        List {
            Section {
                Toggle("后台模糊", isOn: $blur)
            } footer: {
                Text("切到后台或打开多任务界面时模糊画面，切换器里不显示内容。")
            }
        }
        .navigationTitle("隐私")
        .navigationBarTitleDisplayMode(.inline)
    }
}
