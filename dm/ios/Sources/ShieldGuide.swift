import SwiftUI
import UIKit

@MainActor
func showShieldGuide() {
    let controller = DmHostingController(rootView: ShieldGuide())
    controller.modalPresentationStyle = .formSheet
    dm_host_present(nil, Unmanaged.passUnretained(controller).toOpaque())
}

private struct ShieldGuide: View {
    @Environment(\.dismiss) private var dismiss
    @State private var area: DMGuideArea
    @State private var selectedPreview = 0
    @State private var wildSubareaChoices: [DMGuideArea: Int] = [:]
    @State private var missingEncountersOnly = false
    @State private var incompleteOnly = false
    @State private var search = ""
    @State private var context: DMGuidePresentation
    @State private var checkoffs: Set<String> = []
    @State private var saved: DMGuideSavedContext?
    @State private var live: DMGuideLiveLocation?
    @State private var saveStatus = "Looking for a committed Shield save…"
    @State private var stale = false
    @State private var saves = DMGuideSaveMonitor()
    private let guide = DMShieldGuide(defaults: .standard)

    init() {
        _area = State(initialValue: guide.selectedArea)
        _context = State(initialValue: DMGuidePresentation.resolve(source: .current, manualArea: guide.selectedArea,
            saved: nil, stale: false, status: "Looking for a committed Shield save…", live: nil, preview: nil))
    }

    private var preview: DMGuideSnapshot? {
        selectedPreview >= 3 ? DMShieldGuide.previews[selectedPreview - 3] : nil
    }

    private var displayedArea: DMGuideArea { context.area }
    private var locatedWildSubarea: Int? { context.wildSubarea?.intValue }

