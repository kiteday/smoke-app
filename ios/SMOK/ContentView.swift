import SwiftUI
import PhotosUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session = SmokeSession()
    @State private var catalog: SmokeKind?
    @State private var isShowingSettings = false
    @State private var isShowingProfile = false
    @State private var isUnlocked = true
    @State private var checkedInitialLock = false

    var body: some View {
        ZStack {
            AppBackground(theme: session.backgroundTheme)
            VStack(spacing: 0) {
                HeaderView(showSettings: { isShowingSettings = true }, showProfile: { isShowingProfile = true })
                    .padding(.horizontal, 22).frame(height: 62)
                Group {
                    if let kind = catalog {
                        CatalogView(session: session, kind: kind, back: { catalog = nil }) {
                            if kind == .cigarette { session.hasChosenPack = true }
                            if kind == .vape { session.hasChosenVape = true }
                            session.select(kind)
                            catalog = nil
                        }
                    } else if session.selected == nil {
                        HomeView(session: session) { kind in
                            if (kind == .cigarette && session.hasChosenPack) ||
                                (kind == .vape && session.hasChosenVape) {
                                session.select(kind)
                            } else {
                                catalog = kind
                            }
                        }
                    } else {
                        SessionView(session: session) {
                            session.close()
                            isShowingProfile = true
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                AdMobBannerView().frame(height: 50).background(Color.white)
            }
            if !isUnlocked {
                LockView { await unlock() }
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: session.selected)
        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: catalog)
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(session: session).presentationDetents([.large])
                .presentationDragIndicator(.visible).presentationBackground(Color.black)
        }
        .sheet(isPresented: $isShowingProfile) {
            MyPageView(session: session) { kind in
                isShowingProfile = false
                catalog = kind
            }.presentationDetents([.large])
                .presentationDragIndicator(.visible).presentationBackground(Color.black)
        }
        .task {
            guard !checkedInitialLock else { return }
            checkedInitialLock = true
            if session.faceIDLockEnabled {
                isUnlocked = false
                await unlock()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, session.faceIDLockEnabled {
                isUnlocked = false
            } else if phase == .active, session.faceIDLockEnabled, !isUnlocked {
                Task { await unlock() }
            }
        }
    }

    private func unlock() async {
        guard session.faceIDLockEnabled else { isUnlocked = true; return }
        if await AppLock.authenticate(reason: "담타고고 잠금을 해제합니다.") {
            withAnimation { isUnlocked = true }
        }
    }
}

private struct HeaderView: View {
    let showSettings: () -> Void
    let showProfile: () -> Void
    var body: some View {
        HStack {
            RoundIcon("gearshape", label: "환경 설정", action: showSettings)
            Spacer()
            Text("담타고고").font(.system(size: 18, weight: .black, design: .rounded)).tracking(1)
            Spacer()
            RoundIcon("person.crop.circle", label: "내 페이지", action: showProfile)
        }
    }
}

private struct RoundIcon: View {
    let icon: String, label: String
    let action: () -> Void
    init(_ icon: String, label: String, action: @escaping () -> Void) {
        self.icon = icon; self.label = label; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 40, height: 40)
                .background(.white.opacity(0.045), in: Circle()).overlay(Circle().stroke(.white.opacity(0.13)))
        }.accessibilityLabel(label)
    }
}

private struct HomeView: View {
    let session: SmokeSession
    let browse: (SmokeKind) -> Void
    var body: some View {
        HStack(spacing: 12) {
            HomeChoice(session: session, kind: .cigarette, status: "\(session.cigaretteCount)개비", hue: safePack(session.selectedPackIndex).hue) { browse(.cigarette) }
            HomeChoice(session: session, kind: .vape, status: "\(session.podLevel)%", hue: .zero) { browse(.vape) }
        }.padding(.horizontal, 20).frame(maxHeight: .infinity)
    }
}

