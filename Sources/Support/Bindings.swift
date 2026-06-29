import SwiftUI

extension Binding where Value == String {
    /// 将可选 String 适配为非可选绑定（空串视为 nil）。
    init(_ source: Binding<String?>, replacingNilWith def: String = "") {
        self.init(
            get: { source.wrappedValue ?? def },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
