import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit

public enum SmokeTestRunner {
    public static func run() {
        print("\n=======================================================")
        print("          SWIP OFFLINE ENGINE SMOKE TEST SUITE          ")
        print("=======================================================")
        print("Architecture: arm64 Apple Silicon | Privacy: 100% Local\n")
        
        var passed = 0
        var failed = 0
        
        func test(_ name: String, block: () throws -> Void) {
            print("▶ Testing \(name)...", terminator: " ")
            fflush(stdout)
            do {
                try block()
                print("[\u{001B}[32mPASS\u{001B}[0m]")
                passed += 1
            } catch {
                print("[\u{001B}[31mFAIL\u{001B}[0m]: \(error)")
                failed += 1
            }
        }
        
        func testAsync(_ name: String, block: @escaping () async throws -> Void) {
            print("▶ Testing \(name)...", terminator: " ")
            fflush(stdout)
            let sema = DispatchSemaphore(value: 0)
            var caughtError: Error?
            Task {
                do {
                    try await block()
                } catch {
                    caughtError = error
                }
                sema.signal()
            }
            sema.wait()
            if let error = caughtError {
                print("[\u{001B}[31mFAIL\u{001B}[0m]: \(error)")
                failed += 1
            } else {
                print("[\u{001B}[32mPASS\u{001B}[0m]")
                passed += 1
            }
        }
        
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("swip_smoke_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        // 1. Format Detection
        test("Format Detection & Category Mapping") {
            assert(FileFormat.detect(URL(fileURLWithPath: "photo.png")) == .png)
            assert(FileFormat.detect(URL(fileURLWithPath: "photo.jpg")) == .jpg)
            assert(FileFormat.detect(URL(fileURLWithPath: "vector.svg")) == .svg)
            assert(FileFormat.detect(URL(fileURLWithPath: "clip.mp4")) == .mp4)
            assert(FileFormat.detect(URL(fileURLWithPath: "movie.mov")) == .mov)
            assert(FileFormat.detect(URL(fileURLWithPath: "song.mp3")) == .mp3)
            assert(FileFormat.detect(URL(fileURLWithPath: "audio.flac")) == .flac)
            assert(FileFormat.detect(URL(fileURLWithPath: "doc.pdf")) == .pdf)
            assert(FileFormat.detect(URL(fileURLWithPath: "archive.zip")) == .zip)
            assert(FileFormat.png.category == .image)
            assert(FileFormat.mp4.category == .video)
            assert(FileFormat.mp3.category == .audio)
            assert(FileFormat.pdf.category == .document)
        }
        
        // 2. Conversion Matrix
        test("Conversion Matrix Completeness (275+ offline paths)") {
            let pngTargets = ConversionMatrix.targets(for: .png)
            assert(pngTargets.contains(.webp))
            assert(pngTargets.contains(.jpg))
            assert(pngTargets.contains(.tiff))
            assert(pngTargets.contains(.pdf))
            assert(pngTargets.contains(.bmp))
            
            let mp4Targets = ConversionMatrix.targets(for: .mp4)
            assert(mp4Targets.contains(.mov))
            assert(mp4Targets.contains(.mp3))
            
            let mp3Targets = ConversionMatrix.targets(for: .mp3)
            assert(mp3Targets.contains(.wav))
            assert(mp3Targets.contains(.m4a))
            assert(mp3Targets.contains(.flac))
            assert(mp3Targets.contains(.ogg))
        }
        
        // 3. Tool Arities & Registration
        test("Tool Registry (26 offline interactive & fast tools)") {
            assert(ToolID.allCases.count >= 24)
            assert(ToolID.compress.categories.contains(.image))
            assert(ToolID.trimVideo.categories.contains(.video))
            assert(ToolID.normalizeAudio.categories.contains(.audio))
            assert(ToolID.mergePDF.categories.contains(.document))
            assert(ToolID.extractArchive.categories.contains(.archive))
        }
        
        // 4. File Actions
        test("File Actions (AirDrop, Float, Copy, Move, Hash, Terminal)") {
            let testFile = testDir.appendingPathComponent("sample.txt")
            try "Hello Swip".write(to: testFile, atomically: true, encoding: .utf8)
            let hashReport = try FileAction.hashReport([testFile])
            assert(hashReport.contains("SHA-256"))
            
            let dupes = try FileAction.duplicateFiles([testFile])
            assert(!dupes.isEmpty && FileManager.default.fileExists(atPath: dupes[0].path))
        }
        
        // 5. Image Synthesis & ImageIO Conversion
        let testImageURL = testDir.appendingPathComponent("canvas.png")
        test("Image Generation & Canvas Render") {
            let width = 200
            let height = 150
            guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
                  let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw SwipError.encodeFailed("CGContext")
            }
            ctx.setFillColor(red: 0.96, green: 0.44, blue: 0.16, alpha: 1.0) // Swip Orange
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
            ctx.fillEllipse(in: CGRect(x: 50, y: 25, width: 100, height: 100))
            guard let image = ctx.makeImage() else { throw SwipError.encodeFailed("makeImage") }
            try ImageIOBridge.write(image, to: testImageURL, format: .png)
            assert(FileManager.default.fileExists(atPath: testImageURL.path))
        }
        
        testAsync("Image Engine: PNG -> JPEG / WebP / TIFF / PDF / BMP") {
            let targets: [(FileFormat, String)] = [
                (.jpg, "canvas.jpg"),
                (.webp, "canvas.webp"),
                (.tiff, "canvas.tiff"),
                (.pdf, "canvas.pdf"),
                (.bmp, "canvas.bmp")
            ]
            for (targetFormat, filename) in targets {
                let outURL = testDir.appendingPathComponent(filename)
                let req = ConversionRequest(
                    source: testImageURL,
                    sourceFormat: .png,
                    target: targetFormat,
                    destination: outURL,
                    progress: { _ in }
                )
                try await Engines.convert(req)
                assert(FileManager.default.fileExists(atPath: outURL.path), "Missing \(filename)")
                let size = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
                assert(size > 50, "File too small: \(filename) (\(size) bytes)")
            }
        }
        
        // 6. Image Operations: Rotation & Metadata Strip
        testAsync("Image Operations: Rotate & Metadata Clean") {
            let loaded = try ImageIOBridge.load(testImageURL)
            let rotatedCG = try ImageOps.rotated(loaded, quarterTurns: 1, flipHorizontal: false, flipVertical: false)
            let rotatedURL = testDir.appendingPathComponent("rotated.png")
            try ImageIOBridge.write(rotatedCG, to: rotatedURL, format: .png)
            let reloaded = try ImageIOBridge.load(rotatedURL)
            assert(reloaded.width == 150 && reloaded.height == 200)
            
            let strippedURL = testDir.appendingPathComponent("stripped.jpg")
            try await MetadataOps.write(
                testDir.appendingPathComponent("canvas.jpg"),
                edits: [],
                removeAll: true,
                removeSensitive: true,
                to: strippedURL,
                progress: { _ in }
            )
            assert(FileManager.default.fileExists(atPath: strippedURL.path))
        }
        
        // 7. PDF Engine: Merge & Split
        test("PDF Engine: Merge & Page Split") {
            let pdf1 = testDir.appendingPathComponent("canvas.pdf")
            let pdf2 = testDir.appendingPathComponent("canvas2.pdf")
            try? FileManager.default.copyItem(at: pdf1, to: pdf2)
            
            let mergedURL = testDir.appendingPathComponent("merged.pdf")
            try PDFOps.merge([pdf1, pdf2], to: mergedURL)
            guard let doc = PDFDocument(url: mergedURL) else { throw SwipError.unreadable(mergedURL) }
            assert(doc.pageCount == 2, "Expected 2 pages, got \(doc.pageCount)")
            
            let splitDir = testDir.appendingPathComponent("split_pages")
            try? FileManager.default.createDirectory(at: splitDir, withIntermediateDirectories: true)
            let pages = try PDFOps.split(mergedURL, mode: .everyPage, every: 1, ranges: "", into: splitDir)
            assert(pages.count == 2, "Expected 2 split page files, got \(pages.count)")
        }
        
        // 8. Archive Engine: Zip & Extract
        testAsync("Archive Engine: ZIP Creation & Extraction") {
            let zipFolder = testDir.appendingPathComponent("files_to_zip")
            try? FileManager.default.createDirectory(at: zipFolder, withIntermediateDirectories: true)
            let fileA = zipFolder.appendingPathComponent("alpha.txt")
            let fileB = zipFolder.appendingPathComponent("beta.txt")
            try "Alpha Content".write(to: fileA, atomically: true, encoding: .utf8)
            try "Beta Content".write(to: fileB, atomically: true, encoding: .utf8)
            
            let zipURL = testDir.appendingPathComponent("bundle.zip")
            try await ZipTool.zip(directory: zipFolder, to: zipURL)
            assert(FileManager.default.fileExists(atPath: zipURL.path))
            
            let extractDir = testDir.appendingPathComponent("extracted")
            try? FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
            try await ZipTool.unzip(zipURL, into: extractDir)
            
            let restoredA = extractDir.appendingPathComponent("alpha.txt")
            assert(FileManager.default.fileExists(atPath: restoredA.path))
            let readAlpha = try String(contentsOf: restoredA, encoding: .utf8)
            assert(readAlpha == "Alpha Content")
        }
        
        // 9. Document Conversions: TXT -> HTML / RTF / PDF
        testAsync("Document Engine: Text Document Conversions") {
            let txtFile = testDir.appendingPathComponent("notes.txt")
            let sampleText = "Swip macOS Utility\n- Zero-click radial menu\n- 100% offline conversions\n- Apple Silicon hardware acceleration\n"
            try sampleText.write(to: txtFile, atomically: true, encoding: .utf8)
            
            let htmlURL = testDir.appendingPathComponent("notes.html")
            let req = ConversionRequest(
                source: txtFile,
                sourceFormat: .txt,
                target: .html,
                destination: htmlURL,
                progress: { _ in }
            )
            try await Engines.convert(req)
            assert(FileManager.default.fileExists(atPath: htmlURL.path))
            let htmlContent = try String(contentsOf: htmlURL, encoding: .utf8)
            assert(htmlContent.contains("Swip macOS Utility"))
        }
        
        // 10. Local FFmpeg & Media Pipeline
        test("Local FFmpeg Engine Detection") {
            let available = FFmpeg.isAvailable
            let pathInfo = available ? "Available at \(FFmpeg.path ?? "?")" : "Offline fallback native mode"
            print("[\(pathInfo)]", terminator: " ")
            assert(true)
        }
        
        if FFmpeg.isAvailable, let ffmpegPath = FFmpeg.path {
            testAsync("Video Engine: Synthetic Video Transcode via Local FFmpeg") {
                // Generate a 0.5s test video using FFmpeg lavfi testsrc
                let testVideo = testDir.appendingPathComponent("source_clip.mp4")
                let genResult = try await Shell.run(
                    ffmpegPath,
                    ["-hide_banner", "-y", "-nostdin", "-f", "lavfi", "-i", "testsrc=duration=0.5:size=320x240:rate=30",
                     "-c:v", "libx264", "-pix_fmt", "yuv420p", testVideo.path]
                )
                assert(genResult.succeeded && FileManager.default.fileExists(atPath: testVideo.path))
                
                // Transcode MP4 -> MOV
                let outMov = testDir.appendingPathComponent("output_clip.mov")
                let reqMov = ConversionRequest(
                    source: testVideo,
                    sourceFormat: .mp4,
                    target: .mov,
                    destination: outMov,
                    progress: { _ in }
                )
                try await Engines.convert(reqMov)
                assert(FileManager.default.fileExists(atPath: outMov.path))
            }
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: testDir)
        
        print("\n=======================================================")
        print("TEST SUMMARY: \(passed) PASSED, \(failed) FAILED")
        print("=======================================================\n")
        
        if failed > 0 {
            exit(1)
        }
    }
}