    var body: some View {
        let progress = context.progress
        let activityRows = context.rows(guide: guide, query: search, incompleteOnly: incompleteOnly)
        // Reading checkoffs keeps local marks reactive alongside the shared row policy.
        let _ = checkoffs
        NavigationStack {
            List {
                Section {
                    NavigationLink("Offline handbook and reference") { ShieldReferenceBrowser() }
                        .accessibilityIdentifier("guide.handbook")
                }
                Section("Guide context") {
                    Picker("Source", selection: $selectedPreview) {
                        Text("Current game").tag(0)
                        Text("Browse manually").tag(1)
                        Text("Last game save").tag(2)
                        ForEach(DMShieldGuide.previews.indices, id: \.self) { index in
                            Text(DMShieldGuide.previews[index].title).tag(index + 3)
                        }
                    }
                    .accessibilityIdentifier("guide.source")
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(context.summary, id: \.self) { Text($0) }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if context.canChooseArea {
                        Picker("Browse area", selection: $area) {
                            ForEach(DMShieldGuide.areaNames.indices, id: \.self) { index in
                                if let choice = DMGuideArea(rawValue: index) {
                                    Text(DMShieldGuide.areaNames[index]).tag(choice)
                                }
                            }
                        }
                    }
                }

                Section("Checklist") {
                    Toggle("Show incomplete only", isOn: $incompleteOnly)
                        .accessibilityIdentifier("guide.incomplete")
                    if activityRows.isEmpty { Text("No matching activities. Clear search or show completed items.") }
                    let nearby = activityRows.filter { !$0.completed && !$0.later }
                    if !nearby.isEmpty { Text("Explore nearby · \(nearby.count)").font(.headline) }
                    activityGroup(nil, rows: search.isEmpty ? Array(nearby.prefix(5)) : nearby)
                    if search.isEmpty && nearby.count > 5 {
                        DisclosureGroup("More nearby activities · \(nearby.count - 5)") {
                            activityGroup(nil, rows: Array(nearby.dropFirst(5)))
                        }
                    }
                    let later = activityRows.filter { $0.later }
                    if !later.isEmpty {
                        DisclosureGroup("Later visits and access to check · \(later.count)") {
                            activityGroup(nil, rows: later)
                        }
                    }
                    let completed = activityRows.filter { $0.completed }
                    if !completed.isEmpty {
                        DisclosureGroup("Completed · \(completed.count)") {
                            activityGroup(nil, rows: completed)
                        }
                    }
                }
                let services = DMGuidePresentation.services(in: displayedArea).filter {
                    search.isEmpty || $0.localizedStandardContains(search)
                }
                if !services.isEmpty {
                    Section("Local services") { ForEach(services, id: \.self) { Text($0) } }
                }

                Section {
                    DisclosureGroup("Route directions") {
                        Text(DMShieldGuide.directions(in: displayedArea))
                    }
                    let encounters = DMShieldGuide.encounterGroups(in: displayedArea)
                    let wild = DMShieldGuide.hasWildEncounters(in: displayedArea)
                    let missing = (wild || !encounters.isEmpty) ? progress?.missingGalarSpecies : nil
                    let matchingSpecies = missingEncountersOnly ? missing : nil
                    if missing != nil {
                        Toggle("Show missing Galar Pokémon only", isOn: $missingEncountersOnly)
                        if missingEncountersOnly {
                            Text("Based on your last save. Forms share a Pokédex entry.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if wild {
                        let wildArea = displayedArea
                        WildSubareaPicker(area: wildArea,
                                          locatedSubarea: locatedWildSubarea,
                                          saved: progress,
                                          matchingSpecies: matchingSpecies,
                                          choice: Binding(get: { wildSubareaChoices[wildArea, default: -1] },
                                                          set: { wildSubareaChoices[wildArea] = $0 }))
                            .id(wildArea)
                        CurryDexPicker(saved: progress)
                        GigantamaxCollection(saved: progress)
                    } else if !encounters.isEmpty {
                        DisclosureGroup("Pokémon to find") {
                            let groups = matchingSpecies.map { DMShieldGuide.encounterGroups(in: displayedArea, matchingSpecies: $0) }
                                ?? encounters
                            if groups.isEmpty { Text("No missing Galar Pokédex entries in this area’s encounter list.") }
                            ForEach(groups, id: \.self) { group in
                                Text(group)
                            }
                        }
                        .id(displayedArea)
                    }
                    if displayedArea == .circhester {
                        GalarDexPicker(saved: progress)
                    }
                    if displayedArea == .wedgehurst {
                        DisclosureGroup(DMGuideSavedContext.postgameStadiumTitle(savedContext: progress)) {
                            ForEach(DMGuideSavedContext.postgameStadiumRows(savedContext: progress), id: \.self) { stadium in
                                Text(stadium)
                            }
                        }
                    }
                    if displayedArea == .motostoke {
                        DisclosureGroup(DMGuideSavedContext.gymChallengeTitle(savedContext: progress)) {
                            ForEach(DMGuideSavedContext.gymChallengeRows(savedContext: progress), id: \.self) { gym in
                                Text(gym)
                            }
                        }
                    }
                    if displayedArea == .motostoke || displayedArea == .battleTower {
                        DisclosureGroup(DMGuideSavedContext.leagueCardAlbumTitle(savedContext: progress)) {
                            ForEach(DMGuideSavedContext.leagueCardAlbumRows(savedContext: progress), id: \.self) { card in
                                Text(card)
                            }
                        }
                        DisclosureGroup("Card Maker styles") {
                            ForEach(DMGuideSavedContext.cardMakerRows(savedContext: progress), id: \.self) { row in
                                Text(row)
                            }
                        }
                    }
                    if DMShieldGuide.hasUniformWardrobe(in: displayedArea) {
                        DisclosureGroup(DMGuideSavedContext.uniformWardrobeTitle(savedContext: progress)) {
                            ForEach(DMGuideSavedContext.uniformWardrobeRows(savedContext: progress), id: \.self) { row in
                                Text(row)
                            }
                        }
                    }
                    BoutiqueProgress(area: displayedArea, saved: progress)
                    if displayedArea != .unknown {
                        TMProgress(area: displayedArea, saved: progress)
                            .id(displayedArea)
                    }
                    if displayedArea == .motostoke || displayedArea == .battleTower {
                        TMProgress(area: .unknown, saved: progress)
                    }
                    if let traders = DMGuideSavedContext.trSources(in: displayedArea) {
                        TRProgress(traders: traders, saved: progress)
                    }
                    if let cafe = DMGuideSavedContext.cafePrizeTitle(in: displayedArea) {
                        DisclosureGroup(cafe) {
                            ForEach(DMGuideSavedContext.cafePrizeRows(in: displayedArea, savedContext: progress), id: \.self) { row in
                                Text(row)
                            }
                        }
                        .id(displayedArea)
                    }
                    if DMShieldGuide.hasAlcremieCollection(in: displayedArea) {
                        AlcremieCollection(saved: progress)
                    }
                    if displayedArea == .stow {
                        StowMarketProgress(saved: progress)
                    }
                    if displayedArea == .stow || displayedArea == .glimwood {
                        DisclosureGroup(DMGuideSavedContext.teaEvolutionTitle(savedContext: progress)) {
                            ForEach(DMGuideSavedContext.teaEvolutionRows(savedContext: progress), id: \.self) { row in
                                Text(row)
                            }
                        }
                    }
                    if displayedArea == .wyndon {
                        DisclosureGroup(DMGuideSavedContext.rotomFormsTitle(savedContext: progress)) {
                            ForEach(DMGuideSavedContext.rotomFormRows(savedContext: progress), id: \.self) { row in
                                Text(row)
                            }
                        }
                    }
                    if displayedArea == .battleTower {
                        DisclosureGroup(DMGuideSavedContext.silvallyMemoryTitle(savedContext: progress)) {
                            ForEach(DMGuideSavedContext.silvallyMemoryRows(savedContext: progress), id: \.self) { row in
                                Text(row)
                            }
                        }
                        BattleTowerProgress(saved: progress)
                    }
                }

            }
            .navigationTitle("Pokémon Shield Guide")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Local activities and services")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                refreshCheckoffs()
                refreshSave()
            }
            .onChange(of: area) {
                guide.selectedArea = area
                refreshPresentation()
                refreshCheckoffs()
            }
            .onChange(of: displayedArea) { refreshCheckoffs() }
            .onChange(of: selectedPreview) {
                refreshPresentation()
                refreshSave()
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in refreshSave() }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                refreshCheckoffs()
            }
        }
    }

