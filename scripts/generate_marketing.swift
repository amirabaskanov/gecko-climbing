// generate_marketing.swift
//
// Wraps each captured screenshot in an iPhone-Pro-Max-style frame with a
// big tagline and soft sage background, then exports a 1320×2868 PNG ready
// for App Store Connect.
//
// Run from the repo root with:
//   swift scripts/generate_marketing.swift
//
// Inputs:  docs/screenshots/marketing-input/01..05-*.jpg
// Outputs: docs/screenshots/marketing/01..05-*.png

import SwiftUI
import AppKit

// MARK: - Layout constants

let canvasWidth: CGFloat = 1320
let canvasHeight: CGFloat = 2868

// Tagline area at the top
let taglineTopPadding: CGFloat = 200
let taglineFontSize: CGFloat = 92
let taglineLineSpacing: CGFloat = 8

// Device frame (centered horizontally, with breathing room at top + bottom)
let deviceWidth: CGFloat = 1080
let deviceHeight: CGFloat = 2200
let deviceTopOffset: CGFloat = 500             // distance from canvas top to phone top
let deviceBezel: CGFloat = 22                  // thickness of black bezel
let deviceCornerRadius: CGFloat = 175
let screenCornerRadius: CGFloat = 155

// Status-bar mask — covers the simulator's 9:41/wifi/battery so only the
// Dynamic Island reads at the top of the screen, AllTrails-style. Sized
// to the scaled status-bar region only — leaves nav titles ("My Sessions",
// "Back") visible in screens with their own headers.
let statusBarMaskHeight: CGFloat = 100
let screenContentBackground = Color(red: 245/255.0, green: 245/255.0, blue: 240/255.0)

// Dynamic Island
let islandWidth: CGFloat = 240
let islandHeight: CGFloat = 64
let islandTopOffset: CGFloat = 18              // distance from top of screen to top of island

// Colors
let backgroundColor = Color(red: 232/255.0, green: 239/255.0, blue: 233/255.0)  // soft sage
let phoneBodyColor = Color(red: 0.10, green: 0.10, blue: 0.10)                  // matte near-black
let taglineColor = Color(red: 0.06, green: 0.16, blue: 0.10)                    // deep forest

// MARK: - Inputs

struct MarketingSpec {
    let inputFilename: String
    let outputFilename: String
    let tagline: String
}

let specs: [MarketingSpec] = [
    MarketingSpec(
        inputFilename: "01-flagship.png",
        outputFilename: "01-train-smarter.png",
        tagline: "Train smarter,\nclimb higher."
    ),
    MarketingSpec(
        inputFilename: "02-sessions.png",
        outputFilename: "02-track-every-climb.png",
        tagline: "Track every climb,\nfrom V0 to project."
    ),
    MarketingSpec(
        inputFilename: "03-stats.png",
        outputFilename: "03-watch-progress.png",
        tagline: "Watch your progress\ntake shape."
    ),
    MarketingSpec(
        inputFilename: "04-week-in-review.png",
        outputFilename: "04-week-recap.png",
        tagline: "Your week in\nclimbing, recapped."
    ),
    MarketingSpec(
        inputFilename: "05-discover.png",
        outputFilename: "05-crew-sending.png",
        tagline: "See what your crew\nis sending."
    )
]

// MARK: - View

struct MarketingFrame: View {
    let screenshot: Image
    let tagline: String

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Text(tagline)
                    .font(.system(size: taglineFontSize, weight: .black, design: .rounded))
                    .foregroundColor(taglineColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(taglineLineSpacing)
                    .padding(.top, taglineTopPadding)
                    .padding(.horizontal, 60)

                Spacer(minLength: 0)
            }

            // Device frame, anchored from canvas top
            VStack(spacing: 0) {
                Spacer().frame(height: deviceTopOffset)
                phoneFrame
                Spacer(minLength: 0)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .background(backgroundColor)
    }

    private var phoneFrame: some View {
        let screenWidth = deviceWidth - 2 * deviceBezel
        let screenHeight = deviceHeight - 2 * deviceBezel

        return ZStack {
            // Outer phone body — matte near-black
            RoundedRectangle(cornerRadius: deviceCornerRadius, style: .continuous)
                .fill(phoneBodyColor)
                .frame(width: deviceWidth, height: deviceHeight)
                .shadow(color: Color.black.opacity(0.18), radius: 30, x: 0, y: 14)

            // Inner screen contents — screenshot + status-bar mask + island,
            // all clipped together to the screen's rounded corners.
            ZStack {
                screenshot
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: screenWidth, height: screenHeight)

                // Mask the simulator's status bar (time/wifi/battery/cellular)
                // so only the Dynamic Island reads at the top.
                VStack(spacing: 0) {
                    screenContentBackground
                        .frame(height: statusBarMaskHeight)
                    Spacer(minLength: 0)
                }
                .frame(width: screenWidth, height: screenHeight)

                // Dynamic Island sits centered in the cleaned status area.
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: islandHeight / 2, style: .continuous)
                        .fill(Color.black)
                        .frame(width: islandWidth, height: islandHeight)
                        .padding(.top, islandTopOffset)
                    Spacer(minLength: 0)
                }
                .frame(width: screenWidth, height: screenHeight)
            }
            .frame(width: screenWidth, height: screenHeight)
            .clipShape(RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous))
        }
    }
}

// MARK: - Renderer

@MainActor
func render(spec: MarketingSpec, inputDir: String, outputDir: String) {
    let inputURL = URL(fileURLWithPath: "\(inputDir)/\(spec.inputFilename)")
    let outputURL = URL(fileURLWithPath: "\(outputDir)/\(spec.outputFilename)")

    guard let nsImage = NSImage(contentsOf: inputURL) else {
        print("✗ Could not load \(spec.inputFilename)")
        return
    }

    let view = MarketingFrame(
        screenshot: Image(nsImage: nsImage),
        tagline: spec.tagline
    )
    .frame(width: canvasWidth, height: canvasHeight)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 1.0
    renderer.proposedSize = ProposedViewSize(width: canvasWidth, height: canvasHeight)

    guard let cgImage = renderer.cgImage else {
        print("✗ Failed to render \(spec.inputFilename)")
        return
    }

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    bitmapRep.size = NSSize(width: canvasWidth, height: canvasHeight)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("✗ Failed to encode PNG for \(spec.outputFilename)")
        return
    }

    do {
        try pngData.write(to: outputURL)
        print("✓ \(spec.outputFilename) (\(cgImage.width)×\(cgImage.height))")
    } catch {
        print("✗ Failed to write \(spec.outputFilename): \(error)")
    }
}

// MARK: - Main

@MainActor
func main() {
    let repoRoot = "/Users/amir/Desktop/Gecko Climbing"
    let inputDir = "\(repoRoot)/docs/screenshots/marketing-input-hires"
    let outputDir = "\(repoRoot)/docs/screenshots/marketing"

    try? FileManager.default.createDirectory(
        atPath: outputDir,
        withIntermediateDirectories: true
    )

    print("Generating \(specs.count) marketing frames at \(Int(canvasWidth))×\(Int(canvasHeight))")
    for spec in specs {
        render(spec: spec, inputDir: inputDir, outputDir: outputDir)
    }
    print("Done. Output: \(outputDir)")
}

// Top-level script execution
DispatchQueue.main.async {
    main()
    exit(0)
}
RunLoop.main.run()