private struct HomeChoice: View {
    let session: SmokeSession
    let kind: SmokeKind, status: String
    let hue: Angle
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Spacer()
                if kind == .cigarette {
                    PackImageView(session: session, presetIndex: session.selectedPackIndex, height: 330)
                        .frame(maxWidth: .infinity).clipped()
                } else {
                    Image(kind.imageName).resizable().scaledToFit().colorMultiply(safeVape(session.selectedVapeIndex).tint)
                        .frame(maxWidth: .infinity, maxHeight: 330).clipped()
                }
                HStack(spacing: 6) {
                    Circle().fill(status == "0개비" ? .red : .green).frame(width: 6, height: 6)
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
        }.buttonStyle(.plain).overlay(Rectangle().stroke(.white.opacity(0.1)))
    }
}

private struct PackImageView: View {
    let session: SmokeSession
    let presetIndex: Int
    let height: CGFloat
    var body: some View {
        GeometryReader { proxy in
            let renderedHeight = min(proxy.size.height, proxy.size.width * 1.5)
            let renderedWidth = renderedHeight * 2 / 3
            ZStack {
                Image("CigarettePack").resizable().scaledToFit()
                    .hueRotation(safePack(presetIndex).hue)
                if presetIndex == PackPreset.custom.rawValue,
                   let data = session.customPackPhotoData,
                   let photo = UIImage(data: data) {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: renderedWidth * 0.56, height: renderedHeight * 0.43)
                        .clipShape(PackFrontPanelShape())
                        .overlay(PackFrontPanelShape().stroke(.orange.opacity(0.8), lineWidth: 1.5))
                        .offset(x: renderedWidth * 0.09, y: renderedHeight * 0.205)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(height: height)
    }
}

private struct CatalogView: View {
    @Bindable var session: SmokeSession
    let kind: SmokeKind
    let back: () -> Void
    let start: () -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isOrganizing = false
    @State private var namingPackID: UUID?
    @State private var newPackName = ""
    @State private var showNamePrompt = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: back) { Image(systemName: "arrow.left").frame(width: 44, height: 44) }
                Spacer()
                Text(kind == .cigarette ? "담뱃갑 고르기" : "기기 고르기").font(.headline)
                Spacer()
                if kind == .cigarette && !session.customPacks.isEmpty {
                    Button(isOrganizing ? "완료" : "정리") { withAnimation { isOrganizing.toggle() } }
                        .font(.subheadline.weight(.semibold)).frame(width: 44, height: 44)
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }.padding(.horizontal, 14)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if kind == .cigarette {
                        PackCatalogCard(title: "클래식", photoData: nil,
                            selected: session.selectedPackIndex == PackPreset.classic.rawValue,
                            isOrganizing: false, select: {
                                session.selectedPackIndex = PackPreset.classic.rawValue
                                session.selectedCustomPackID = nil
                            }, delete: {})
                        ForEach(session.customPacks) { pack in
                            PackCatalogCard(title: pack.name, photoData: pack.photoData,
                                selected: session.selectedPackIndex == PackPreset.custom.rawValue && session.selectedCustomPackID == pack.id,
                                isOrganizing: isOrganizing,
                                select: { session.selectCustomPack(pack.id) },
                                rename: {
                                    namingPackID = pack.id
                                    newPackName = pack.name
                                    showNamePrompt = true
                                },
                                delete: { session.deleteCustomPack(pack.id) })
                        }
                        PhotosPicker(selection: $selectedPhoto, matching: .images) { AddPackCard() }.buttonStyle(.plain)
                    } else {
                        ForEach(VapePreset.allCases) { preset in
                            CatalogCard(title: preset.name, image: "Vape", hue: .zero, tint: preset.tint,
                                customPhoto: nil,
                                showsAdd: false,
                                favorite: session.isFavorite(kind: kind, index: preset.rawValue),
                                selected: session.selectedVapeIndex == preset.rawValue,
                                favoriteAction: { session.toggleFavorite(kind: kind, index: preset.rawValue) },
                                selectAction: { session.selectedVapeIndex = preset.rawValue })
                        }
                    }
                }.padding(20)

            }
            let unavailable = kind == .cigarette ? session.cigaretteCount == 0 : session.podLevel == 0
            Button(action: start) {
                Text(unavailable ? (kind == .cigarette ? "새 갑이 필요해요" : "충전이 필요해요") : "이걸로 시작")
                    .fontWeight(.bold).frame(maxWidth: .infinity).frame(height: 52)
                    .background(unavailable ? Color.gray.opacity(0.45) : Color.orange, in: RoundedRectangle(cornerRadius: 4))
            }.buttonStyle(.plain).disabled(unavailable).padding(.horizontal, 20).padding(.bottom, 14)
        }
        .task(id: selectedPhoto) {
            guard let photoItem = selectedPhoto,
                  let data = try? await photoItem.loadTransferable(type: Data.self) else { return }
            if let id = session.addCustomPackPhoto(data) {
                namingPackID = id
                newPackName = session.selectedCustomPack?.name ?? "나의 곽"
                showNamePrompt = true
            }
            selectedPhoto = nil
        }
        .alert("담뱃갑 이름", isPresented: $showNamePrompt) {
            TextField("이름 입력", text: $newPackName)
            Button("저장") {
                if let namingPackID { session.renameCustomPack(namingPackID, name: newPackName) }
            }
            Button("나중에", role: .cancel) {}
        } message: {
            Text("선택 화면에 표시할 이름을 정해 주세요.")
        }
    }
}