    @ViewBuilder
    private func activityGroup(_ title: String?, rows: [DMGuideActivityRow]) -> some View {
        if let title, !rows.isEmpty { Text("\(title) · \(rows.count)").font(.headline) }
        ForEach(rows, id: \.activity.key) { row in
            let activity = row.activity
            DisclosureGroup {
                Text(row.status)
                Text(row.access)
                Text(activity.directions)
                ForEach(row.relatedAreas, id: \.self) { related in
                    if let destination = DMGuideArea(rawValue: related.intValue), destination != displayedArea {
                        Button("Browse \(DMShieldGuide.areaNames[destination.rawValue])") {
                            area = destination
                            guide.selectedArea = destination
                            selectedPreview = 1
                            search = ""
                            refreshPresentation()
                        }
                    }
                }
                if !context.readOnly && context.progress?.activityCompletion(forKey: activity.key) == nil {
                    Toggle(isOn: Binding(get: { checkoffs.contains(activity.key) }, set: {
                        guide.setChecked($0, for: activity)
                        refreshCheckoffs()
                    })) {
                        Text(activity.isDaily ? "Check off for today" : "Check off")
                    }
                    .accessibilityLabel("\(activity.title) — \(activity.isDaily ? "Check off for today" : "Check off")")
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Label(activity.title, systemImage: row.completed ? "checkmark.circle.fill" : (activity.isDaily ? "calendar" : "circle"))
                    Text(row.hint).font(.subheadline).foregroundStyle(.secondary)
                    if row.status != "Player confirmation available" {
                        Text(row.status).font(.caption).foregroundStyle(.secondary)
                    }
                    if row.later { Text(row.access).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .accessibilityIdentifier("guide.activity.\(activity.key)")
        }
    }

    private func refreshPresentation() {
        context = DMGuidePresentation.resolve(source: selectedPreview >= 3 ? .archive : DMGuideSource(rawValue: selectedPreview)!,
            manualArea: area, saved: saved, stale: stale, status: saveStatus, live: live, preview: preview)
    }

    private func refreshCheckoffs() {
        checkoffs = Set(DMShieldGuide.activities(in: displayedArea).filter { guide.isChecked($0) }.map(\.key))
    }

    private func refreshSave() {
        guard selectedPreview < 3 else { return }
        let location = selectedPreview == 0 ? DMGuideLiveLocation.current() : nil
        if location?.area != live?.area || location?.name != live?.name ||
            location?.placementBased != live?.placementBased || location?.wildSubarea != live?.wildSubarea {
            live = location
            refreshPresentation()
        }
        // Keep the presentation identity stable on unchanged timer polls. Replacing
        // it rebuilds List while a native Picker menu is tracking a selection.
        saves.refresh {
            saved = saves.context
            stale = saves.stale
            saveStatus = saves.status
            refreshPresentation()
        }
    }
}

private struct StowMarketProgress: View {
    let saved: DMGuideSavedContext?

    var body: some View {
        DisclosureGroup("Street Market") {
            ForEach(DMGuideSavedContext.stowMarketRows(savedContext: saved), id: \.self) { Text($0) }
            DisclosureGroup("Bargain stock") {
                ForEach(DMGuideSavedContext.stowBargainStock(), id: \.self) { Text($0) }
            }
            DisclosureGroup("Buyer prices") {
                ForEach(DMGuideSavedContext.stowBuyerPrices(), id: \.self) { Text($0) }
            }
        }
    }
}

private struct AlcremieCollection: View {
    let saved: DMGuideSavedContext?

    var body: some View {
        DisclosureGroup(DMGuideSavedContext.alcremieTitle(savedContext: saved)) {
            Text(DMShieldGuide.alcremieDirections())
            let titles = DMGuideSavedContext.alcremieSweetTitles(savedContext: saved)
            ForEach(titles.indices, id: \.self) { sweet in
                DisclosureGroup(titles[sweet]) {
                    ForEach(DMGuideSavedContext.alcremieRows(forSweet: sweet, savedContext: saved), id: \.self) { row in
                        Text(row)
                    }
                }
            }
        }
    }
}

private struct GigantamaxCollection: View {
    let saved: DMGuideSavedContext?
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(DMGuideSavedContext.gigantamaxTitle(savedContext: saved), isExpanded: $expanded) {
            if expanded {
                ForEach(DMGuideSavedContext.gigantamaxRows(savedContext: saved), id: \.self) { row in
                    Text(row)
                }
            }
        }
    }
}

private struct BoutiqueProgress: View {
    let area: DMGuideArea
    let saved: DMGuideSavedContext?

    var body: some View {
        if let title = DMGuideSavedContext.boutiqueTitle(in: area, savedContext: saved) {
            DisclosureGroup(title) {
                let categories = DMGuideSavedContext.boutiqueCategories(in: area, savedContext: saved)
                if categories.isEmpty {
                    Text("Load a Shield save to see the stock for your avatar.")
                }
                ForEach(categories, id: \.identifier) { category in
                    DisclosureGroup(category.title) {
                        ForEach(category.items, id: \.self) { item in
                            Text(item)
                        }
                    }
                }
            }
        }
    }
}

private struct TMProgress: View {
    let area: DMGuideArea
    let saved: DMGuideSavedContext?
    @State private var expanded = false

    var body: some View {
        if let title = DMGuideSavedContext.tmTitle(in: area, savedContext: saved) {
            DisclosureGroup(title, isExpanded: $expanded) {
                if expanded {
                    ForEach(DMGuideSavedContext.tmRows(in: area, savedContext: saved), id: \.self) { row in
                        Text(row)
                    }
                }
            }
        }
    }
}

private struct TRProgress: View {
    let traders: String
    let saved: DMGuideSavedContext?
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(DMGuideSavedContext.trTitle(savedContext: saved), isExpanded: $expanded) {
            if expanded {
                Text(traders)
                ForEach(DMGuideSavedContext.trRows(savedContext: saved), id: \.self) { row in
                    Text(row)
                }
            }
        }
    }
}

private struct BattleTowerProgress: View {
    let saved: DMGuideSavedContext?

