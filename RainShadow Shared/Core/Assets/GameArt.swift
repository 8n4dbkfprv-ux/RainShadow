import SpriteKit
import ImageIO

@MainActor
enum GameArt {
    private static let atlasByTexturePrefix: [(prefix: String, atlas: String)] = [
        ("lila_arrival_", "LilaArrival"),
        ("lila_departure_", "LilaArrival"),
        ("voss_standing_idle_", "VossIdle"),
        ("voss_seated_arms_", "VossSeatedArms"),
        ("voss_seated_idle_", "VossSeatedIdle"),
        ("voss_seated_upper_", "VossSeatedIdle"),
        ("voss_seated_lower_", "VossSeatedIdle"),
        ("voss_stand_up_", "VossSeatTransitions"),
        ("voss_sit_down_", "VossSeatTransitions"),
        ("voss_walk_", "VossWalk")
    ]

    static func texture(named name: String, preferredExtension: String? = nil) -> SKTexture? {
        if let standalone = standaloneTexture(
            named: name,
            preferredExtension: preferredExtension
        ) {
            return standalone
        }

        guard let atlasName = atlasByTexturePrefix.first(where: {
            name.hasPrefix($0.prefix)
        })?.atlas else { return nil }

        let atlas = SKTextureAtlas(named: atlasName)
        guard let storedName = atlas.textureNames.first(where: {
            ($0 as NSString).deletingPathExtension == name
        }) else { return nil }

        // Character atlases are V15 plate-density rasters (2.84 art-px per
        // world unit, ~parity with the area plates). Linear filtering smooths
        // the magnified sprite exactly the way the BG:EE engine smooths its
        // zoom; nearest would re-introduce blockiness the plates do not have.
        let texture = atlas.textureNamed(storedName)
        texture.filteringMode = .linear
        return texture
    }

    /// Loads a standalone PNG only when the file is actually present in the app bundle.
    /// `SKTexture(imageNamed:)` returns SpriteKit's red-X placeholder for a missing name,
    /// so its non-zero size cannot be used to validate newly added runtime resources.
    static func standaloneTexture(
        named name: String,
        preferredExtension: String? = nil
    ) -> SKTexture? {
        guard let image = standaloneCGImage(
            named: name,
            preferredExtension: preferredExtension
        ) else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        recordSourceNameIfDumping(texture, name: name)
        return texture
    }

    /// Which file a live texture came from.
    ///
    /// `SKTexture` built from a `CGImage` reports `<data>` and carries no
    /// filename, and a node's name is not a reliable stand-in: the office rug
    /// node is `office_worn_rug` but draws `office_worn_rug_burgundy`. A bake
    /// that resolved art by node name composited the wrong picture and produced
    /// a plate that looked almost right, which is the worst kind of wrong.
    ///
    /// Only populated under `RAINSHADOW_DUMP_PROPS`, so shipping play pays
    /// nothing for it.
    private static let dumpingTextureSources =
        ProcessInfo.processInfo.environment["RAINSHADOW_DUMP_PROPS"] == "1"
    private static let sourceNameLock = NSLock()
    nonisolated(unsafe) private static var sourceNames: [ObjectIdentifier: String] = [:]

    private static func recordSourceNameIfDumping(_ texture: SKTexture, name: String) {
        guard dumpingTextureSources else { return }
        sourceNameLock.lock()
        defer { sourceNameLock.unlock() }
        sourceNames[ObjectIdentifier(texture)] = name
    }

    static func sourceName(of texture: SKTexture) -> String? {
        guard dumpingTextureSources else { return nil }
        sourceNameLock.lock()
        defer { sourceNameLock.unlock() }
        return sourceNames[ObjectIdentifier(texture)]
    }

    /// Decoded images, keyed by the name and extension they were asked for.
    ///
    /// Every `texture(named:)` used to reopen the file and decode the PNG again,
    /// so `office_suite_plate` — 4096×2304, about 38 MB decoded — was re-decoded
    /// on each area entry, and the four HUD overlays re-decoded their multi-MB
    /// plates on every scene change. It also made `preloadOfficeAssets` dead
    /// work: the textures it warmed were released the moment it returned, and
    /// the office asked for fresh ones.
    ///
    /// The `CGImage` is cached rather than the `SKTexture` deliberately. 66 call
    /// sites assign `filteringMode` on the texture they get back, 53 of them
    /// `.linear`, so handing every caller the same `SKTexture` instance would
    /// let whichever ran last decide filtering for all of them. Caching one step
    /// earlier removes the decode — the dominant cost — while each caller still
    /// gets its own texture to configure.
    ///
    /// `NSCache` so this yields to memory pressure instead of pinning every
    /// plate the session has ever shown.
    /// `nonisolated(unsafe)` is accurate rather than a waiver: `NSCache` does its
    /// own locking, and this is read and written from the background preload as
    /// well as the main actor.
    nonisolated(unsafe) private static let imageCache: NSCache<NSString, CGImageBox> = {
        let cache = NSCache<NSString, CGImageBox>()
        // Decoded bytes, not files: one 8192×6144 ward page is about 200 MB.
        cache.totalCostLimit = 384 * 1024 * 1024
        return cache
    }()

