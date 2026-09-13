//
//  PPLivePhotoPreviewViewController.swift
//  PandaNote
//
//  Created by pan on 2026/4/20.
//  Copyright © 2026 Panway. All rights reserved.
//

import Foundation
import PhotosUI
import UIKit

final class PPLivePhotoPreviewViewController: UIViewController {
    var imagePath = ""
    var videoPath = ""
    // MARK: - UI

    private lazy var livePhotoView: PHLivePhotoView = {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var badgeImageView: UIImageView = {
        let iv = UIImageView(image: PHLivePhotoView.livePhotoBadgeImage(options: .overContent))
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.text = "长按查看动态效果"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.lightGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Data

    /// 传入相册资产的 localIdentifier
    var assetLocalIdentifier: String?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        let imageFileURL = URL(fileURLWithPath: imagePath)
        let videoFileURL = URL(fileURLWithPath: videoPath)

        // 检查文件是否存在
        if FileManager.default.fileExists(atPath: imageFileURL.path) &&
           FileManager.default.fileExists(atPath: videoFileURL.path) {
            loadLivePhoto(imageURL: imageFileURL, videoURL: videoFileURL)
        }
        else {
            PPToast.show("无法加载")
        }
//        loadLivePhoto()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(livePhotoView)
        view.addSubview(badgeImageView)
        view.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            livePhotoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            livePhotoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            livePhotoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            livePhotoView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.85),

            badgeImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            badgeImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            badgeImageView.widthAnchor.constraint(equalToConstant: 28),
            badgeImageView.heightAnchor.constraint(equalToConstant: 28),

            hintLabel.topAnchor.constraint(equalTo: livePhotoView.bottomAnchor, constant: 12),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Load

    func loadLivePhoto(imageURL: URL, videoURL: URL) {
        PHLivePhoto.request(
            withResourceFileURLs: [imageURL, videoURL],
            placeholderImage: nil,
            targetSize: CGSize(width: 400, height: 400),
            contentMode: .aspectFit
        ) { livePhoto, _ in
            guard let livePhoto = livePhoto else { return }

            DispatchQueue.main.async {
                self.displayLivePhoto(livePhoto)
            }
        }
    }

    func displayLivePhoto(_ livePhoto: PHLivePhoto) {
        let livePhotoView = PHLivePhotoView(frame: view.bounds)
        livePhotoView.livePhoto = livePhoto
        livePhotoView.contentMode = .scaleAspectFit
        view.addSubview(livePhotoView)

        // 自动播放（静音）
        livePhotoView.startPlayback(with: .hint)
    }

    private func loadLivePhoto() {
        guard let identifier = assetLocalIdentifier else { return }

        let results = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )
        guard let asset = results.firstObject else { return }

        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat // 优先高质量
        options.isNetworkAccessAllowed = true // 允许从 iCloud 下载

        PHImageManager.default().requestLivePhoto(
            for: asset,
            targetSize: view.bounds.size,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] livePhoto, info in
            guard let self else { return }
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            DispatchQueue.main.async {
                self.livePhotoView.livePhoto = livePhoto
                // 首次加载自动播放一次提示用户
                if !isDegraded {
                    self.livePhotoView.startPlayback(with: .hint)
                }
            }
        }
    }
}

// MARK: - PHLivePhotoViewDelegate

extension PPLivePhotoPreviewViewController: PHLivePhotoViewDelegate {
    func livePhotoView(
        _: PHLivePhotoView,
        willBeginPlaybackWith _: PHLivePhotoViewPlaybackStyle
    ) {
        hintLabel.isHidden = true
        UIView.animate(withDuration: 0.2) {
            self.badgeImageView.alpha = 0
        }
    }

    func livePhotoView(
        _: PHLivePhotoView,
        didEndPlaybackWith _: PHLivePhotoViewPlaybackStyle
    ) {
        hintLabel.isHidden = false
        UIView.animate(withDuration: 0.2) {
            self.badgeImageView.alpha = 1
        }
    }
}