    var body: some View {
        records("Singles records", doubles: false)
        records("Doubles records", doubles: true)
    }

    private func records(_ title: String, doubles: Bool) -> some View {
        DisclosureGroup(title) {
            let rows = saved?.battleTowerProgress(doubles: doubles) ?? []
            if rows.isEmpty {
                Text(doubles ? "Doubles records unavailable." : "Singles records unavailable.")
            }
            ForEach(rows, id: \.self) { Text($0) }
            DisclosureGroup("Rank rewards") {
                ForEach(DMGuideSavedContext.battleTowerRankRewards(doubles: doubles, savedContext: saved), id: \.self) {
                    Text($0)
                }
            }
            DisclosureGroup("Win rewards") {
                ForEach(DMGuideSavedContext.battleTowerWinRewards(doubles: doubles, repeating: false, savedContext: saved), id: \.self) {
                    Text($0)
                }
            }
            DisclosureGroup("Repeat rewards after 200 wins") {
                ForEach(DMGuideSavedContext.battleTowerWinRewards(doubles: doubles, repeating: true, savedContext: saved), id: \.self) {
                    Text($0)
                }
            }
        }
    }
}

private struct GalarDexPicker: View {
    let saved: DMGuideSavedContext?
    @State private var range = 0
    @State private var missingOnly = true

