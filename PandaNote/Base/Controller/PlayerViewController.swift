/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller containing a player view and basic playback controls.
*/

import Foundation
import AVFoundation
import UIKit

/*
	KVO context used to differentiate KVO callbacks for this class versus other
	classes in its class hierarchy.
*/
private var playerViewControllerKVOContext = 0

class PlayerViewController: UIViewController {
    // MARK: Properties
    
    // Attempt load and test these asset keys before playing.
    static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]

    @objc let player = AVPlayer()

	var currentTime: Double {
		get {
            return CMTimeGetSeconds(player.currentTime())
        }
		set {
            let newTime = CMTimeMakeWithSeconds(newValue, preferredTimescale: 1)
            player.seek(to: newTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
		}
	}

	var duration: Double {
        guard let currentItem = player.currentItem else { return 0.0 }

        return CMTimeGetSeconds(currentItem.duration)
	}

	var rate: Float {
		get {
            return player.rate
        }

        set {
            player.rate = newValue
        }
	}

    var asset: AVURLAsset? {
        didSet {
            guard let newAsset = asset else { return }

            asynchronouslyLoadURLAsset(newAsset)
        }
    }
    
	private var playerLayer: AVPlayerLayer? {
        return playerView.playerLayer
    }
	
	/*
	A formatter for individual date components used to provide an appropriate
	value for the `startTimeLabel` and `durationLabel`.
	*/
	let timeRemainingFormatter: DateComponentsFormatter = {
		let formatter = DateComponentsFormatter()
		formatter.zeroFormattingBehavior = .pad
		formatter.allowedUnits = [.minute, .second]
		
		return formatter
	}()

    /*
        A token obtained from calling `player`'s `addPeriodicTimeObserverForInterval(_:queue:usingBlock:)`
        method.
    */
	private var timeObserverToken: Any?

	private var playerItem: AVPlayerItem? = nil {
        didSet {
            /*
                If needed, configure player item here before associating it with a player.
                (example: adding outputs, setting text style rules, selecting media options)
            */
            player.replaceCurrentItem(with: self.playerItem)
        }
	}
    var localFilePath:String = ""
    var localFileURL:URL!
    open var filePathStr: String = ""//文件相对路径


    // MARK: - IBOutlets
    var timeSlider: UISlider!
    var startTimeLabel: UILabel!
    var durationLabel: UILabel!
    var rewindButton: UIButton!
    var playPauseButton: UIButton!
    var fastForwardButton: UIButton!
    var playerView: PlayerView!
    
    // MARK: - View Controller
    override func viewDidLoad() {
        super.viewDidLoad()
        pp_initUI()
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        /*
            Update the UI when these player properties change.
        
            Use the context parameter to distinguish KVO for our particular observers 
            and not those destined for a subclass that also happens to be observing 
            these properties.
        */
        addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.duration), options: [.new, .initial], context: &playerViewControllerKVOContext)
        addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.rate), options: [.new, .initial], context: &playerViewControllerKVOContext)
        addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.status), options: [.new, .initial], context: &playerViewControllerKVOContext)
        
        playerView.playerLayer.player = player
        