private struct PackCatalogCard: View {
    let title: String
    let photoData: Data?
    let selected: Bool
    let isOrganizing: Bool
    let select: () -> Void
    var rename: (() -> Void)? = nil
    let delete: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: select) {
                VStack(spacing: 6) {
                    ZStack {
                        Image("CigarettePack").resizable().scaledToFit()
                        if let photoData, let photo = UIImage(data: photoData) {
                            Image(uiImage: photo).resizable().scaledToFill()
                                .frame(width: 62, height: 71)
                                .clipShape(PackFrontPanelShape()).offset(x: 10, y: 34)
                                .overlay(PackFrontPanelShape().stroke(.orange.opacity(0.8), lineWidth: 1).frame(width: 62, height: 71).offset(x: 10, y: 34))
                        }
                    }.frame(height: 165).padding(.top, 10)
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        .underline(rename != nil)
                        .onTapGesture { rename?() }
                        .accessibilityHint(rename == nil ? "" : "두 번 탭하여 이름 수정")
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? .orange : .secondary)
                }.frame(maxWidth: .infinity).padding(.bottom, 12).background(.white.opacity(selected ? 0.09 : 0.035))
            }.buttonStyle(.plain)
            if isOrganizing && photoData != nil {
                Button(action: delete) {
                    Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(.red)
                        .padding(10).background(.black.opacity(0.55), in: Circle())
                }.accessibilityLabel("사용자 담뱃갑 삭제")
            }
        }.overlay(Rectangle().stroke(selected ? Color.orange : .white.opacity(0.1), lineWidth: selected ? 2 : 1))
    }
}

private struct PackFrontPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.12))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.82))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct AddPackCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "plus").font(.system(size: 38, weight: .light)).foregroundStyle(.orange)
            Text("사진 추가").font(.subheadline.weight(.semibold))
            Spacer()
        }.frame(maxWidth: .infinity).frame(height: 211)
            .background(.white.opacity(0.025))
            .overlay(Rectangle().stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [7])))
    }
}

private struct CatalogCard: View {
    let title: String, image: String
    let hue: Angle, tint: Color
    let customPhoto: Data?
    let showsAdd: Bool
    let favorite: Bool, selected: Bool
    let favoriteAction: () -> Void, selectAction: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: selectAction) {
                VStack(spacing: 6) {
                    ZStack {
                        if showsAdd {
                            RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [7]))
                                .frame(width: 108, height: 138)
                            Image(systemName: "plus").font(.system(size: 38, weight: .light)).foregroundStyle(.orange)
                        } else {
                            Image(image).resizable().scaledToFit().hueRotation(hue).colorMultiply(tint)
                            if let customPhoto, let photo = UIImage(data: customPhoto) {
                                Image(uiImage: photo).resizable().scaledToFill()
                                    .frame(width: 80, height: 53).clipped().offset(y: 40)
                                    .overlay(Rectangle().stroke(.black.opacity(0.35), lineWidth: 1).frame(width: 80, height: 53).offset(y: 40))
                            }
                        }
                    }.frame(height: 155).padding(.top, 10)
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? .orange : .secondary)
                }.frame(maxWidth: .infinity).padding(.bottom, 12).background(.white.opacity(selected ? 0.09 : 0.035))
            }.buttonStyle(.plain)
            Button(action: favoriteAction) {
                Image(systemName: favorite ? "heart.fill" : "heart").foregroundStyle(favorite ? .red : .secondary).padding(12)
            }
        }.overlay(Rectangle().stroke(selected ? Color.orange : .white.opacity(0.1), lineWidth: selected ? 2 : 1))
    }
}

