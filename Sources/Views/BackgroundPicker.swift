import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#else
import PhotosUI
#endif

/// 设置里的「背景图」区块：缩略图 + 选择/更换/移除 + 填充方式 + 暗化/不透明度/模糊。
struct BackgroundSettingsSection: View {
    @AppStorage(BackgroundConfig.fileKey)    private var file = ""
    @AppStorage(BackgroundConfig.scrimKey)   private var scrim = BackgroundConfig.defaultScrim
    @AppStorage(BackgroundConfig.blurKey)    private var blur = BackgroundConfig.defaultBlur
    @AppStorage(BackgroundConfig.fillKey)    private var fillRaw = BackgroundConfig.defaultFill
    @AppStorage(BackgroundConfig.opacityKey) private var opacity = BackgroundConfig.defaultOpacity

    @State private var thumb: Image?
    #if os(iOS)
    @State private var pickerItem: PhotosPickerItem?
    #endif

    private var hasImage: Bool { !file.isEmpty }

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                thumbView
                VStack(alignment: .leading, spacing: 6) {
                    pickButton
                    if hasImage {
                        Button(role: .destructive) { removeImage() } label: {
                            Label(L("settings.bg.remove"), systemImage: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Spacer()
            }

            if hasImage {
                Picker(L("settings.bg.fill"), selection: $fillRaw) {
                    ForEach(BackgroundFill.allCases) { f in Text(L(f.titleKey)).tag(f.rawValue) }
                }
                slider(L("settings.bg.scrim"), value: $scrim, in: 0...1, unit: .percent)
                slider(L("settings.bg.opacity"), value: $opacity, in: 0...1, unit: .percent)
                slider(L("settings.bg.blur"), value: $blur, in: 0...BackgroundConfig.maxBlur, unit: .points)
            }
        } header: {
            Text(L("settings.bg.section"))
        } footer: {
            Text(L("settings.bg.note")).appFont(.caption)
        }
        .task(id: file) { thumb = BackgroundStore.image(for: file) }
    }

    // MARK: 缩略图

    @ViewBuilder private var thumbView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.appFill)
            .frame(width: 72, height: 46)
            .overlay {
                if let thumb {
                    thumb.resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25)))
    }

    // MARK: 选图

    @ViewBuilder private var pickButton: some View {
        let title = hasImage ? L("settings.bg.replace") : L("settings.bg.choose")
        #if os(macOS)
        Button { pickMacOS() } label: { Label(title, systemImage: "photo.badge.plus") }
            .buttonStyle(.borderless)
        #else
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label(title, systemImage: "photo.badge.plus")
        }
        .onChange(of: pickerItem) { _, new in
            Task { await loadIOS(new) }
        }
        #endif
    }

    #if os(macOS)
    private func pickMacOS() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let name = BackgroundStore.save(data, ext: url.pathExtension) else { return }
        setFile(name)
    }
    #else
    private func loadIOS(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let name = BackgroundStore.save(data, ext: "img") else { return }
        setFile(name)
    }
    #endif

    /// 换图：先记旧名，落新名后删旧文件，避免残留。
    private func setFile(_ name: String) {
        let old = file
        file = name
        if old != name { BackgroundStore.remove(old) }
    }

    private func removeImage() {
        let old = file
        file = ""
        BackgroundStore.remove(old)
    }

    // MARK: 滑杆

    private enum SliderUnit { case percent, points }

    @ViewBuilder
    private func slider(_ title: String, value: Binding<Double>,
                        in range: ClosedRange<Double>, unit: SliderUnit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).appFont(.caption)
                Spacer()
                Text(readout(value.wrappedValue, unit))
                    .appFont(.caption, monospaced: true).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func readout(_ v: Double, _ unit: SliderUnit) -> String {
        switch unit {
        case .percent: return "\(Int((v * 100).rounded()))%"
        case .points:  return "\(Int(v.rounded()))pt"
        }
    }
}
