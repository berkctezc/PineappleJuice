//
//  ContentView.swift
//  PineappleJuice
//
//  Created by Berkcan Tezcaner on 29.06.2025.
//

import SwiftUI
import AVFoundation
import VideoToolbox

struct ContentView: View {
    // Input file state
    @State private var inputURL: URL?
    @State private var inputFileName = "No input video selected"
    @State private var showInputPicker = false

    // Output folder state
    @State private var outputURL: URL?
    @State private var outputFolderName = "No output folder selected"
    @State private var showOutputPicker = false

    // Transcoding options
    @State private var outputFormat: OutputFormat = .mp4
    @State private var videoCodec: VideoCodec = .h264
    @State private var useHardwareAcceleration = true
    @State private var quality: Float = 0.75
    @State private var resolution: Resolution = .original
    @State private var frameRate: FrameRate = .original

    // Progress state
    @State private var isTranscoding = false
    @State private var progress: Double = 0
    @State private var showProgress = false

    // Error state
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    Text("Pineapple Juice")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top)

                    // Input File Selection
                    VStack(spacing: 8) {
                        Button(action: { showInputPicker = true }) {
                            Text("Select Input Video")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(colors: [.purple, .blue],
                                                startPoint: .leading,
                                                endPoint: .trailing)
                                )
                                .cornerRadius(12)
                        }
                        .fileImporter(
                            isPresented: $showInputPicker,
                            allowedContentTypes: [.movie],
                            allowsMultipleSelection: false
                        ) { result in
                            handleFileSelection(result: result, isInput: true)
                        }

                        Text(inputFileName)
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal)
                    }

                    // Output Folder Selection
                    VStack(spacing: 8) {
                        Button(action: { showOutputPicker = true }) {
                            Text("Select Output Folder")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(colors: [.orange, .red],
                                                startPoint: .leading,
                                                endPoint: .trailing)
                                )
                                .cornerRadius(12)
                        }
                        .fileImporter(
                            isPresented: $showOutputPicker,
                            allowedContentTypes: [.folder],
                            allowsMultipleSelection: false
                        ) { result in
                            handleFileSelection(result: result, isInput: false)
                        }

                        Text(outputFolderName)
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal)
                    }

                    // Transcoding Options
                    TranscodingOptionsView(
                        outputFormat: $outputFormat,
                        videoCodec: $videoCodec,
                        useHardwareAcceleration: $useHardwareAcceleration,
                        quality: $quality,
                        resolution: $resolution,
                        frameRate: $frameRate
                    )
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Transcode Button
                    Button(action: startTranscoding) {
                        if isTranscoding {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Start Transcoding")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(isTranscoding ? Color.gray : Color.green)
                    .cornerRadius(12)
                    .disabled(inputURL == nil || outputURL == nil || isTranscoding)

                    if showProgress {
                        ProgressView(value: progress, total: 1.0) {
                            Text("Transcoding Progress")
                        } currentValueLabel: {
                            Text("\(Int(progress * 100))%")
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Video Transcoder")
            .alert("Transcoding Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func handleFileSelection(result: Result<[URL], Error>, isInput: Bool) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let accessGranted = url.startAccessingSecurityScopedResource()
            print("Access granted: \(accessGranted)")

            DispatchQueue.main.async {
                if isInput {
                    inputURL = url
                    inputFileName = "Selected: \(url.lastPathComponent)"
                    print("Input file set: \(url.path)")
                } else {
                    outputURL = url
                    outputFolderName = "Selected: \(url.lastPathComponent)"
                    print("Output folder set: \(url.path)")
                }
            }

        case .failure(let error):
            print("Selection error: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }
    }

    private func startTranscoding() {
        guard let inputURL = inputURL, let outputURL = outputURL else {
            showError(message: "Please select both input and output locations")
            return
        }

        // Ensure the input file exists and is reachable
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            showError(message: "Input file does not exist or is not reachable.")
            return
        }
        // Ensure the input file is a supported video type
        let supportedExtensions = ["mp4", "mov", "m4v", "mkv"]
        guard supportedExtensions.contains(inputURL.pathExtension.lowercased()) else {
            showError(message: "Unsupported video file type. Please select an mp4, mov, m4v, or mkv file.")
            return
        }

        // Security-scoped resource access
        let accessGranted = inputURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                inputURL.stopAccessingSecurityScopedResource()
            }
        }
        guard accessGranted else {
            showError(message: "Failed to access the input file due to permissions.")
            return
        }

        let outputFileName = "transcoded_\(inputURL.deletingPathExtension().lastPathComponent).\(outputFormat.rawValue)"
        let outputFileURL = outputURL.appendingPathComponent(outputFileName)

        if FileManager.default.fileExists(atPath: outputFileURL.path) {
            showError(message: "A file with this name already exists in the output folder")
            return
        }

        isTranscoding = true
        showProgress = true
        progress = 0

        let transcoder = VideoTranscoder(
            inputURL: inputURL,
            outputURL: outputFileURL,
            outputFormat: outputFormat,
            videoCodec: videoCodec,
            useHardwareAcceleration: useHardwareAcceleration,
            quality: quality,
            resolution: resolution,
            frameRate: frameRate
        )

        DispatchQueue.global(qos: .userInitiated).async {
            transcoder.transcode { currentProgress in
                DispatchQueue.main.async {
                    self.progress = currentProgress
                }
            } completion: { result in
                DispatchQueue.main.async {
                    self.isTranscoding = false

                    switch result {
                    case .success(_):
                        // Optionally, you could show a success message here
                        break
                    case .failure(let error):
                        self.showError(message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

struct TranscodingOptionsView: View {
    @Binding var outputFormat: OutputFormat
    @Binding var videoCodec: VideoCodec
    @Binding var useHardwareAcceleration: Bool
    @Binding var quality: Float
    @Binding var resolution: Resolution
    @Binding var frameRate: FrameRate

    var body: some View {
        VStack(spacing: 20) {
            Text("Transcoding Options")
                .font(.headline)

            Picker("Output Format", selection: $outputFormat) {
                ForEach(OutputFormat.allCases, id: \.self) { format in
                    Text(format.rawValue.uppercased()).tag(format)
                }
            }
            .pickerStyle(.segmented)

            Picker("Video Codec", selection: $videoCodec) {
                ForEach(VideoCodec.allCases, id: \.self) { codec in
                    Text(codec.rawValue.uppercased()).tag(codec)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Hardware Acceleration", isOn: $useHardwareAcceleration)

            VStack(alignment: .leading) {
                Text("Quality: \(String(format: "%.0f%%", quality * 100))")
                Slider(value: $quality, in: 0.1...1.0, step: 0.05) {
                    Text("Quality")
                } minimumValueLabel: {
                    Text("Low")
                } maximumValueLabel: {
                    Text("High")
                }
            }

            Picker("Resolution", selection: $resolution) {
                ForEach(Resolution.allCases, id: \.self) { res in
                    Text(res.displayName).tag(res)
                }
            }
            .pickerStyle(.menu)

            Picker("Frame Rate", selection: $frameRate) {
                ForEach(FrameRate.allCases, id: \.self) { rate in
                    Text(rate.displayName).tag(rate)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

enum OutputFormat: String, CaseIterable {
    case mp4, mov, m4v
}

enum VideoCodec: String, CaseIterable {
    case h264, hevc, jpeg, proRes
}

enum Resolution: CaseIterable, Hashable {
    case original
    case p720
    case p1080
    case p4K
    case custom(width: Int, height: Int)

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .p720: return "720p (HD)"
        case .p1080: return "1080p (Full HD)"
        case .p4K: return "4K (UHD)"
        case .custom(let width, let height): return "Custom (\(width)x\(height))"
        }
    }

    static var allCases: [Resolution] {
        return [.original, .p720, .p1080, .p4K]
    }
}

enum FrameRate: CaseIterable {
    case original
    case fps24
    case fps30
    case fps60

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .fps24: return "24 fps"
        case .fps30: return "30 fps"
        case .fps60: return "60 fps"
        }
    }

    var value: Float? {
        switch self {
        case .original: return nil
        case .fps24: return 24
        case .fps30: return 30
        case .fps60: return 60
        }
    }
}

class VideoTranscoder {
    private let inputURL: URL
    private let outputURL: URL
    private let outputFormat: OutputFormat
    private let videoCodec: VideoCodec
    private let useHardwareAcceleration: Bool
    private let quality: Float
    private let resolution: Resolution
    private let frameRate: FrameRate

    init(inputURL: URL, outputURL: URL, outputFormat: OutputFormat, videoCodec: VideoCodec,
         useHardwareAcceleration: Bool, quality: Float, resolution: Resolution, frameRate: FrameRate) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.outputFormat = outputFormat
        self.videoCodec = videoCodec
        self.useHardwareAcceleration = useHardwareAcceleration
        self.quality = quality
        self.resolution = resolution
        self.frameRate = frameRate
    }

    func transcode(progressHandler: @escaping (Double) -> Void,
                   completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            let asset = AVAsset(url: inputURL)

            guard let reader = try? AVAssetReader(asset: asset) else {
                throw TranscoderError.failedToCreateReader
            }

            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                throw TranscoderError.noVideoTrackFound
            }

            let outputSettings = configureOutputSettings(for: videoTrack)

            let writer: AVAssetWriter
            do {
                writer = try AVAssetWriter(outputURL: outputURL, fileType: outputFileType)
            } catch {
                throw TranscoderError.failedToCreateWriter(error)
            }

            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings.videoSettings)
            videoInput.expectsMediaDataInRealTime = false

            if writer.canAdd(videoInput) {
                writer.add(videoInput)
            } else {
                throw TranscoderError.cannotAddVideoInput
            }

            if asset.tracks(withMediaType: .audio).first != nil {
                let audioOutputSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 44100,
                    AVEncoderBitRateKey: 128000
                ]

                let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
                audioInput.expectsMediaDataInRealTime = false

                if writer.canAdd(audioInput) {
                    writer.add(audioInput)
                } else {
                    throw TranscoderError.cannotAddAudioInput
                }
            }

            let readerOutputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
            ]

            let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
            if reader.canAdd(readerOutput) {
                reader.add(readerOutput)
            } else {
                throw TranscoderError.cannotAddReaderOutput
            }

            if !reader.startReading() {
                throw TranscoderError.readerFailedToStart(reader.error)
            }

            if !writer.startWriting() {
                throw TranscoderError.writerFailedToStart(writer.error)
            }

            writer.startSession(atSourceTime: CMTime.zero)

            let group = DispatchGroup()

            group.enter()
            videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "video.transcoding.queue")) {
                while videoInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        if !videoInput.append(sampleBuffer) {
                            reader.cancelReading()
                            break
                        }

                        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        let duration = asset.duration
                        let currentProgress = CMTimeGetSeconds(currentTime) / CMTimeGetSeconds(duration)
                        progressHandler(Double(currentProgress))
                    } else {
                        videoInput.markAsFinished()
                        group.leave()
                        break
                    }
                }
            }

            group.notify(queue: .main) {
                writer.finishWriting {
                    if writer.status == .completed {
                        completion(.success(self.outputURL))
                    } else {
                        completion(.failure(TranscoderError.writerFailed(writer.error)))
                    }
                }
            }

        } catch {
            completion(.failure(error))
        }
    }

    private var outputFileType: AVFileType {
        switch outputFormat {
        case .mp4: return .mp4
        case .mov: return .mov
        case .m4v: return .m4v
        }
    }

    private func configureOutputSettings(for track: AVAssetTrack) -> (videoSettings: [String: Any], hardwareAccelerated: Bool) {
        var videoSettings: [String: Any] = [:]
        var useHardware = false

        let naturalSize = track.naturalSize
        let targetSize: CGSize

        switch resolution {
        case .original:
            targetSize = naturalSize
        case .p720:
            targetSize = CGSize(width: 1280, height: 720)
        case .p1080:
            targetSize = CGSize(width: 1920, height: 1080)
        case .p4K:
            targetSize = CGSize(width: 3840, height: 2160)
        case .custom(let width, let height):
            targetSize = CGSize(width: width, height: height)
        }

        let size = calculateAspectRatioPreservingSize(source: naturalSize, target: targetSize)

        if useHardwareAcceleration && (videoCodec == .h264 || videoCodec == .hevc) {
            useHardware = true

            let codecType: AVVideoCodecType
            switch videoCodec {
            case .h264: codecType = .h264
            case .hevc: codecType = .hevc
            case .jpeg: codecType = .jpeg
            case .proRes: codecType = .proRes4444
            }

            let compressionProperties: [String: Any] = [
                AVVideoQualityKey: quality,
                AVVideoAverageBitRateKey: calculateBitrate(for: size, frameRate: frameRate.value ?? Float(track.nominalFrameRate), quality: quality)
            ]

            videoSettings = [
                AVVideoCodecKey: codecType.rawValue,
                AVVideoWidthKey: NSNumber(value: Float(size.width)),
                AVVideoHeightKey: NSNumber(value: Float(size.height)),
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
                AVVideoCompressionPropertiesKey: compressionProperties
            ]
        } else {
            let codec: AVVideoCodecType
            switch videoCodec {
            case .h264: codec = .h264
            case .hevc: codec = .hevc
            case .jpeg: codec = .jpeg
            case .proRes: codec = .proRes4444
            }

            videoSettings = [
                AVVideoCodecKey: codec.rawValue,
                AVVideoWidthKey: NSNumber(value: Float(size.width)),
                AVVideoHeightKey: NSNumber(value: Float(size.height)),
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
                AVVideoCompressionPropertiesKey: [
                    AVVideoQualityKey: quality,
                    AVVideoAverageBitRateKey: calculateBitrate(for: size, frameRate: frameRate.value ?? Float(track.nominalFrameRate), quality: quality)
                ]
            ]
        }

        return (videoSettings, useHardware)
    }

    private func calculateAspectRatioPreservingSize(source: CGSize, target: CGSize) -> CGSize {
        let sourceAspectRatio = source.width / source.height
        let targetAspectRatio = target.width / target.height

        if sourceAspectRatio > targetAspectRatio {
            let height = target.width / sourceAspectRatio
            return CGSize(width: target.width, height: height)
        } else {
            let width = target.height * sourceAspectRatio
            return CGSize(width: width, height: target.height)
        }
    }

    private func calculateBitrate(for size: CGSize, frameRate: Float, quality: Float) -> Int {
        let width = Float(size.width)
        let height = Float(size.height)
        let pixels = width * height
        let baseBitrate = pixels * frameRate / 30.0
        let adjustedBitrate = baseBitrate * quality
        return Int(adjustedBitrate)
    }
}

enum TranscoderError: Error, LocalizedError {
    case failedToCreateReader
    case noVideoTrackFound
    case failedToCreateWriter(Error?)
    case cannotAddVideoInput
    case cannotAddAudioInput
    case cannotAddReaderOutput
    case readerFailedToStart(Error?)
    case writerFailedToStart(Error?)
    case writerFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .failedToCreateReader:
            return "Failed to create video reader"
        case .noVideoTrackFound:
            return "No video track found in the input file"
        case .failedToCreateWriter(let error):
            return "Failed to create video writer: \(error?.localizedDescription ?? "Unknown error")"
        case .cannotAddVideoInput:
            return "Cannot add video input to writer"
        case .cannotAddAudioInput:
            return "Cannot add audio input to writer"
        case .cannotAddReaderOutput:
            return "Cannot add output to reader"
        case .readerFailedToStart(let error):
            return "Reader failed to start: \(error?.localizedDescription ?? "Unknown error")"
        case .writerFailedToStart(let error):
            return "Writer failed to start: \(error?.localizedDescription ?? "Unknown error")"
        case .writerFailed(let error):
            return "Writer failed: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}
