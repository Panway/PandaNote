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

class PlayerViewController: PPBaseViewController {
    // MARK: Properties
    
    // Attempt load and test these asset keys before playing.
    static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    var name = ""
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
    /// 本地文件地址。原来声明成 URL!（隐式解包），调用方忘赋值也不报错，现在改成安全的可选类型
    var localFileURL: URL?
    /// 网络播放地址（http/https 开头）。设置了就优先于 localFileURL，边缓冲边播放
    var httpURL = ""
    /// 播放 httpURL 时附加到每个 HTTP 请求上的自定义请求头（比如 WebDAV 的 Authorization）
    var httpHeaders: [String: String] = [:]
    /// 边播边缓存：把流式下载的数据顺手存到这个本地文件，下次直接本地秒开。留空则只播不缓存
    var cacheFilePath: String = ""
    /// 必须持有它：AVAsset 对 resourceLoader 的 delegate 是弱引用，这里不存就没人管下载了
    private var streamLoader: PPStreamResourceLoader?
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

        // 决定播放源：优先网络流（带自定义请求头，边缓冲边播），其次本地文件；两者都没有就明确报错，不再静默返回
        if !httpURL.isEmpty, let realURL = URL(string: httpURL),
           let fakeURL = PPStreamResourceLoader.fakeSchemeURL(for: realURL) {
            // 传了 cacheFilePath 就边播边缓存到该文件，否则只播不缓存
            let cacheURL = cacheFilePath.isEmpty ? nil : URL(fileURLWithPath: cacheFilePath)
            let loader = PPStreamResourceLoader(headers: httpHeaders, cacheFileURL: cacheURL)
            self.streamLoader = loader
            let urlAsset = AVURLAsset(url: fakeURL, options: nil)
            // 把假协议 URL 的数据请求交给 loader 处理，它才能真正带上请求头去下载
            urlAsset.resourceLoader.setDelegate(loader, queue: DispatchQueue(label: "PlayerVC.resourceLoader"))
            asset = urlAsset
        }
        else if let movieURL = localFileURL {
            asset = AVURLAsset(url: movieURL, options: nil)
            debugPrint("AVURLAsset:", movieURL)
        }
        else {
            handleErrorWithMessage("无法播放：没有传入文件路径（localFileURL）或网络地址（httpURL）")
        }

        // Make sure we don't have a strong reference cycle by only capturing self as weak.
        let interval = CMTimeMake(value: 1, timescale: 1)
        // 用 weak self 而不是 unowned：控制器若在观察者移除前被释放，unowned 会崩溃，weak 只是跳过
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] time in
            guard let self = self else { return }
            let timeElapsed = Float(CMTimeGetSeconds(time))

            self.timeSlider.value = Float(timeElapsed)
            self.startTimeLabel.text = self.createTimeString(time: timeElapsed)
        }
        self.tabBarController?.tabBar.isHidden = true

    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
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

        // 停掉网络下载并解除 URLSession 对 loader 的强引用，避免内存泄漏
        streamLoader?.shutdown()
        streamLoader = nil
        
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
        // rate == 0 才是"暂停中"。原来的 != 1.0 判断有缺陷：快进到 2.0 倍速时点按钮不会暂停
        if player.rate == 0 {
            if duration.isFinite && duration > 0 && currentTime >= duration {
                // 已播到结尾，回到开头再播
                currentTime = 0.0
            }
            player.play()
        }
        else {
            player.pause()
        }
	}
	
	@IBAction func rewindButtonWasPressed(_ sender: UIButton) {
        // 原版示例用负 rate 倒放，那是 macOS 的能力，iOS 的 AVPlayer 不支持负 rate（设了也不会倒放）。
        // 改成 iOS 用户习惯的行为：每点一次往回跳 10 秒
        guard currentTime.isFinite else { return }
        currentTime = max(currentTime - 10.0, 0.0)
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
        // 兜底：正常路径 viewDidDisappear -> removePlayerObserver 已经清理过；
        // 这里防止控制器没走 disappear 就被释放时，URLSession 还强引用着 loader 造成泄漏
        streamLoader?.shutdown()
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
        self.title = self.name
        playerView = PlayerView()
        self.view.addSubview(playerView)

        let bottomView = UIView()
        self.view.addSubview(bottomView)
        bottomView.backgroundColor = .white
        bottomView.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(self.pp_safeLayoutGuideBottom())
            make.height.equalTo(110)
        }

        playerView.snp.makeConstraints { (make) in
            make.top.equalTo(self.pp_safeLayoutGuideTop())
            make.left.right.equalTo(self.view)
            make.bottom.equalTo(bottomView.snp.top)
        }

        // 底部面板从上到下三行：进度条、时间标签、按钮。
        // 原来 frame 和约束混写，frame 全是白写的，而且滑条会压住时间标签，现在统一用约束

        // 第一行：进度条
        timeSlider = UISlider()
        bottomView.addSubview(timeSlider)
        timeSlider.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
        }
        timeSlider.tintColor = UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00)//VUE绿
        timeSlider.addTarget(self, action: #selector(timeSliderDidChange(_:)), for: .valueChanged)

        // 第二行：左边已播时间，右边总时长
        startTimeLabel = UILabel()
        startTimeLabel.textColor = .gray
        startTimeLabel.font = UIFont.systemFont(ofSize: 14)
        startTimeLabel.text = "0:00"
        bottomView.addSubview(startTimeLabel)
        startTimeLabel.snp.makeConstraints { (make) in
            make.top.equalTo(timeSlider.snp.bottom).offset(2)
            make.leading.equalTo(timeSlider)
        }

        durationLabel = UILabel()
        durationLabel.textColor = .gray
        durationLabel.font = UIFont.systemFont(ofSize: 14)
        durationLabel.text = "-:--"
        bottomView.addSubview(durationLabel)
        durationLabel.snp.makeConstraints { (make) in
            make.centerY.equalTo(startTimeLabel)
            make.trailing.equalTo(timeSlider)
        }

        // 第三行：播放按钮居中，倒带在左，快进在右
        playPauseButton = UIButton(type: .custom)
        playPauseButton.setTitle("▶️", for: .normal)
        playPauseButton.addTarget(self, action: #selector(playPauseButtonWasPressed(_:)), for: .touchUpInside)
        bottomView.addSubview(playPauseButton)
        playPauseButton.snp.makeConstraints { (make) in
            make.top.equalTo(startTimeLabel.snp.bottom).offset(6)
            make.centerX.equalToSuperview()
            make.width.equalTo(70)
            make.height.equalTo(30)
        }

        rewindButton = UIButton(type: .custom)
        rewindButton.setTitle("⏪", for: .normal)
        rewindButton.addTarget(self, action: #selector(rewindButtonWasPressed(_:)), for: .touchUpInside)
        bottomView.addSubview(rewindButton)
        rewindButton.snp.makeConstraints { (make) in
            make.centerY.equalTo(playPauseButton)
            make.trailing.equalTo(playPauseButton.snp.leading).offset(-10)
            make.width.height.equalTo(playPauseButton)
        }

        fastForwardButton = UIButton(type: .custom)
        fastForwardButton.setTitle("⏩", for: .normal)
        fastForwardButton.addTarget(self, action: #selector(fastForwardButtonWasPressed(_:)), for: .touchUpInside)
        bottomView.addSubview(fastForwardButton)
        fastForwardButton.snp.makeConstraints { (make) in
            make.centerY.equalTo(playPauseButton)
            make.leading.equalTo(playPauseButton.snp.trailing).offset(10)
            make.width.height.equalTo(playPauseButton)
        }
    }
}
