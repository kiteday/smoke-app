import SwiftUI
import UIKit

enum SmokeKind: String, Identifiable {
    case cigarette, vape
    var id: String { rawValue }
    var label: String { self == .cigarette ? "연초" : "전자담배" }
    var imageName: String { self == .cigarette ? "CigarettePack" : "Vape" }
}

enum RitualPhase: Equatable { case ready, drawn, smoking, finished }

@MainActor @Observable
final class SmokeSession {
    var selected: SmokeKind?
    var phase: RitualPhase = .ready
    var remaining = 100
    var puffs: [SmokePuff] = []
    var isBurning = false
    var showIgnitionFlame = false

    @ObservationIgnored private var burnTask: Task<Void, Never>?
    @ObservationIgnored private var vapeBurnTicks = 0

    var hapticsEnabled: Bool { didSet { save(hapticsEnabled, "hapticsEnabled") } }
    var smokeLevel: Int { didSet { save(smokeLevel, "smokeLevel") } }
    var flameColorIndex: Int { didSet { save(flameColorIndex, "flameColorIndex") } }
    var filterColorIndex: Int { didSet { save(filterColorIndex, "filterColorIndex") } }
    var backgroundTheme: Int { didSet { save(backgroundTheme, "backgroundTheme") } }
    var burnEffect: Int { didSet { save(burnEffect, "burnEffect") } }
    var selectedPackIndex: Int { didSet { save(selectedPackIndex, "selectedPackIndex") } }
    var selectedVapeIndex: Int { didSet { save(selectedVapeIndex, "selectedVapeIndex") } }
    var packNickname: String { didSet { UserDefaults.standard.set(packNickname, forKey: "packNickname") } }
    var favoritePacks: Set<Int> { didSet { saveSet(favoritePacks, "favoritePacks") } }
    var favoriteVapes: Set<Int> { didSet { saveSet(favoriteVapes, "favoriteVapes") } }
    var cigaretteCount: Int { didSet { save(cigaretteCount, "cigaretteCount") } }
    var podLevel: Int { didSet { save(podLevel, "podLevel") } }
    var totalCigarettesSmoked: Int { didSet { save(totalCigarettesSmoked, "totalCigarettesSmoked") } }
    var completedPacks: Int { didSet { save(completedPacks, "completedPacks") } }
    var faceIDLockEnabled: Bool { didSet { save(faceIDLockEnabled, "faceIDLockEnabled") } }
    var hasChosenPack: Bool { didSet { save(hasChosenPack, "hasChosenPack") } }
    var hasChosenVape: Bool { didSet { save(hasChosenVape, "hasChosenVape") } }
    var customPacks: [CustomPack] { didSet { saveCustomPacks() } }
    var selectedCustomPackID: UUID? { didSet { UserDefaults.standard.set(selectedCustomPackID?.uuidString, forKey: "selectedCustomPackID") } }

    init() {
        let d = UserDefaults.standard
        hapticsEnabled = d.object(forKey: "hapticsEnabled") == nil ? true : d.bool(forKey: "hapticsEnabled")
        smokeLevel = d.object(forKey: "smokeLevel") == nil ? 1 : d.integer(forKey: "smokeLevel")
        flameColorIndex = d.integer(forKey: "flameColorIndex")
        filterColorIndex = d.integer(forKey: "filterColorIndex")
        backgroundTheme = d.integer(forKey: "backgroundTheme")
        burnEffect = d.integer(forKey: "burnEffect")
        selectedPackIndex = d.integer(forKey: "selectedPackIndex") == 0 ? PackPreset.classic.rawValue : PackPreset.custom.rawValue
        selectedVapeIndex = d.integer(forKey: "selectedVapeIndex")
        packNickname = d.string(forKey: "packNickname") ?? "내 담배"
        favoritePacks = Self.readSet(d.string(forKey: "favoritePacks"))
        favoriteVapes = Self.readSet(d.string(forKey: "favoriteVapes"))
        cigaretteCount = d.object(forKey: "cigaretteCount") == nil ? 20 : d.integer(forKey: "cigaretteCount")
        podLevel = d.object(forKey: "podLevel") == nil ? 100 : d.integer(forKey: "podLevel")
        totalCigarettesSmoked = d.integer(forKey: "totalCigarettesSmoked")
        completedPacks = d.integer(forKey: "completedPacks")
        faceIDLockEnabled = d.bool(forKey: "faceIDLockEnabled")
        if d.object(forKey: "hasChosenPack") == nil {
            // 이전 버전에서 이미 담뱃갑을 골랐다면 최초 선택을 다시 요구하지 않는다.
            hasChosenPack = d.object(forKey: "selectedPackIndex") != nil
        } else {
            hasChosenPack = d.bool(forKey: "hasChosenPack")
        }
        hasChosenVape = d.bool(forKey: "hasChosenVape")
        customPacks = (d.data(forKey: "customPacks").flatMap { try? JSONDecoder().decode([CustomPack].self, from: $0) }) ?? []
        if customPacks.isEmpty, let legacyPhoto = d.data(forKey: "customPackPhotoData") {
            customPacks = [CustomPack(photoData: legacyPhoto)]
        }
        selectedCustomPackID = d.string(forKey: "selectedCustomPackID").flatMap(UUID.init(uuidString:)) ?? customPacks.first?.id
    }