//        let movieURL = Bundle.main.url(forResource: "ElephantSeals", withExtension: "mov")!
        let movieURL = localFileURL//URL(string: "http://music.163.com/song/media/outer/url?id=545558246.mp3")

        asset = AVURLAsset(url: movieURL!, options: nil)
        
        // Make sure we don't have a strong reference cycle by only capturing self as weak.
        let interval = CMTimeMake(value: 1, timescale: 1)
		timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [unowned self] time in
			let timeElapsed = Float(CMTimeGetSeconds(time))
			
			self.timeSlider.value = Float(timeElapsed)
			self.startTimeLabel.text = self.createTimeString(time: timeElapsed)
		}
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removePlayerObserver()
    }
    func removePlayerObserver() {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        
        player.pause()
        
        removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.duration), context: &playerViewControllerKVOContext)
        removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.rate), context: &playerViewControllerKVOContext)
        removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.status), context: &playerViewControllerKVOContext)
    }
    
    // MARK: - Asset Loading

    func asynchronouslyLoadURLAsset(_ newAsset: AVURLAsset) {
        /*
            Using AVAsset now runs the risk of blocking the current thread (the 
            main UI thread) whilst I/O happens to populate the properties. It's
            prudent to defer our work until the properties we need have been loaded.
将我们的工作推迟到加载所需属性后再进行，防止阻塞主线程
        */
        newAsset.loadValuesAsynchronously(forKeys: PlayerViewController.assetKeysRequiredToPlay) {
            /*
                The asset invokes its completion handler on an arbitrary queue. 
                To avoid multiple threads using our internal state at the same time 
                we'll elect to use the main thread at all times, let's dispatch
                our handler to the main queue.
为了避免多个线程同时使用我们的内部状态，我们将选择始终使用主线程，让我们将处理程序分派到主队列
            */
            DispatchQueue.main.async {
                /*
                    `self.asset` has already changed! No point continuing because
                    another `newAsset` will come along in a moment.
                */
                guard newAsset == self.asset else { return }

                /*
                    Test whether the values of each of the keys we need have been
                    successfully loaded.
                 测试我们所需的每个键的值是否已成功加载
                */
                for key in PlayerViewController.assetKeysRequiredToPlay {
                    var error: NSError?
                    
                    if newAsset.statusOfValue(forKey: key, error: &error) == .failed {
                        let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")

                        let message = String.localizedStringWithFormat(stringFormat, key)
                        
                        self.handleErrorWithMessage(message, error: error)
                        
                        return
                    }
                }
                
                // We can't play this asset.
                if !newAsset.isPlayable || newAsset.hasProtectedContent {
                    let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                    
                    self.handleErrorWithMessage(message)
                    
                    return
                }
                
                /*
                    We can play this asset. Create a new `AVPlayerItem` and make
                    it our player's current item.
                */
                self.playerItem = AVPlayerItem(asset: newAsset)
            }
        }
    }

    // MARK: - IBActions

	@IBAction func playPauseButtonWasPressed(_ sender: UIButton) {
		if player.rate != 1.0 {
            // Not playing forward, so play.
 			if currentTime == duration {
                // At end, so got back to begining.
				currentTime = 0.0
			}

			player.play()
		}
        else {
            // Playing, so pause.
			player.pause()
		}
	}
	
	@IBAction func rewindButtonWasPressed(_ sender: UIButton) {
        // Rewind no faster than -2.0.
        rate = max(player.rate - 2.0, -2.0)
	}
	
	@IBAction func fastForwardButtonWasPressed(_ sender: UIButton) {
        // Fast forward no faster than 2.0.
        rate = min(player.rate + 2.0, 2.0)
	}

    @IBAction func timeSliderDidChange(_ sender: UISlider) {
        currentTime = Double(sender.value)
    }
    
    // MARK: - KVO Observation

    // Update our UI when player or `player.currentItem` changes.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        // Make sure the this KVO callback was intended for this view controller.
        guard context == &playerViewControllerKVOContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        if keyPath == #keyPath(PlayerViewController.player.currentItem.duration) {
            // Update timeSlider and enable/disable controls when duration > 0.0

            /*
                Handle `NSNull` value for `NSKeyValueChangeNewKey`, i.e. when 
                `player.currentItem` is nil.
            */
            let newDuration: CMTime
            if let newDurationAsValue = change?[NSKeyValueChangeKey.newKey] as? NSValue {
                newDuration = newDurationAsValue.timeValue
            }
            else {
                newDuration = CMTime.zero
            }

            let hasValidDuration = newDuration.isNumeric && newDuration.value != 0
            let newDurationSeconds = hasValidDuration ? CMTimeGetSeconds(newDuration) : 0.0
			let currentTime = hasValidDuration ? Float(CMTimeGetSeconds(player.currentTime())) : 0.0

            timeSlider.maximumValue = Float(newDurationSeconds)

            timeSlider.value = currentTime
            
            rewindButton.isEnabled = hasValidDuration
            
            playPauseButton.isEnabled = hasValidDuration
            
            fastForwardButton.isEnabled = hasValidDuration
            
            timeSlider.isEnabled = hasValidDuration
            
            startTimeLabel.isEnabled = hasValidDuration
            startTimeLabel.text = createTimeString(time: currentTime)
			
            durationLabel.isEnabled = hasValidDuration
            durationLabel.text = createTimeString(time: Float(newDurationSeconds))
        }
        else if keyPath == #keyPath(PlayerViewController.player.rate) {
            // Update `playPauseButton` image.

            let newRate = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).doubleValue
            
            let buttonImageName = newRate == 1.0 ? "PauseButton" : "PlayButton"
            
            let buttonImage = UIImage(named: buttonImageName)

            playPauseButton.setImage(buttonImage, for: UIControl.State())
            playPauseButton.setTitle(newRate == 1.0 ? "⏸" : "▶️", for: UIControl.State())
        }
        else if keyPath == #keyPath(PlayerViewController.player.currentItem.status) {
            // Display an error if status becomes `.Failed`.

            /*
                Handle `NSNull` value for `NSKeyValueChangeNewKey`, i.e. when
                `player.currentItem` is nil.
            */
            let newStatus: AVPlayerItem.Status

            if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                newStatus = AVPlayerItem.Status(rawValue: newStatusAsNumber.intValue)!
            }
            else {
                newStatus = .unknown
            }
            
            if newStatus == .failed {
                handleErrorWithMessage(player.currentItem?.error?.localizedDescription, error:player.currentItem?.error)
            }
        }
    }

    // Trigger KVO for anyone observing our properties affected by player and player.currentItem
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        let affectedKeyPathsMappingByKey: [String: Set<String>] = [
            "duration":     [#keyPath(PlayerViewController.player.currentItem.duration)],
            "rate":         [#keyPath(PlayerViewController.player.rate)]
        ]
        
        return affectedKeyPathsMappingByKey[key] ?? super.keyPathsForValuesAffectingValue(forKey: key)
	}
    deinit {
//        removePlayerObserver()

    }
    // MARK: - Error Handling

	func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        NSLog("Error occured with message: \(String(describing: message)), error: \(String(describing: error)).")
    
        let alertTitle = NSLocalizedString("alert.error.title", comment: "Alert title for errors")
        let defaultAlertMessage = NSLocalizedString("error.default.description", comment: "Default error message when no NSError provided")

        let alert = UIAlertController(title: alertTitle, message: message == nil ? defaultAlertMessage : message, preferredStyle: UIAlertController.Style.alert)

        let alertActionTitle = NSLocalizedString("alert.error.actions.OK", comment: "OK on error alert")

        let alertAction = UIAlertAction(title: alertActionTitle, style: .default, handler: nil)
        
        alert.addAction(alertAction)

        present(alert, animated: true, completion: nil)
	}
	
	// MARK: Convenience
	
	func createTimeString(time: Float) -> String {
		let components = NSDateComponents()
		components.second = Int(max(0.0, time))
		
		return timeRemainingFormatter.string(from: components as DateComponents)!
	}
    
    // MARK: UI init
    func pp_initUI() {
        playerView = PlayerView()
        self.view.addSubview(playerView)
        playerView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-80)
        }
        
        let bottomView = UIView()
        self.view.addSubview(bottomView)
        bottomView.backgroundColor = UIColor.white
        bottomView.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(100)
        }
        
        rewindButton = UIButton.init(type: UIButton.ButtonType.custom)
        bottomView.addSubview(rewindButton)
        rewindButton.frame = CGRect.init(x: 40, y: 0, width: 40, height: 40)