    /// `NSCache` holds objects; `CGImage` is a CoreFoundation type.
    private final class CGImageBox: @unchecked Sendable {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    /// Drops the decoded-image cache. Nothing calls this in normal play; it
    /// exists so a memory warning or a test can reclaim the plates.
    nonisolated static func flushImageCache() {
        imageCache.removeAllObjects()
    }

    nonisolated static func standaloneCGImage(
        named name: String,
        preferredExtension: String? = nil
    ) -> CGImage? {
        let key = "\(name)|\(preferredExtension ?? "")" as NSString
        if let cached = imageCache.object(forKey: key) { return cached.image }
        guard let image = decodeStandaloneCGImage(named: name, preferredExtension: preferredExtension) else {
            return nil
        }
        let cost = image.height * image.bytesPerRow
        imageCache.setObject(CGImageBox(image), forKey: key, cost: cost)
        return image
    }

    /// Decodes and caches without building an `SKTexture`, so the bulk of a
    /// preload can run off the main actor. `NSCache`, `Bundle.url` and
    /// `CGImageSource` are all thread-safe; `SKTexture` creation is left on the
    /// main actor where it already was.
    nonisolated static func warmImage(named name: String) {
        _ = standaloneCGImage(named: name)
    }

    nonisolated private static func decodeStandaloneCGImage(
        named name: String,
        preferredExtension: String? = nil
    ) -> CGImage? {
        var extensions = [preferredExtension, "png", "jpg", "jpeg"].compactMap { $0 }
        var seen = Set<String>()
        extensions = extensions.filter { seen.insert($0.lowercased()).inserted }
        guard let url = extensions.lazy.compactMap({ fileExtension in
            Bundle.main.url(forResource: name, withExtension: fileExtension)
        }).first,
        let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        // Full decode first. Literal 80×60-tile city areas are paged into
        // 2048×1536 textures; legacy/office plates still use this same path.
        let fullOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: false
        ]
        if let image = CGImageSourceCreateImageAtIndex(source, 0, fullOptions as CFDictionary) {
            return image
        }
        // Last resort: keep the area visible (soft) rather than nil → black fog.
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary)
    }

    /// Warms what the first playable area is about to need, while the player is
    /// still watching the intro.
    ///
    /// This used to be a synchronous block in `OpeningExteriorScene.buildScene`
    /// that bought nothing. `GameArt` had no cache, so the ~300 `SKTexture`s it
    /// built lived only in a local array and were released the moment
    /// `SKTexture.preload` returned; the office then asked for the same art and
    /// decoded all of it again. Everything genuinely expensive about entering an
    /// area — the area catalog, the avatar bundles, the compositor — was first
    /// touched *after* the intro, so skipping did not cancel a preload. There
    /// was not one.
    ///
    /// Now the image decodes land in a cache the office actually reads, and they
    /// run off the main actor so the intro keeps its frame rate. The main-actor
    /// half yields between slices for the same reason.
    ///
    /// The name list still contains art no scene places any more —
    /// `office_suite.area.json` has an empty `props` array because the props are
    /// baked into `office_suite_plate`. It is left intact on purpose: several of
    /// these names are built by interpolation at the call site
    /// (`ui_move_marker_00` and friends), so a grep cannot tell live from dead
    /// and a trim needs a runtime audit. Warming a few extra images off-thread
    /// is cheap; guessing wrong and dropping live art is not.
    static func preloadOfficeAssets() {
        let textureNames = [
            "hud_left_rail_plate_v03",
            "hud_right_rail_plate_v03",
            "hud_portrait_frame_v03",
            "hud_loot_container_panel_v02",
            "hud_loot_take_all_v03",
            "hud_action_menu_v03",
            "hud_action_map_v03",
            "hud_action_journal_v03",
            "hud_action_inventory_v03",
            "hud_action_character_v03",
            "hud_action_leads_v03",
            "hud_action_contacts_v03",
            "hud_action_settings_v03",
            "hud_action_rest_v03",
            "hud_action_help_v03",
            "hud_action_hide_ui_v03",
            "hud_action_clock_v03",
            "hud_party_search_v03",
            "hud_party_lantern_v03",
            "hud_party_select_v03",
            "ui_close_box_macos9_noir_v04",
            "inventory_close_box_macos9_noir_v09",
            "inventory_close_box_macos9_noir_v10",
            "inventory_close_box_macos9_noir_v11",
            "inventory_close_box_macos9_noir_v15",
            "inventory_close_box_macos9_noir_v14",
            "inventory_close_box_macos9_noir_v13",
            "inventory_close_box_macos9_noir_v12",
            "ui_close_box_noir_v03",
            "ui_move_marker_00",
            "ui_move_marker_01",
            "ui_move_marker_02",
            "ui_move_marker_03",
            "ui_move_marker_04",
            "ui_move_marker_05",
            "ui_move_marker_06",
            "ui_move_marker_07",
            "ui_move_marker_blocked",
            "ui_move_marker_blocked_00",
            "ui_move_marker_blocked_01",
            "ui_move_marker_blocked_02",
            "ui_move_marker_blocked_03",
            "ui_move_marker_blocked_04",
            "ui_move_marker_blocked_05",
            "ui_move_marker_blocked_06",
            "ui_move_marker_blocked_07",
            "ui_waypoint_pip",
            "det_contact_shadow_soft",
            "map_chrome_top_bar_v03",
            "map_icon_noir_v03",
            "map_icon_noir_v03_hover",
            "map_icon_noir_v03_pressed",
            "journal_icon_noir_v02",
            "journal_icon_noir_v02_hover",
            "journal_icon_noir_v02_pressed",
            "map_detective_office_v08",
            "dialogue_outer_frame_overlay_v11",
            "dialogue_outer_frame_overlay_v10",
            "dialogue_outer_frame_overlay_v08",
            "dialogue_outer_frame_overlay_v09",
            "dialogue_outer_frame_overlay_v07",
            "dialogue_outer_frame_overlay_v06",
            "dialogue_outer_frame_overlay_v05",
            "dialogue_outer_frame_overlay_v04",
            "dialogue_command_button_plate_v07",
            "dialogue_command_button_plate_v07_hover",
            "dialogue_command_button_plate_v07_pressed",
            "dialogue_command_button_plate_v06",
            "dialogue_command_button_plate_v05",
            "dialogue_command_button_plate_v04",
            "dialogue_command_button_plate_v03",
            "dialogue_scroll_up_v06",
            "dialogue_scroll_down_v06",
            "dialogue_scroll_up_pressed_v06",
            "dialogue_scroll_down_pressed_v06",
            "dialogue_scroll_box_v06",
            "dialogue_scroll_area_v06",
            "dialogue_scroll_area_solid_v06",
            "dialogue_portrait_lila_march_v02",
            "dialogue_portrait_harlan_voss_v01",
            "inventory_outer_frame_v09",
            "inventory_outer_frame_v10",
            "inventory_outer_frame_v11",
            "inventory_outer_frame_v12",
            "inventory_outer_frame_v16",
            "inventory_outer_frame_v15",
            "inventory_outer_frame_v14",
            "inventory_outer_frame_v13",
            "inventory_outer_frame_v08",
            "inventory_outer_frame_v07",
            "inventory_outer_frame_v06",
            "inventory_outer_frame_v05",
            "inventory_section_loadout_v05",
            "inventory_section_paperdoll_v05",
            "inventory_section_stats_v05",
            "inventory_section_mid_v05",
            "inventory_section_bag_v06",
            "inventory_slot_frame_v05",
            "inventory_selection_frame_v05",
            "inventory_slot_silhouette_hat_v05",
            "inventory_slot_silhouette_coat_v05",
            "inventory_slot_silhouette_hands_v05",
            "inventory_slot_silhouette_feet_v05",
            "inventory_slot_silhouette_ring_v05",
            "inventory_slot_silhouette_weapon_v05",
            "inventory_slot_silhouette_item_v05",
            "inventory_slot_silhouette_bag_v05",
            "inventory_slot_silhouette_hat_v06",
            "inventory_slot_silhouette_coat_v06",
            "inventory_slot_silhouette_hands_v06",
            "inventory_slot_silhouette_charm_v06",
            "inventory_slot_silhouette_cloak_v06",
            "inventory_slot_silhouette_belt_v06",
            "inventory_slot_silhouette_feet_v06",
            "inventory_slot_silhouette_ring_v06",
            "inventory_slot_silhouette_holster_v06",
            "inventory_slot_silhouette_weapon_v06",
            "inventory_slot_silhouette_item_v06",
            "inventory_slot_silhouette_bag_v06",
            "inventory_stat_badge_defence_v05",
            "inventory_stat_badge_vitality_v05",
            "inventory_stat_badge_resolve_v05",
            "inventory_stat_badge_damage_v05",
            "inventory_page_arrow_prev_v05",
            "inventory_page_arrow_next_v05",
            "inventory_case_bag_v05",
            "inventory_coin_stack_v05",
            "inventory_item_service_revolver_v01",
            "inventory_item_case_notebook_v01",
            "inventory_item_brass_key_v01",
            "inventory_item_matchbook_v01",
            "inventory_item_flashlight_v01",
            "inventory_item_wallet_v01",
            "inventory_item_cigarette_case_v01",
            "journal_casebook_plate_v03",
            "journal_row_marker_v03",
            "voss_paperdoll_front_rgba_v01",
            "voss_standing_idle_s_00",
            "voss_standing_idle_ssw_00",
            "voss_standing_idle_sw_00",
            "voss_standing_idle_wsw_00",
            "voss_standing_idle_w_00",
            "voss_standing_idle_wnw_00",
            "voss_standing_idle_nw_00",
            "voss_standing_idle_nnw_00",
            "voss_standing_idle_n_00",
            "office_shell_base",
            "office_suite_plate",
            "office_shadow_vignette",
            "office_floor_wear_decal",
            "office_partition_wall",
            "office_partition_wall_cutaway",
            "office_partition_cutaway_mask",
            "office_foreground_cutaway",
            "office_personal_sideboard",
            "office_personal_fan",
            "office_personal_washbasin",
            "office_personal_glass",
            "office_light_lamp_pool",
            "office_light_window_spill",
            "office_light_blind_stripes",
            "office_light_hallway",
            "office_desk_floor_shadow",
            "office_cabinet_floor_shadow",
            "office_bookshelf",
            "office_archive_stack",
            "office_window_glass_mask",
            // City ward plates are 8192×6144 (~200 MB decoded each). Eager
            // preloading every ward here OOMs on iPhone / Designed-for-iPad and
            // leaves GameAreaScene with a nil plate under solid-black fog.
            // Load plates on demand when the district opens; keep HUD map art.
            "city_building_interior_v01",
            "map_city_sable_row_v02",
            "map_city_wharf_ladder_v02",
            "map_city_riverside_v02",
            "map_city_harborpoint_pd_v02",
            "map_city_lila_street_v02",
            "map_city_civic_records_v02",
            "map_city_building_interior_v01",
            "map_world_harborpoint_v02",
            "map_world_harborpoint_v03",
            "map_world_harborpoint_v04",
            "map_district_icon_sable_row_v01",
            "map_district_icon_sable_row_v01_hover",
            "map_district_icon_wharf_ladder_v01",
            "map_district_icon_wharf_ladder_v01_hover",
            "map_district_icon_riverside_v01",
            "map_district_icon_riverside_v01_hover",
            "map_district_icon_harborpoint_pd_v01",
            "map_district_icon_harborpoint_pd_v01_hover",
            "map_district_icon_lila_street_v01",
            "map_district_icon_lila_street_v01_hover",
            "map_district_icon_civic_records_v01",
            "map_district_icon_civic_records_v01_hover",
            "city_building_voss_stoop",
            "city_terrace_sable_sw",
            "city_terrace_sable_se",
            "city_terrace_sable_nw",
            "city_terrace_sable_ne",
            "city_terrace_sable_south_w",
            "city_terrace_sable_south_e",
            "city_terrace_sable_far_a",
            "city_terrace_sable_far_b",
            "city_district_sable_south_row",
            "city_district_sable_north_skyline",
            "city_district_sable_corner_shops",
            "city_building_tenement",
            "city_building_storefront",
            "city_building_rowhouse",
            "city_building_shop",
            "city_building_gatehouse",
            "city_building_shipping_office",
            "city_building_warehouse",
            "city_building_boarding",
            "city_building_dock_shed",
            "city_building_iron_stairs",
            "city_building_river_watch",
            "city_building_rail_lamp",
            "city_building_abutment",
            "city_building_pd_station",
            "city_building_pd_annex",
            "city_building_pd_alley",
            "city_building_pd_plaza_wall",
            "city_building_lila_rooms",
            "city_building_lila_neighbor",
            "city_building_lila_opposite",
            "city_building_lila_alcove",
            "city_building_records_annex",
            "city_building_records_wing",
            "city_building_records_colonnade",
            "city_building_records_plaza",
            "city_building_row_corner",
            "city_prop_lamp",
            "city_prop_bench",
            "city_prop_car_black",
            "city_prop_car_olive",
            "city_prop_car_maroon",
            "city_prop_kiosk",
            "city_prop_crates_mail",
            "city_prop_gate",
            "city_prop_statue",
            "city_building_nw",
            "city_building_central",
            "city_building_ne",
            "city_building_sw",
            "city_building_mid",
            "city_building_se",
            "city_lamp",
            "city_statue",
            "city_bench",
            "city_car_black",
            "city_car_olive",
            "city_car_maroon",
            "city_kiosk",
            "city_crates_mail",
            "city_gate",
            "office_desk_chair",
            "office_filing_cabinet",
            "office_filing_cabinet_open",
            "office_safe",
            "office_archive_box_a",
            "office_archive_box_b",
            "office_coat_rack",
            "office_umbrella_stand",
            "office_visitor_armchair",
            "office_waiting_chair_a",
            "office_waiting_chair_b",
            "office_waiting_table",
            "office_newspaper",
            "office_waiting_ashtray",
            "office_wastebasket",
            "office_worn_rug",
            "office_worn_rug_burgundy",
            "office_entrance_runner",
            "office_case_board",
            "office_wall_city_map",
            "office_framed_licence",
            "office_wall_photos",
            "office_shadow_ceiling_fan",
            "office_floor_trash_a",
            "office_floor_trash_b",
            "office_floor_trash_c",
            "office_hidden_bottle",
            "office_framed_photo",
            "office_pencil_tray",
            "office_desk_bare",
            "office_desk_lamp",
            "office_desk_typewriter",
            "office_desk_notebook",
            "office_desk_phone",
            "office_desk_mug",
            "office_desk_ashtray",
            "office_desk_files",
            "office_desk_papers",
            "office_desk_actor_occluder",
            "office_desk_front_occluder_v04",
            "office_desk_top_occluder"
        ]
        // Decode off the main actor. These land in `imageCache`, which is what
        // `texture(named:)` reads, so the office reuses this work instead of
        // repeating it.
        Task.detached(priority: .utility) {
            AreaLoadTrace.measure("preload.images", "\(textureNames.count) names") {
                for name in textureNames { warmImage(named: name) }
            }
        }

        // The rest has to be on the main actor, so it is sliced: a yield between
        // batches keeps the intro's rain at frame rate instead of trading one
        // long stall at the transition for one long stall at the start.
        Task { @MainActor in
            await warmAreaEntryState()
        }
    }

    /// The main-actor half of the preload: the things whose first touch used to
    /// land squarely on the transition frame.
    private static func warmAreaEntryState() async {
        // Parsing the shipped catalog reads every area's JSON at once. The
        // opening exterior never asks for an area, so this was always paid at
        // the transition.
        AreaLoadTrace.measure("preload.areaCatalog") {
            _ = HarborpointAreas.catalog
        }
        await Task.yield()

        // `IEAvatarFrameLibrary.shared` caches per character for the process, so
        // materialising the frames here means `DetectiveActorNode.init` and
        // `ClientActorNode.init` find them already built. That init is the
        // single largest CPU block on an area change.
        for character in ["Voss", "Lila"] {
            guard let library = try? IEAvatarFrameLibrary.shared(character: character) else { continue }
            AreaLoadTrace.measure("preload.avatarFrames", character) {
                _ = library
            }
            var sinceYield = 0
            for frame in library.sprite.frames where !frame.isEmpty {
                _ = library.frame(atlas: frame.id.atlas, name: frame.id.name)
                sinceYield += 1
                // Small enough that no single frame of the intro loses its
                // budget to this, large enough not to be all scheduler overhead.
                if sinceYield >= 8 {
                    sinceYield = 0
                    await Task.yield()
                }
            }
        }

        let atlases = [
            "LilaArrival",
            "VossIdle",
            "VossSeatedArms",
            "VossSeatedIdle",
            "VossSeatTransitions",
            "VossWalk"
        ]
            .map(SKTextureAtlas.init(named:))
        SKTextureAtlas.preloadTextureAtlases(atlases) {}
    }

    static func rainStreakTexture() -> SKTexture {
        let width = 4
        let height = 48
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return SKTexture()
        }

        let colors = [
            CGColor(red: 0.72, green: 0.80, blue: 0.92, alpha: 0.0),
            CGColor(red: 0.72, green: 0.80, blue: 0.92, alpha: 0.75),
            CGColor(red: 0.72, green: 0.80, blue: 0.92, alpha: 0.0)
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.55, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)
        context.drawLinearGradient(
            gradient!,
            start: CGPoint(x: 2, y: 0),
            end: CGPoint(x: 2, y: 48),
            options: []
        )
        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }
}