    var inventoryText: String { selected == .cigarette ? "\(cigaretteCount)개비" : "\(podLevel)%" }
    var selectedCustomPack: CustomPack? { customPacks.first { $0.id == selectedCustomPackID } }
    var customPackPhotoData: Data? { selectedCustomPack?.photoData }
    var selectedTitle: String {
        if selected == .cigarette {
            let i = selectedPackIndex.clamped(to: PackPreset.allCases.indices)
            return i == PackPreset.custom.rawValue ? (selectedCustomPack?.name ?? "나의 곽") : PackPreset.allCases[i].name
        }
        return VapePreset.allCases[selectedVapeIndex.clamped(to: VapePreset.allCases.indices)].name
    }
    var actionTitle: String {
        switch phase {
        case .ready: return selected == .cigarette ? "누르면 꺼내져요" : "길게 눌러 사용"
        case .drawn, .smoking: return selected == .vape ? "길게 눌러 사용" : "길게 눌러 피우기"
        case .finished: return "돌아가기"
        }
    }
    var puffCount: Int { [2, 4, 7][smokeLevel.clamped(to: 0...2)] }
    var burnAmount: Int { [2, 3, 1][burnEffect.clamped(to: 0...2)] }

    func select(_ kind: SmokeKind) {
        guard kind == .vape ? podLevel > 0 : cigaretteCount > 0 else { return }
        selected = kind
        phase = .ready
        remaining = kind == .vape ? podLevel : 100
        puffs.removeAll()
        feedback(.medium)
    }