//        rewindButton.setImage(UIImage.init(named: "share"), for: UIControl.State.normal)
        rewindButton.setTitle("⏪", for: UIControl.State.normal)
        rewindButton.addTarget(self, action: #selector(rewindButtonWasPressed(_:)), for: UIControl.Event.touchUpInside)
        rewindButton.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(40)
            make.left.equalToSuperview()
            make.width.equalTo(70)
            make.height.equalTo(30)
        }
        
        playPauseButton = UIButton.init(type: UIButton.ButtonType.custom)
        bottomView.addSubview(playPauseButton)
        playPauseButton.frame = CGRect.init(x: 40, y: 0, width: 40, height: 40)
        //        rewindButton.setImage(UIImage.init(named: "share"), for: UIControl.State.normal)
        playPauseButton.setTitle("▶️", for: UIControl.State.normal)
        playPauseButton.addTarget(self, action: #selector(playPauseButtonWasPressed(_:)), for: UIControl.Event.touchUpInside)
        playPauseButton.snp.makeConstraints { (make) in
            make.top.equalTo(rewindButton)
            make.left.equalTo(rewindButton.snp.right)
            make.width.equalTo(70)
            make.height.equalTo(30)
        }
        
        fastForwardButton = UIButton.init(type: UIButton.ButtonType.custom)
        bottomView.addSubview(fastForwardButton)
        fastForwardButton.frame = CGRect.init(x: 40, y: 0, width: 40, height: 40)
        //        rewindButton.setImage(UIImage.init(named: "share"), for: UIControl.State.normal)
        fastForwardButton.setTitle("⏩", for: UIControl.State.normal)
        fastForwardButton.addTarget(self, action: #selector(playPauseButtonWasPressed(_:)), for: UIControl.Event.touchUpInside)
        fastForwardButton.snp.makeConstraints { (make) in
            make.top.equalTo(rewindButton)
            make.left.equalTo(playPauseButton.snp.right)
            make.width.equalTo(70)
            make.height.equalTo(30)
        }
        
        timeSlider = UISlider()
        bottomView.addSubview(timeSlider)
        timeSlider.snp.makeConstraints { (make) in
            make.top.left.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(8)
        }
        timeSlider.addTarget(self, action: #selector(timeSliderDidChange(_:)), for: UIControl.Event.valueChanged)
        
        startTimeLabel = UILabel(frame: CGRect(x: 110, y: 0, width: 100, height: 40))
        //        aLB.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        //        aLB.backgroundColor = UIColor.white
        startTimeLabel.textColor = UIColor.gray
        //        aLB.textAlignment = NSTextAlignment.center
        startTimeLabel.font = UIFont.systemFont(ofSize: 16)
        startTimeLabel.text = "0:00"
        bottomView.addSubview(startTimeLabel)
        
        
        durationLabel = UILabel(frame: CGRect(x: 300, y: 0, width: 100, height: 40))
        //        aLB.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        //        aLB.backgroundColor = UIColor.white
        durationLabel.textColor = UIColor.gray
        //        aLB.textAlignment = NSTextAlignment.center
        durationLabel.font = UIFont.systemFont(ofSize: 16)
        durationLabel.text = "-:--"
        bottomView.addSubview(durationLabel)
        
    }
}
