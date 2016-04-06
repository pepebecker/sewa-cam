//
//  RecordVideoVC.swift
//  SewaCam
//
//  Created by Pepe Becker on 3/12/16.
//  Copyright © 2016 Pepe Becker. All rights reserved.
//

import Foundation
import UIKit
import AVKit
import AVFoundation
import AssetsLibrary
import MediaPlayer

class RecordVideoVC: UIViewController, AVCaptureFileOutputRecordingDelegate {
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var songTitleLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var trashButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var output: AVCaptureMovieFileOutput?
    var prevLayer: AVCaptureVideoPreviewLayer?
    
    var videoPlayer = AVPlayerViewController()
    var musicPlayer = MPMusicPlayerController()
    
    var mixComposition: AVMutableComposition?
    var videoURL: NSURL?
    var videoAsset: AVURLAsset?
    
    var audioAssets: [AVURLAsset?] = []
    var audioStartPlaybackTimes: [NSTimeInterval?] = []
    var audioStopPlaybackTimes: [NSTimeInterval?] = []
    var audioStartPlayingTimes: [NSTimeInterval?] = []
    var startRecordingTime: NSTimeInterval?
    
    var isRecording: Bool = false
    var isPreviewing: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.musicPlayer = MPMusicPlayerController.systemMusicPlayer()
        
        self.session = AVCaptureSession()
        self.device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        do {
            try self.input = AVCaptureDeviceInput(device: self.device)
            self.session?.addInput(self.input)
        } catch let error as NSError {
            print(error)
        }
        
        self.output = AVCaptureMovieFileOutput()
        let totalSeconds: Float64 = 60
        let preferredTimeScale: Int32 = 30
        let maxDuration = CMTimeMakeWithSeconds(totalSeconds, preferredTimeScale)
        self.output?.maxRecordedDuration = maxDuration
        self.output?.minFreeDiskSpaceLimit = 1024 * 1024
        self.session?.addOutput(self.output)
        self.session?.sessionPreset = AVCaptureSessionPresetMedium
        self.prevLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.prevLayer?.frame.size = self.videoView.frame.size
        self.prevLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.prevLayer?.backgroundColor = UIColor.blackColor().CGColor
        self.videoView.layer.addSublayer(self.prevLayer!)
        self.view.addSubview(self.videoView)
        
