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

    static func texture(named name: String) -> SKTexture? {
        if let standalone = standaloneTexture(named: name) {
            return standalone
        }

        guard let atlasName = atlasByTexturePrefix.first(where: {
            name.hasPrefix($0.prefix)
        })?.atlas else { return nil }

        let atlas = SKTextureAtlas(named: atlasName)
        guard let storedName = atlas.textureNames.first(where: {
            ($0 as NSString).deletingPathExtension == name
        }) else { return nil }

        let texture = atlas.textureNamed(storedName)
        texture.filteringMode = .nearest
        return texture
    }

    /// Loads a standalone PNG only when the file is actually present in the app bundle.
    /// `SKTexture(imageNamed:)` returns SpriteKit's red-X placeholder for a missing name,
    /// so its non-zero size cannot be used to validate newly added runtime resources.
    static func standaloneTexture(named name: String) -> SKTexture? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    static func preloadOfficeAssets() {
        let textureNames = [
            "hud_portrait_frame_v01",
            "ui_close_box_macos9_v01",
            "map_icon_noir_v03",
            "map_icon_noir_v03_hover",
            "map_icon_noir_v03_pressed",
            "journal_icon_noir_v02",
            "journal_icon_noir_v02_hover",
            "journal_icon_noir_v02_pressed",
            "map_detective_office_v02",
            "dialogue_outer_frame_overlay_v02",
            "dialogue_scroll_up_v01",
            "dialogue_scroll_down_v01",
            "dialogue_scroll_track_v01",
            "dialogue_scroll_thumb_v01",
            "dialogue_portrait_lila_march_v01",
            "dialogue_portrait_harlan_voss_v01",
            "inventory_outer_frame_overlay_v01",
            "inventory_slot_frame_v01",
            "inventory_case_bag_v01",
            "inventory_coin_stack_v01",
            "inventory_item_service_revolver_v01",
            "inventory_item_case_notebook_v01",
            "inventory_item_brass_key_v01",
            "inventory_item_matchbook_v01",
            "inventory_item_flashlight_v01",
            "inventory_item_wallet_v01",
            "inventory_item_cigarette_case_v01",
            "journal_casebook_plate_v01",
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
            "office_shadow_vignette",
            "office_floor_wear_decal",
            "office_light_lamp_pool",
            "office_light_window_spill",
            "office_desk_floor_shadow",
            "office_cabinet_floor_shadow",
            "office_bookshelf",
            "office_archive_stack",
            "office_window",
            "office_window_hover",
            "city_district_block_v01",
            "city_district_ground_v01",
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
            "office_radiator",
            "office_door_leaf",
            "office_door_leaf_hover",
            "office_desk_chair",
            "office_filing_cabinet",
            "office_archive_box_a",
            "office_archive_box_b",
            "office_coat_rack",
            "office_visitor_armchair",
            "office_wastebasket",
            "office_worn_rug",
            "office_floor_trash_a",
            "office_floor_trash_b",
            "office_floor_trash_c",
            "office_hidden_bottle",
            "office_framed_photo",
            "office_pencil_tray",
            "office_desk_bare",
            "office_desk_bare_hover",
            "office_desk_lamp",
            "office_desk_phone",
            "office_desk_phone_hover",
            "office_desk_mug",
            "office_desk_ashtray",
            "office_desk_files",
            "office_desk_files_hover",
            "office_desk_papers",
            "office_desk_actor_occluder",
            "office_desk_actor_occluder_hover",
            "office_desk_front_occluder_v04",
            "office_desk_front_occluder_v04_hover"
        ]
        let textures = textureNames.compactMap(texture(named:))
        SKTexture.preload(textures) {}

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