private struct SettingsView: View {
    @Bindable var session: SmokeSession
    @Environment(\.dismiss) private var dismiss
    @State private var faceIDError = false
    var body: some View {
        NavigationStack {
            Form {
                Section("반응") {
                    Toggle("햅틱 진동", isOn: $session.hapticsEnabled).tint(.orange)
                    Picker("연기 양", selection: $session.smokeLevel) {
                        Text("적음").tag(0); Text("보통").tag(1); Text("많음").tag(2)
                    }
                    Picker("소진 속도", selection: $session.burnEffect) {
                        Text("기본").tag(0); Text("빠르게").tag(1); Text("잔잔하게").tag(2)
                    }
                }
                Section("보안") {
                    Toggle("Face ID 앱 잠금", isOn: Binding(
                        get: { session.faceIDLockEnabled },
                        set: { enabled in
                            if !enabled {
                                session.faceIDLockEnabled = false
                            } else {
                                Task {
                                    let authenticated = await AppLock.authenticate(reason: "Face ID 앱 잠금을 켭니다.")
                                    if authenticated { session.faceIDLockEnabled = true }
                                    else { faceIDError = true }
                                }
                            }
                        }
                    )).tint(.orange)
                }
                Section("색상") {
                    Picker("불꽃", selection: $session.flameColorIndex) {
                        Text("주황").tag(0); Text("파랑").tag(1); Text("분홍").tag(2)
                    }
                    Picker("필터", selection: $session.filterColorIndex) {
                        Text("브라운").tag(0); Text("화이트").tag(1); Text("블랙").tag(2)
                    }
                    Picker("배경", selection: $session.backgroundTheme) {
                        Text("블랙").tag(0); Text("차콜").tag(1); Text("와인").tag(2); Text("네이비").tag(3)
                    }
                }
                Section { Text("소리는 사용하지 않습니다. 햅틱과 화면 모션만 재생됩니다.").font(.caption).foregroundStyle(.secondary) }
            }.scrollContentBackground(.hidden).navigationTitle("환경 설정").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
                .alert("Face ID를 사용할 수 없어요", isPresented: $faceIDError) {
                    Button("확인", role: .cancel) {}
                } message: {
                    Text("기기 설정에서 Face ID와 화면 잠금을 먼저 설정해 주세요.")
                }
        }
    }
}

private struct MyPageView: View {
    @Bindable var session: SmokeSession
    let changeProduct: (SmokeKind) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PackImageView(session: session, presetIndex: session.selectedPackIndex, height: 220)
                    VStack(spacing: 8) {
                        Text("\(session.cigaretteCount) / 20").font(.system(size: 38, weight: .black, design: .rounded))
                        ProgressView(value: Double(session.cigaretteCount), total: 20).tint(.orange)
                        Text(session.cigaretteCount == 0 ? "빈 갑이에요" : "마지막 한 개비까지 사용하면 새 갑으로 바꿀 수 있어요")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 30)