        self.recordButton.addTarget(self, action: "recordButtonPressed", forControlEvents: .TouchUpInside)
        self.trashButton.addTarget(self, action: "trashButtonPressed", forControlEvents: .TouchUpInside)
        self.saveButton.addTarget(self, action: "saveButtonPressed", forControlEvents: .TouchUpInside)
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "handleNowPlayingItemChanged", name: MPMusicPlayerControllerNowPlayingItemDidChangeNotification, object: nil)
        
        self.musicPlayer.beginGeneratingPlaybackNotifications()
        
        let swipeLeftRcognizer = UISwipeGestureRecognizer(target: self, action: "nextSong")
        swipeLeftRcognizer.direction = .Left
        self.view.addGestureRecognizer(swipeLeftRcognizer)
        
        let swipeRightRcognizer = UISwipeGestureRecognizer(target: self, action: "previousSong")
        swipeRightRcognizer.direction = .Right
        self.view.addGestureRecognizer(swipeRightRcognizer)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: "togglePlaying")
        self.view.addGestureRecognizer(tapRecognizer)
        
        self.reset()
    }
    
    func handleNowPlayingItemChanged() {
        if let title = self.musicPlayer.nowPlayingItem?.valueForProperty(MPMediaItemPropertyTitle) as? String {
            self.songTitleLabel.text = title
            self.songTitleLabel.hidden = false
        } else {
            self.songTitleLabel.hidden = true
        }
    }
    
    func nextSong() {
        if (isPreviewing) {
            return
        }
        
        if (isRecording && self.musicPlayer.playbackState == .Playing) {
            if let url = self.musicPlayer.nowPlayingItem?.valueForProperty(MPMediaItemPropertyAssetURL) as? NSURL {
                addAudioTrack(url)
                addStopTime(self.musicPlayer.currentPlaybackTime)
            }
        }
        
        self.musicPlayer.skipToNextItem()
        
        if (isRecording && self.musicPlayer.playbackState == .Playing) {
            if (self.musicPlayer.playbackState == .Playing) {
                addStartTime(self.musicPlayer.currentPlaybackTime)
            }
        }
    }
    
    func previousSong() {
        if (isPreviewing) {
            return
        }
        
        if (isRecording && self.musicPlayer.playbackState == .Playing) {
            if let url = self.musicPlayer.nowPlayingItem?.valueForProperty(MPMediaItemPropertyAssetURL) as? NSURL {
                addAudioTrack(url)
                addStopTime(self.musicPlayer.currentPlaybackTime)
            }
        }
        
        self.musicPlayer.skipToPreviousItem()
        
        if (isRecording && self.musicPlayer.playbackState == .Playing) {
            if (self.musicPlayer.playbackState == .Playing) {
                addStartTime(self.musicPlayer.currentPlaybackTime)
            }
        }
    }
    
    func togglePlaying() {
        if (isPreviewing == false) {
            if (self.musicPlayer.playbackState == .Playing) {
                print("Pause Music")
                if (isRecording && self.musicPlayer.playbackState == .Playing) {
                    if let url = self.musicPlayer.nowPlayingItem?.valueForProperty(MPMediaItemPropertyAssetURL) as? NSURL {
                        addAudioTrack(url)
                        addStopTime(self.musicPlayer.currentPlaybackTime)
                    }
                }
                self.musicPlayer.pause()
            } else {
                print("Start Music")
                self.musicPlayer.play()
                if (isRecording) {
                    addStartTime(self.musicPlayer.currentPlaybackTime)
                }
            }
        }
    }
    
    func addAudioTrack(url: NSURL) {
        let audioAsset = AVURLAsset(URL: url, options: nil)
        self.audioAssets.append(audioAsset)
    }
    
    func addStartTime(time: NSTimeInterval) {
        self.audioStartPlaybackTimes.append(time)
        self.audioStartPlayingTimes.append(CACurrentMediaTime() - self.startRecordingTime!)
        print(CACurrentMediaTime() - self.startRecordingTime!)
    }
    
    func addStopTime(time: NSTimeInterval) {
        self.audioStopPlaybackTimes.append(time)
    }
    
    func reset() {
        print("Reset")
        
        self.videoURL = nil
        self.videoAsset = nil
        
        self.audioAssets = []
        self.audioStartPlayingTimes = []
        self.audioStartPlaybackTimes = []
        self.audioStopPlaybackTimes = []
        
        self.recordButton.setTitle("Record", forState: .Normal)
        self.recordButton.hidden = false
        self.trashButton.hidden = true
        self.saveButton.hidden = true
        self.isRecording = false
        self.isPreviewing = false
        
        self.videoPlayer.player?.pause()
        self.videoPlayer.player?.seekToTime(kCMTimeZero)
        
        if (self.videoPlayer.parentViewController != nil) {
            self.videoPlayer.removeFromParentViewController()
        }
        
        if (self.videoPlayer.view.superview != nil) {
            self.videoPlayer.view.removeFromSuperview()
        }
        
        if let title = self.musicPlayer.nowPlayingItem?.valueForProperty(MPMediaItemPropertyTitle) as? String {
            self.songTitleLabel.text = title
            self.songTitleLabel.hidden = false
        } else {
            self.songTitleLabel.hidden = true
        }
        
        self.session?.performSelectorInBackground("startRunning", withObject: nil)
    }
    
    func startRecoding() {
        print("Start recording")
        
        self.startRecordingTime = CACurrentMediaTime()
        addStartTime(self.musicPlayer.currentPlaybackTime)
        
        if (self.musicPlayer.playbackState != .Playing) {
            self.musicPlayer.play()
        }
        
        var dirPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let docsDir = dirPaths[0]
        let outputFilePath = docsDir.stringByAppendingString("/FinalVideo.mov")
        videoURL = NSURL(fileURLWithPath: outputFilePath)
        
        if NSFileManager.defaultManager().fileExistsAtPath(outputFilePath) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(outputFilePath)
            } catch {
                print("Error: Not able to remove video")
            }
        }
        
        self.output?.startRecordingToOutputFileURL(videoURL, recordingDelegate: self)
    }
    
    func recordButtonPressed() {
        if (self.isRecording == false) {
            print("Record button pressed")
            startRecoding()
            self.recordButton.setTitle("Stop", forState: .Normal)
            self.isRecording = true
        } else {
            print("Stop button pressed")
            self.output?.stopRecording()
            self.session?.performSelectorInBackground("stopRunning", withObject: nil)
            self.recordButton.hidden = true
            self.trashButton.hidden = false
            self.saveButton.hidden = false
            self.isRecording = false
            self.isPreviewing = true
            
            if (self.musicPlayer.playbackState == .Playing) {
                if let url = self.musicPlayer.nowPlayingItem?.valueForProperty(MPMediaItemPropertyAssetURL) as? NSURL {
                    addAudioTrack(url)
                    addStopTime(self.musicPlayer.currentPlaybackTime)
                }
                self.musicPlayer.pause()
            }
        }
    }
    
    func trashButtonPressed() {
        print("Trash button pressed")
        reset()
    }
    
    func saveButtonPressed() {
        print("Save button pressed")
        self.saveVideo()
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        self.videoURL = outputFileURL
        print("Stopped recording")
        mergeVideoAndAudio()
    }
    
    func mergeVideoAndAudio() {
        print("Merging Video and Audio")
        
        self.mixComposition = AVMutableComposition()
        var compositionVideoTrack: AVMutableCompositionTrack?
        var compositionAudioTrack: AVMutableCompositionTrack?
        
        print("Audio Asstes: \(self.audioAssets.count)")
        print("Audio Start Playing Times: \(self.audioStartPlayingTimes.count)")
        print("Audio Start Playback Times: \(self.audioStartPlaybackTimes.count)")
        print("Audio Stop Playback Times: \(self.audioStopPlaybackTimes.count)")
        
        if let url = self.videoURL {
            self.videoAsset = AVURLAsset(URL: url, options: nil)
            let video_timeRange = CMTimeRange(start: kCMTimeZero, duration: videoAsset!.duration)
            
            compositionVideoTrack = self.mixComposition!.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                try compositionVideoTrack!.insertTimeRange(video_timeRange, ofTrack: videoAsset!.tracksWithMediaType(AVMediaTypeVideo)[0], atTime: kCMTimeZero)
            } catch {
                print("Error: Not able to insert video track")
            }
        }
        
        for (var i: Int = 0; i < self.audioAssets.count; i++) {
            let startTime = CMTimeMakeWithSeconds(self.audioStartPlaybackTimes[i]!, 1000000)
            let duration = CMTimeMakeWithSeconds(self.audioStopPlaybackTimes[i]! - self.audioStartPlaybackTimes[i]!, 1000000)
            let timeRange = CMTimeRangeMake(startTime, duration)
            
            let startPlayingTime = CMTimeMakeWithSeconds(self.audioStartPlayingTimes[i]!, 1000000)
            
            compositionAudioTrack = self.mixComposition!.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                try compositionAudioTrack!.insertTimeRange(timeRange, ofTrack: self.audioAssets[i]!.tracksWithMediaType(AVMediaTypeAudio)[0], atTime: startPlayingTime)
            } catch let error as NSError {
                print(error.userInfo)
            }
        }
        
        let assetVideoTrack = (videoAsset!.tracksWithMediaType(AVMediaTypeVideo)).last! as AVAssetTrack
        compositionVideoTrack!.preferredTransform = assetVideoTrack.preferredTransform
        
        
        let item = AVPlayerItem(asset: self.mixComposition!)
        let player = AVPlayer(playerItem: item)
        
        self.videoPlayer = AVPlayerViewController()
        self.videoPlayer.player = player
        self.videoPlayer.view.frame = self.videoView.frame;
        self.addChildViewController(self.videoPlayer)
        self.view.addSubview(self.videoPlayer.view)
        self.videoPlayer.didMoveToParentViewController(self)
    }
    
    func saveVideo() {
        print("Saving Video")
        
        var dirPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let docsDir = dirPaths[0]
        let outputFilePath = docsDir.stringByAppendingString("/FinalVideo.mov")
        let outputFileUrl = NSURL(fileURLWithPath: outputFilePath)
        
        if NSFileManager.defaultManager().fileExistsAtPath(outputFilePath) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(outputFilePath)
            } catch {
                print("Error: Not able to remove video")
            }
        }
        
        let _assetExport = AVAssetExportSession(asset: self.mixComposition!, presetName: AVAssetExportPresetHighestQuality)
        _assetExport?.outputFileType = AVFileTypeMPEG4
        _assetExport?.outputURL = outputFileUrl
        
        _assetExport?.exportAsynchronouslyWithCompletionHandler({ () -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.exportDidFinish(_assetExport!)
            })
        })
    }
    
    func exportDidFinish(session: AVAssetExportSession) {
        if (session.status == .Completed) {
            let outputURL = session.outputURL
            let library = ALAssetsLibrary()
            if (library.videoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL)) {
                library.writeVideoAtPathToSavedPhotosAlbum(outputURL, completionBlock: { (assetURL: NSURL!, error: NSError!) -> Void in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        if (error != nil) {
                            UIAlertView(title: "Error", message: error.description, delegate: nil, cancelButtonTitle: "Ok").show()
                            self.reset()
                        } else {
                            UIAlertView(title: "Video Saved", message: "Saved To Photo Album", delegate: self, cancelButtonTitle: "Ok").show()
                            self.reset()
                        }
                    })
                })
            }
        } else {
            print("Session did not complete")
        }
    }
    
}