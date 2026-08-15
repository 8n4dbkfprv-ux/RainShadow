//
//  GameViewController.swift
//  RainShadow macOS
//
//  Created by Laurens van Oorschot on 7/17/26.
//

import Cocoa
import SpriteKit

class GameViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let skView = self.view as! SKView
        GameBootstrap.start(in: skView)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.acceptsMouseMovedEvents = true
        view.window?.makeFirstResponder(view)
        applyReviewCaptureSizeIfRequested()
        syncSceneToViewBounds()
        scheduleReviewCaptureIfRequested()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // macOS can finish window layout after didMove(to:); re-sync so the left
        // action rail is framed against the real point bounds, not the 800×600 IB size.
        syncSceneToViewBounds()
    }

    private func syncSceneToViewBounds() {
        guard let skView = view as? SKView, let scene = skView.scene as? BaseGameScene else { return }
        scene.syncSizeFromViewIfNeeded()
        scene.layoutViewport()
    }

    /// Optional viewport matrix for renderer QA, e.g.
    /// `RAINSHADOW_CAPTURE_SIZE=1280x720`. This only applies when a capture path
    /// is armed and lets one shipping macOS renderer exercise phone, tablet, and
    /// desktop point layouts without changing the storyboard window.
    private func applyReviewCaptureSizeIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["RAINSHADOW_CAPTURE"] != nil,
              let specification = environment["RAINSHADOW_CAPTURE_SIZE"] else { return }
        let components = specification.lowercased().split(separator: "x", maxSplits: 1)
        guard components.count == 2,
              let width = Double(components[0]),
              let height = Double(components[1]),
              width >= 320,
              height >= 240 else {
            FileHandle.standardError.write(
                Data("capture: invalid RAINSHADOW_CAPTURE_SIZE=\(specification)\n".utf8)
            )
            return
        }
        view.window?.setContentSize(NSSize(width: width, height: height))
        view.window?.contentView?.layoutSubtreeIfNeeded()
    }

    /// QA hook: `RAINSHADOW_CAPTURE=<path>` writes one PNG of the live scene and
    /// quits, so review frames come from the shipping renderer rather than a
    /// re-implementation of it.
    ///
    /// `RAINSHADOW_CAPTURE_MODE`
    ///   `camera` (default) exactly what the play camera frames
    ///   `room`             the whole room plate
    ///   `shell`            shell plate only
    ///   `suite_plate`      suite background plate only (Stage 1 architecture review)
    ///   `architecture`     suite/shell + doors (no furniture); legacy partition if enabled
    ///   `architecture_debug` architecture plus collision / axis / doorway overlays
    ///
    /// `RAINSHADOW_CAPTURE_SIZE=<width>x<height>` resizes the window in points
    /// before layout and capture (for example `1280x720`).
    ///
    /// `RAINSHADOW_CAPTURE_ZOOM=<percent>` frames the capture at a BG:EE zoom
    /// percent (25…155) instead of the default 100. Clamped to the scene's own
    /// ceiling, so asking for 155 in the office reports back the 140 it allows —
    /// which is how a capture proves the plate still covers the viewport.
    ///
    /// `RAINSHADOW_PARTITION_MASK=0` loads the full-height partition (mask off).
    /// `RAINSHADOW_LEGACY_PARTITION=1` restores partition/foreground overlays with suite plate.
    /// `RAINSHADOW_FORCE_CLIENT_ENTRANCE=1` with `RAINSHADOW_SKIP_INTRO=1` starts
    /// Lila's walk-in immediately for mid-doorway captures.
    private func scheduleReviewCaptureIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["RAINSHADOW_CAPTURE"] else { return }
        FileHandle.standardError.write(Data("capture: armed for \(path)\n".utf8))
        let delay = Double(environment["RAINSHADOW_CAPTURE_DELAY"] ?? "") ?? 2.0
        let mode = environment["RAINSHADOW_CAPTURE_MODE"] ?? "camera"

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            // This launch draws one frame and never runs the update loop, so any
            // cutscene is still on its first beat. Advance it to `delay` before
            // rendering or every cinematic reviews as frame zero.
            if let game = (self?.view as? SKView)?.scene as? BaseGameScene {
                game.seekForCapture(elapsed: delay)
                if let requested = environment["RAINSHADOW_CAPTURE_ZOOM"].flatMap(Double.init) {
                    game.setZoomStep(CameraZoom.step(forPercent: CGFloat(requested)))
                    let applied = CameraZoom.percent(forStep: game.zoomStep)
                    let report = "capture: zoom \(applied)% (step \(game.zoomStep) of \(game.zoomBounds))\n"
                    FileHandle.standardError.write(Data(report.utf8))
                }
            }
            if let office = (self?.view as? SKView)?.scene as? DetectiveOfficeScene {
                office.seekForcedClientEntranceForCapture()
            }
            if environment["RAINSHADOW_CAPTURE_DUMP"] != nil {
                self?.dumpSceneGraph()
            }
            self?.writeCapture(to: path, mode: mode)
            NSApp.terminate(nil)
        }
    }

    /// Reports every placed node back in authored plate pixels so the offline
    /// layout plan can be diffed against what the scene actually built.
    private func dumpSceneGraph() {
        guard let scene = (view as? SKView)?.scene as? BaseGameScene else { return }
        let roots: [(String, SKNode)] = [
            ("background", scene.backgroundRoot),
            ("floor", scene.floorEffectRoot),
            ("rear", scene.rearFixtureRoot),
            ("depth", scene.depthWorldRoot),
            ("occlusion", scene.occlusionRoot)
        ]
        var lines = ["RAINSHADOW_DUMP_BEGIN"]
        for (label, root) in roots {
            for node in root.children {
                let authored = OfficeInteriorScale.unmapPoint(node.position)
                let size = (node as? SKSpriteNode)?.size ?? node.calculateAccumulatedFrame().size
                lines.append(
                    String(
                        format: "%@ %@ authored=(%.0f, %.0f) world=(%.0f, %.0f) size=(%.0f, %.0f) z=%.0f",
                        label, node.name ?? "unnamed",
                        authored.x, authored.y,
                        node.position.x, node.position.y,
                        size.width, size.height,
                        node.zPosition
                    )
                )
            }
        }
        lines.append("RAINSHADOW_DUMP_END")
        FileHandle.standardError.write(Data(lines.joined(separator: "\n").appending("\n").utf8))
    }

    private static let architectureNodeNames: Set<String> = [
        "office_suite_plate",
        "office_shell_base",
        "office_partition_wall",
        "office_internal_door_leaf",
        "office_foreground_cutaway",
        "office_door_leaf",
        "office_door_leaf_thickness",
        "office_door_fall_contact_shadow",
        "qa_scale_reference_stand"
    ]

    private func writeCapture(to path: String, mode: String) {
        guard let skView = view as? SKView, let scene = skView.scene else { return }
        let game = scene as? BaseGameScene

        if mode != "camera" {
            // Room-wide frames render the plate itself, so the screen-locked HUD
            // would otherwise sit across the middle of the room.
            game?.hudRoot.isHidden = true
        }
        if mode == "shell" || mode == "suite_plate" {
            for root in [game?.floorEffectRoot, game?.rearFixtureRoot, game?.depthWorldRoot, game?.occlusionRoot, game?.weatherRoot] {
                for node in root?.children ?? [] {
                    node.isHidden = true
                }
            }
            if mode == "suite_plate" {
                for node in game?.backgroundRoot.children ?? []
                where node.name != "office_suite_plate" && node.name != "office_shell_base" {
                    node.isHidden = true
                }
            }
        } else if mode == "architecture" || mode == "architecture_debug" {
            for root in [game?.floorEffectRoot, game?.rearFixtureRoot, game?.depthWorldRoot, game?.weatherRoot, game?.occlusionRoot] {
                for node in root?.children ?? [] where !Self.architectureNodeNames.contains(node.name ?? "") {
                    node.isHidden = true
                }
            }
            // Stage 1 suite-plate review: hide door leaves so the capture is
            // architecture paint only (leaves return in Stage 3).
            if ProcessInfo.processInfo.environment["RAINSHADOW_SUITE_PLATE_ARCH"] == "1" {
                for root in [game?.depthWorldRoot, game?.occlusionRoot] {
                    for node in root?.children ?? []
                    where node.name == "office_internal_door_leaf" || node.name == "office_door_leaf" {
                        node.isHidden = true
                    }
                }
            }
        }

        let crop: CGRect
        if mode == "camera", let camera = scene.camera {
            let visible = CGSize(
                width: scene.size.width * camera.xScale,
                height: scene.size.height * camera.yScale
            )
            crop = CGRect(
                x: camera.position.x - visible.width / 2,
                y: camera.position.y - visible.height / 2,
                width: visible.width,
                height: visible.height
            )
        } else if let plate = game?.backgroundRoot.calculateAccumulatedFrame(), !plate.isEmpty {
            crop = plate
        } else {
            crop = scene.calculateAccumulatedFrame()
        }

        guard let texture = skView.texture(from: scene, crop: crop) else {
            FileHandle.standardError.write(Data("capture: no texture for crop \(crop)\n".utf8))
            return
        }
        let cgImage = texture.cgImage()
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("capture: png encode failed\n".utf8))
            return
        }
        // The app sandbox refuses paths outside its container, so the PNG goes out
        // over stdout in base64 and the caller writes the file.
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            FileHandle.standardOutput.write(Data("RAINSHADOW_CAPTURE_BEGIN\n".utf8))
            FileHandle.standardOutput.write(Data(png.base64EncodedString().utf8))
            FileHandle.standardOutput.write(Data("\nRAINSHADOW_CAPTURE_END\n".utf8))
        }
        FileHandle.standardError.write(
            Data(
                """
                capture: rendered \(cgImage.width)x\(cgImage.height) \
                crop=(\(crop.origin.x), \(crop.origin.y), \(crop.width), \(crop.height))

                """.utf8
            )
        )
    }
}