                    Button(action: session.replacePack) {
                        Label("새 갑으로 교체", systemImage: "shippingbox.fill")
                            .fontWeight(.bold).frame(maxWidth: .infinity).frame(height: 52)
                            .background(session.cigaretteCount == 0 ? Color.orange : Color.gray.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain).disabled(session.cigaretteCount != 0).padding(.horizontal, 24)

                    Button { changeProduct(.cigarette) } label: {
                        Label("담뱃갑 디자인 바꾸기", systemImage: "square.3.layers.3d")
                            .frame(maxWidth: .infinity).frame(height: 46)
                    }.buttonStyle(.bordered).tint(.orange).padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        StatCard(value: "\(session.totalCigarettesSmoked)", title: "사용한 개비")
                        StatCard(value: "\(session.completedPacks)", title: "교체한 갑")
                    }.padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        HStack { Text("전자담배 잔량"); Spacer(); Text("\(session.podLevel)%").foregroundStyle(.secondary) }
                        Button("전자담배 충전", action: session.refillPod).buttonStyle(.bordered).tint(.orange)
                        Button { changeProduct(.vape) } label: {
                            Label("전자담배 기기 바꾸기", systemImage: "square.3.layers.3d")
                        }.buttonStyle(.bordered).tint(.orange)
                    }.padding(20).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 24)
                }.padding(.vertical, 24)
            }
            .navigationTitle("내 페이지").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
        }
    }
}

private struct StatCard: View {
    let value: String, title: String
    var body: some View {
        VStack(spacing: 6) {
            Text(value).font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 18).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct LockView: View {
    let unlock: () async -> Void
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "faceid").font(.system(size: 54)).foregroundStyle(.orange)
                Text("담타고고 잠김").font(.title2.bold())
                Button("Face ID로 열기") { Task { await unlock() } }
                    .buttonStyle(.borderedProminent).tint(.orange)
            }
        }
    }
}

private struct SessionView: View {
    let session: SmokeSession
    let showProfile: () -> Void
    @State private var showFinishOptions = false
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack { Button(action: session.close) { Image(systemName: "arrow.left").frame(width: 44, height: 44) }; Spacer(); Color.clear.frame(width: 44, height: 44) }
                VStack(spacing: 2) { Text(session.selectedTitle).font(.subheadline.weight(.semibold)); Text(session.inventoryText).font(.caption2).foregroundStyle(.secondary) }
            }.padding(.horizontal, 14)
            ZStack {
                if let kind = session.selected {
                    Group {
                        if kind == .cigarette {
                            PackImageView(session: session, presetIndex: session.selectedPackIndex, height: 380)
                        } else {
                            Image(kind.imageName).resizable().scaledToFit().colorMultiply(safeVape(session.selectedVapeIndex).tint)
                        }
                    }
                        .frame(width: kind == .cigarette ? 300 : 205, height: 380)
                        .scaleEffect(session.phase == .ready ? 1 : (kind == .cigarette ? 0.72 : 0.92))
                        .offset(y: session.phase == .ready ? 0 : 42).opacity(kind == .cigarette && session.phase != .ready ? 0.24 : 1)
                    if kind == .cigarette && session.phase != .ready { CigaretteView(session: session) }
                    if kind == .vape && session.isBurning {
                        Capsule().fill(flameColor(session.flameColorIndex)).frame(width: 6, height: 23)
                            .shadow(color: flameColor(session.flameColorIndex), radius: 12).offset(y: 38)
                    }
                }
                SmokeCloud(puffs: session.puffs).offset(y: -92)
            }
            .frame(maxHeight: .infinity).contentShape(Rectangle())
            .gesture(holdGesture)
            VStack(spacing: 8) {
                HStack {
                    Text(session.selected == .vape ? "기기 잔량" : "남은 양")
                    Spacer()
                    Text("\(session.remaining)%").foregroundStyle(.white)
                }.font(.caption2).foregroundStyle(.secondary)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.1)).frame(height: 2)
                        Rectangle().fill(.orange).frame(width: proxy.size.width * CGFloat(session.remaining) / 100, height: 2)
                    }
                }.frame(height: 2)
            }.padding(.horizontal, 38).padding(.bottom, 18)
            VStack(spacing: 8) {
                Circle().fill(session.isBurning ? .red : .orange).frame(width: 42, height: 42)
                    .scaleEffect(session.isBurning ? 1.13 : 1).shadow(color: .orange.opacity(0.5), radius: 12)
                Text(session.actionTitle).font(.headline)
            }
            .contentShape(Rectangle()).gesture(holdGesture).onTapGesture(perform: session.finishButtonTapped)
            .padding(.bottom, 18)
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .finished { showFinishOptions = true }
        }
        .alert(finishTitle, isPresented: $showFinishOptions) {
            if session.selected == .vape {
                Button("충전하기", action: showProfile)
            } else if session.cigaretteCount == 0 {
                Button("새 갑 교체", action: showProfile)
            } else {
                Button("새 담배 꺼내기", action: session.startNext)
            }
            Button("나가기", role: .cancel, action: session.close)
        }
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in session.beginPress() }
            .onEnded { _ in session.endPress() }
    }

    private var finishTitle: String {
        if session.selected == .vape { return "배터리가 모두 닳았어요" }
        return session.cigaretteCount == 0 ? "빈 갑이에요" : "한 개비 끝"
    }
}