    var body: some View {
        let caught = saved?.galarDexCaughtCount
        let title = caught.map { "Galar Pokédex · \($0) of 400 caught" } ?? "Galar Pokédex"
        DisclosureGroup(title) {
            let ranges = DMGuideSavedContext.galarDexRanges(savedContext: saved)
            Picker("Pokédex range", selection: $range) {
                ForEach(ranges.indices, id: \.self) { Text(ranges[$0]).tag($0) }
            }
            if caught != nil {
                Toggle("Show missing only", isOn: $missingOnly)
            } else {
                Text("Galar Pokédex progress unavailable").foregroundStyle(.secondary)
            }
            let entries = DMGuideSavedContext.galarDexRows(inRange: range, missingOnly: missingOnly, savedContext: saved)
            if entries.isEmpty { Text("All entries in this range are caught.") }
            ForEach(entries, id: \.number) { entry in
                NavigationLink(entry.label) { DexEncounterLocations(species: entry.species) }
            }
        }
    }
}

private struct DexEncounterLocations: View {
    let species: String

    var body: some View {
        let locations = DMShieldGuide.encounterLocations(forSpecies: species)
        List {
            if !locations.routes.isEmpty {
                Section("Routes and towns") {
                    ForEach(locations.routes, id: \.self) { Text($0) }
                }
            }
            if !locations.wildArea.isEmpty {
                Section("Wild Area encounters") {
                    ForEach(locations.wildArea, id: \.self) { Text($0) }
                }
            }
            if !locations.raids.isEmpty {
                Section("Max Raid dens") {
                    ForEach(locations.raids, id: \.self) { Text($0) }
                }
            }
            if !locations.other.isEmpty {
                Section("Gifts, trades, and other sources") {
                    ForEach(locations.other, id: \.self) { Text($0) }
                }
            }
            if locations.routes.isEmpty && locations.wildArea.isEmpty && locations.raids.isEmpty && locations.other.isEmpty {
                Text("No location is listed for this species in the guide.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle(species)
    }
}

private struct CurryDexPicker: View {
    let saved: DMGuideSavedContext?
    @State private var group = 0

    var body: some View {
        let cooked = saved?.cookedCurryCount
        let title = cooked.map { "Curry Dex · \($0) of 151 cooked" } ?? "Curry Dex"
        DisclosureGroup(title) {
            let groups = DMGuideSavedContext.curryRecipeGroups
            Picker("Recipe group", selection: $group) {
                ForEach(groups.indices, id: \.self) { Text(groups[$0]).tag($0) }
            }
            if cooked == nil {
                Text("Curry Dex progress unavailable").foregroundStyle(.secondary)
            }
            if let ingredient = DMGuideSavedContext.curryIngredient(inGroup: group) {
                Text(ingredient).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(DMGuideSavedContext.curryRecipes(inGroup: group, savedContext: saved), id: \.self) {
                Text($0)
            }
            DisclosureGroup("Camping King rewards") {
                Text("Ask the Camping King by the steps to Motostoke to rate your Curry Dex.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(DMGuideSavedContext.campingRewards(savedContext: saved), id: \.self) { Text($0) }
            }
        }
    }
}

private struct WildSubareaPicker: View {
    let area: DMGuideArea
    let locatedSubarea: Int?
    let saved: DMGuideSavedContext?
    let matchingSpecies: Set<String>?
    @Binding var choice: Int
    @State private var weather = 0

    var body: some View {
        let subareas = DMShieldGuide.wildSubareas(in: area)
        let subarea = choice >= 0 ? choice : (locatedSubarea ?? 0)
        DisclosureGroup("Wild Area subareas · \(subareas[subarea])") {
            Picker("Subarea", selection: $choice) {
                Text("Follow location").tag(-1)
                ForEach(subareas.indices, id: \.self) { Text(subareas[$0]).tag($0) }
            }
            let weathers = DMShieldGuide.wildWeatherNames
            Picker("Weather", selection: $weather) {
                ForEach(weathers.indices, id: \.self) { Text(weathers[$0]).tag($0) }
            }
            Text(DMShieldGuide.wildDirections(in: area, subarea: subarea))
            WildSparklePicker(area: area, subarea: subarea, saved: saved)
            WildRaidPicker(area: area, subarea: subarea, matchingSpecies: matchingSpecies)
            Text(DMShieldGuide.wildWeatherHelp)
                .font(.caption).foregroundStyle(.secondary)
            let sections = DMShieldGuide.wildEncounters(in: area, subarea: subarea, weather: weather,
                                                        matchingSpecies: matchingSpecies)
            ForEach(sections, id: \.self) { Text($0) }
            if sections.isEmpty {
                Text(matchingSpecies == nil ? "No listed encounters for this selection." :
                    "No missing Galar Pokédex entries for this selection.")
            }
        }
    }
}

private struct WildSparklePicker: View {
    let area: DMGuideArea
    let subarea: Int
    let saved: DMGuideSavedContext?
    @State private var selection = 0

    var body: some View {
        DisclosureGroup("Recurring sparkles") {
            let rows = DMGuideSavedContext.wildSparkles(in: area, subarea: subarea, savedContext: saved)
            if let summary = rows.first { Text(summary) }
            if let map = DMGuideSavedContext.wildSparkleMap(in: area, subarea: subarea, savedContext: saved) {
                let selected = map.spots.indices.contains(selection) ? selection : 0
                Picker("Sparkle spot", selection: $selection) {
                    ForEach(map.spots.indices, id: \.self) { Text(map.spots[$0].title).tag($0) }
                }
                let spot = map.spots[selected]
                Text("\(spot.saveStatus) · \(spot.denReference)")
                Text("Relative positions · North ↑ · Hollow dots await respawn · D labels mark raid dens")
                    .font(.caption).foregroundStyle(.secondary)
                Canvas { context, size in
                    context.withCGContext { map.draw(in: $0, size: size, selectedIndex: selected) }
                }
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            }
            ForEach(rows.dropFirst(), id: \.self) { Text($0) }
            Text("Mixed reward pools can also yield a Wishing Piece.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: subarea) { selection = 0 }
    }
}

private struct WildRaidPicker: View {
    let area: DMGuideArea
    let subarea: Int
    let matchingSpecies: Set<String>?
    @State private var denIndex = 0
    @State private var rare = false
    @State private var stars = 1

    var body: some View {
        DisclosureGroup("Max Raid dens") {
            let dens = DMShieldGuide.raidDens(in: area, subarea: subarea)
            Picker("Den", selection: $denIndex) {
                ForEach(dens.indices, id: \.self) { Text("Den \(dens[$0])").tag($0) }
            }
            Picker("Beam", selection: $rare) {
                Text("Red beam").tag(false)
                Text("Purple beam").tag(true)
            }
            Picker("Star rank", selection: $stars) {
                ForEach(1...5, id: \.self) { Text($0 == 1 ? "1 star" : "\($0) stars").tag($0) }
            }
            if let map = DMShieldGuide.raidMap(in: area, subarea: subarea) {
                Text("Den locations · Schematic map · North ↑")
                    .font(.caption).foregroundStyle(.secondary)
                WildRaidMap(map: map, selection: $denIndex)
            }
            Text("Standard Shield raid pools. Your Gym Badges determine which star ranks can appear.")
                .font(.caption).foregroundStyle(.secondary)
            if matchingSpecies != nil {
                Text("Odds are for the full den pool.").font(.caption).foregroundStyle(.secondary)
            }
            if let den = dens.indices.contains(denIndex) ? dens[denIndex] : dens.first {
                let encounters = DMShieldGuide.raidEncounters(
                    in: area, subarea: subarea, den: den.intValue, rare: rare, stars: stars, matchingSpecies: matchingSpecies)
                if encounters.isEmpty {
                    Text(matchingSpecies == nil ? "No listed encounters for this selection." :
                        "No missing Galar Pokédex entries for this selection.")
                } else {
                    Text(encounters.joined(separator: "\n"))
                }
            }
        }
        .onChange(of: subarea) { denIndex = 0 }
    }
}

private struct WildRaidMap: View {
    let map: DMGuideRaidMap
    @Binding var selection: Int

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let pins = map.markersLaidOut(in: size)
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    context.withCGContext { map.draw(in: $0, size: size) }
                }
                .accessibilityHidden(true)
                ForEach(pins.indices, id: \.self) { index in
                    let marker = pins[index]
                    let selected = index == selection
                    Button {
                        selection = index
                    } label: {
                        Text(marker.den.formatted(.number.grouping(.never)))
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(selected ? .black : .white)
                            .frame(minWidth: 24, minHeight: 22)
                            .background(selected ? Color(red: 1, green: 0.82, blue: 0.38) :
                                Color(red: 0.10, green: 0.16, blue: 0.16), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white, lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .position(x: marker.position.x, y: marker.position.y)
                    .accessibilityLabel("Den \(marker.den)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .zIndex(selected ? 1 : 0)
                }
            }
            .clipShape(.rect(cornerRadius: 8))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Wild Area den map, north up")
        }
        .aspectRatio(map.aspectRatio, contentMode: .fit)
    }
}

// Separate search and paging keep the static handbook independent of save state
// and the local activity filter, including when the monitor refreshes its save.
private struct ShieldReferenceBrowser: View {
    @State private var category = ""
    @State private var query = ""
    @State private var page = 0
    private let pageSize = 25

    var body: some View {
        let entries = DMShieldReference.entries(category: category, query: query)
        let pages = max(1, (entries.count + pageSize - 1) / pageSize)
        let current = min(page, pages - 1)
        List {
            Section {
                Text("Browse base-game facts without a save. These entries do not track completion. Sword-only sources and communication requirements are labeled in the text.")
                    .font(.subheadline).foregroundStyle(.secondary)
                NavigationLink {
                    ShieldReferenceCategories(selection: $category)
                } label: {
                    VStack(alignment: .leading) {
                        Text("Reference category")
                        Text(category.isEmpty ? "All categories" : category).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("reference.category")
            }
            if pages > 1 {
                Section {
                    Button("Previous page") { page = max(0, current - 1) }
                        .disabled(current == 0).accessibilityIdentifier("reference.previous")
                    Button("Next page") { page = min(pages - 1, current + 1) }
                        .disabled(current == pages - 1).accessibilityIdentifier("reference.next")
                }
            }
            Section("\(entries.count) results · Page \(current + 1) of \(pages)") {
                if entries.isEmpty { Text("No matching reference entries. Clear search or choose All categories.") }
                ForEach(Array(entries.dropFirst(current * pageSize).prefix(pageSize)), id: \.key) { entry in
                    NavigationLink {
                        List {
                            Section {
                                Text(entry.title).font(.title2).bold()
                                Text(entry.category).foregroundStyle(.secondary)
                                Text(entry.body).textSelection(.enabled)
                            }
                            Section("Source") { Text(entry.citation).font(.footnote).textSelection(.enabled) }
                        }
                        .navigationTitle(entry.title)
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(entry.title)
                            Text(entry.category).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("reference.entry.\(entry.key)")
                }
            }
        }
        .navigationTitle("Offline handbook")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search all reference facts")
        .onChange(of: query) { _, _ in page = 0 }
        .onChange(of: category) { _, _ in page = 0 }
    }
}

private struct ShieldReferenceCategories: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    @State private var query = ""

    var body: some View {
        List {
            Button("All categories") { selection = ""; dismiss() }
            ForEach(DMShieldReference.categories.filter {
                query.isEmpty || $0.localizedStandardContains(query)
            }, id: \.self) { category in
                Button {
                    selection = category
                    dismiss()
                } label: {
                    HStack {
                        Text(category)
                        if selection == category { Image(systemName: "checkmark") }
                    }
                }
            }
        }
        .navigationTitle("Reference category")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Find a category")
    }
}
