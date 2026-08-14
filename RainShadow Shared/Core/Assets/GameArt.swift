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
        guard let image = standaloneCGImage(named: name) else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    static func standaloneCGImage(named name: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func preloadOfficeAssets() {
        let textureNames = [
            "hud_left_rail_plate_v03",
            "hud_right_rail_plate_v03",
            "hud_portrait_frame_v03",
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
            "ui_selection_ring_party",
            "ui_selection_ring_npc",
            "det_contact_shadow_soft",
            "map_chrome_top_bar_v03",
            "map_icon_noir_v03",
            "map_icon_noir_v03_hover",
            "map_icon_noir_v03_pressed",
            "journal_icon_noir_v02",
            "journal_icon_noir_v02_hover",
            "journal_icon_noir_v02_pressed",
            "map_detective_office_v03",
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
            "inventory_section_bag_v05",
            "inventory_section_nearby_v05",
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
            "office_internal_door_leaf",
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
            "office_window",
            "office_window_hover",
            "office_window_blinds",
            "city_district_block_v01",
            "city_district_ground_v01",
            "city_district_block_v02",
            "city_district_ground_v02",
            "city_sable_row_block_v02",
            "city_sable_row_ground_v02",
            "city_wharf_ladder_ground_v02",
            "city_riverside_ground_v02",
            "city_harborpoint_pd_ground_v02",
            "city_lila_street_ground_v02",
            "city_civic_records_ground_v02",
            "map_city_sable_row_v02",
            "map_city_wharf_ladder_v02",
            "map_city_riverside_v02",
            "map_city_harborpoint_pd_v02",
            "map_city_lila_street_v02",
            "map_city_civic_records_v02",
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
            "office_radiator",
            "office_door_leaf",
            "office_door_leaf_fallen",
            "office_door_leaf_hover",
            "office_door_leaf_thickness",
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
            "office_desk_bare_hover",
            "office_desk_lamp",
            "office_desk_typewriter",
            "office_desk_notebook",
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
            "office_desk_front_occluder_v04_hover",
            "office_desk_top_occluder",
            "office_desk_top_occluder_hover"
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