private struct CigaretteView: View {
    let session: SmokeSession
    var body: some View {
        VStack(spacing: 0) {
            if session.showIgnitionFlame {
                Image(systemName: "flame.fill").font(.system(size: 34))
                    .foregroundStyle(flameColor(session.flameColorIndex))
                    .shadow(color: flameColor(session.flameColorIndex), radius: 14)
                    .padding(.bottom, -2)
            }
            if session.isBurning {
                Rectangle().fill(Color(white: 0.35)).frame(width: 28, height: 8)
                Rectangle().fill(flameColor(session.flameColorIndex)).frame(width: 30, height: 7)
                    .shadow(color: flameColor(session.flameColorIndex), radius: 12)
            } else if session.phase == .finished {
                Rectangle().fill(Color(white: 0.28)).frame(width: 28, height: 10)
            }
            RoundedRectangle(cornerRadius: 1).fill(Color(white: 0.94))
                .frame(width: 30, height: max(10, 176 * CGFloat(session.remaining) / 100))
            RoundedRectangle(cornerRadius: 2).fill(filterColor(session.filterColorIndex)).frame(width: 30, height: 62)
                .overlay(Rectangle().fill(.orange.opacity(0.55)).frame(height: 2), alignment: .top)
        }
        .frame(width: 34, height: 270, alignment: .bottom)
        .rotationEffect(.degrees(4)).offset(y: 55)
        .shadow(color: .black, radius: 12, y: 16).animation(.easeOut(duration: 0.4), value: session.remaining)
    }
}

private struct SmokeCloud: View {
    let puffs: [SmokePuff]
    var body: some View { ZStack { ForEach(puffs) { SmokeParticle(puff: $0) } }.allowsHitTesting(false) }
}
private struct SmokeParticle: View {
    let puff: SmokePuff
    @State private var active = false
    var body: some View {
        Circle().stroke(.white.opacity(0.44), lineWidth: 2).frame(width: 30, height: 30).blur(radius: active ? 4 : 0)
            .scaleEffect(active ? 4.5 : 0.2).opacity(active ? 0 : 0.65).offset(x: active ? puff.drift : 0, y: active ? -230 : 40)
            .onAppear { withAnimation(.easeOut(duration: 2.8).delay(puff.delay)) { active = true } }
    }
}

private struct AppBackground: View {
    let theme: Int
    var color: Color { [.black, Color(white: 0.055), Color(red: 0.12, green: 0.015, blue: 0.025), Color(red: 0.015, green: 0.025, blue: 0.10)][min(max(theme, 0), 3)] }
    var body: some View { color.ignoresSafeArea() }
}
private func flameColor(_ index: Int) -> Color { [.orange, .cyan, .pink][min(max(index, 0), 2)] }
private func filterColor(_ index: Int) -> Color { [Color.brown, .white, Color(white: 0.12)][min(max(index, 0), 2)] }
private func safePack(_ index: Int) -> PackPreset { PackPreset.allCases[min(max(index, 0), PackPreset.allCases.count - 1)] }
private func safeVape(_ index: Int) -> VapePreset { VapePreset.allCases[min(max(index, 0), VapePreset.allCases.count - 1)] }

#Preview { ContentView() }
