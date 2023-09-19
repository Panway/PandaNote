//
//  UIImage+PPTool.swift
//  PandaNote
//
//  Created by Panway on 2020/5/6.
//  Copyright © 2020 Panway. All rights reserved.
//

import Foundation
extension UIImage {
    // 创建一个带有指定大小和颜色的圆形 UIImage
    static func pp_circleImage(withSize size: CGSize, color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        // 设置填充颜色
        color.setFill()
        
        // 创建圆形路径并填充
        let radius = min(size.width, size.height) / 2.0
        context.addArc(center: CGPoint(x: size.width / 2.0, y: size.height / 2.0), radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        context.fillPath()
        
        // 从当前上下文获取 UIImage
        let circleImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return circleImage
    }
    
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
    func maskWithColor(_ color: UIColor) -> UIImage? {
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