    func beginPress() {
        guard burnTask == nil, let selected else { return }
        if phase == .finished { close(); return }
        if phase == .ready {
            phase = .drawn
            feedback(.medium)
        }
        guard phase == .drawn || phase == .smoking else { return }
        let isFirstIgnition = phase == .drawn

        burnTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled, let self else { return }
            self.phase = .smoking
            self.isBurning = true
            if isFirstIgnition {
                self.showIgnitionFlame = true
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(700))
                    self?.showIgnitionFlame = false
                }
            }
            while !Task.isCancelled, self.remaining > 0 {
                self.consumeStep(for: selected)
                try? await Task.sleep(for: .milliseconds(800))
            }
        }
    }

    func endPress() {
        burnTask?.cancel()
        burnTask = nil
        isBurning = false
    }

    func finishButtonTapped() {
        if phase == .finished { close() }
    }

    func startNext() {
        let available = selected == .cigarette && cigaretteCount > 0
        guard selected != nil, available else { return }
        endPress()
        phase = .ready
        remaining = 100
        puffs.removeAll()
        showIgnitionFlame = false
        feedback(.medium)
    }

    func close() {
        endPress(); showIgnitionFlame = false; selected = nil; phase = .ready; puffs.removeAll()
    }

    func replacePack() {
        guard cigaretteCount == 0 else { return }
        cigaretteCount = 20
        completedPacks += 1
        feedback(.heavy)
    }

    func refillPod() { podLevel = 100; feedback(.medium) }

    @discardableResult
    func addCustomPackPhoto(_ data: Data) -> UUID? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 900
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let photoData = resized.jpegData(compressionQuality: 0.82) else { return nil }
        let pack = CustomPack(name: "나의 곽 \(customPacks.count + 1)", photoData: photoData)
        customPacks.append(pack)
        selectedPackIndex = PackPreset.custom.rawValue
        selectedCustomPackID = pack.id
        return pack.id
    }

    func selectCustomPack(_ id: UUID) {
        selectedPackIndex = PackPreset.custom.rawValue
        selectedCustomPackID = id
        feedback(.light)
    }

    func deleteCustomPack(_ id: UUID) {
        customPacks.removeAll { $0.id == id }
        if selectedCustomPackID == id {
            selectedPackIndex = PackPreset.classic.rawValue
            selectedCustomPackID = nil
        }
        feedback(.medium)
    }

    func renameCustomPack(_ id: UUID, name: String) {
        guard let index = customPacks.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        customPacks[index].name = String(trimmed.prefix(18))
    }
    func toggleFavorite(kind: SmokeKind, index: Int) {
        if kind == .cigarette {
            if favoritePacks.contains(index) { favoritePacks.remove(index) } else { favoritePacks.insert(index) }
        } else {
            if favoriteVapes.contains(index) { favoriteVapes.remove(index) } else { favoriteVapes.insert(index) }
        }
        feedback(.light)
    }
    func isFavorite(kind: SmokeKind, index: Int) -> Bool {
        kind == .cigarette ? favoritePacks.contains(index) : favoriteVapes.contains(index)
    }

    private func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }; UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    private func consumeStep(for kind: SmokeKind) {
        emitSmoke(count: puffCount)
        if kind == .vape {
            vapeBurnTicks += 1
            if vapeBurnTicks.isMultiple(of: 10) {
                podLevel = max(0, podLevel - 1)
                remaining = podLevel
                feedback(.light)
            }
        } else {
            remaining = max(0, remaining - burnAmount)
            feedback(.light)
        }
        guard remaining == 0 else { return }

        phase = .finished
        isBurning = false
        burnTask?.cancel()
        burnTask = nil
        if kind == .cigarette {
            cigaretteCount = max(0, cigaretteCount - 1)
            totalCigarettesSmoked += 1
        }
        guard hapticsEnabled else { return }
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        impact.impactOccurred(intensity: 1)
        Task {
            try? await Task.sleep(for: .milliseconds(140))
            impact.impactOccurred(intensity: 1)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    private func emitSmoke(count: Int) {
        for index in 0..<count {
            let puff = SmokePuff(delay: Double(index) * 0.08, drift: CGFloat.random(in: -75...75))
            puffs.append(puff)
            Task { try? await Task.sleep(for: .seconds(3.2)); puffs.removeAll { $0.id == puff.id } }
        }
    }
    private func save(_ value: Any, _ key: String) { UserDefaults.standard.set(value, forKey: key) }
    private func saveSet(_ value: Set<Int>, _ key: String) {
        UserDefaults.standard.set(value.sorted().map(String.init).joined(separator: ","), forKey: key)
    }
    private func saveCustomPacks() {
        UserDefaults.standard.set(try? JSONEncoder().encode(customPacks), forKey: "customPacks")
    }
    private static func readSet(_ value: String?) -> Set<Int> {
        Set((value ?? "").split(separator: ",").compactMap { Int($0) })
    }
}

enum PackPreset: Int, CaseIterable, Identifiable {
    case classic, custom
    var id: Int { rawValue }
    var name: String { ["클래식", "사진으로 만들기"][rawValue] }
    var hue: Angle { .zero }
}

enum VapePreset: Int, CaseIterable, Identifiable {
    case graphite, blue, coral, lime
    var id: Int { rawValue }
    var name: String { ["그래파이트", "블루", "코랄", "라임"][rawValue] }
    var tint: Color { [.white, .blue, .orange, .green][rawValue] }
}

struct SmokePuff: Identifiable, Equatable { let id = UUID(); let delay: Double; let drift: CGFloat }

struct CustomPack: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let photoData: Data
    init(id: UUID = UUID(), name: String = "나의 곽", photoData: Data) {
        self.id = id; self.name = name; self.photoData = photoData
    }

    private enum CodingKeys: String, CodingKey { case id, name, photoData }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "나의 곽"
        photoData = try values.decode(Data.self, forKey: .photoData)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
    func clamped(to range: Range<Int>) -> Int { Swift.min(Swift.max(self, range.lowerBound), range.upperBound - 1) }
}
