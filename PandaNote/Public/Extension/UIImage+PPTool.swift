//
//  UIImage+PPTool.swift
//  PandaNote
//
//  Created by Panway on 2020/5/6.
//  Copyright © 2020 Panway. All rights reserved.
//

import Foundation
extension UIImage {
    
    func pp_rotate(_ degrees: CGFloat) -> UIImage {
        let image = self
        // 将度数转换为弧度
        let radians = degrees * .pi / 180

        // 计算旋转后的图像大小
        let rotatedRect = CGRect(origin: CGPoint.zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
        let rotatedSize = rotatedRect.size

        // 创建一个绘制上下文
        UIGraphicsBeginImageContext(rotatedSize)

        // 在绘制上下文中绘制旋转后的图像
        let context = UIGraphicsGetCurrentContext()!
        // 在进行旋转时，要将 CGContext 的原点移动到旋转后图像的中心点，然后再进行旋转和绘制操作。
        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        context.rotate(by: radians)
        image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                               width: image.size.width, height: image.size.height))

        // 获取绘制结果并关闭上下文
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return rotatedImage
    }
    func maskWithColor(color: UIColor) -> UIImage? {
        let maskImage = cgImage!
        
        let width = size.width
        let height = size.height
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!
        
        context.clip(to: bounds, mask: maskImage)
        context.setFillColor(color.cgColor)
        context.fill(bounds)
        
        if let cgImage = context.makeImage() {
            let coloredImage = UIImage(cgImage: cgImage)
            return coloredImage
        } else {
            return nil
        }
    }
    
}
