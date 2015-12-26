//
//  ViewController.swift
//  Leveler
//
//  Created by Frederico Schnekenberg on 19/10/15.
//  Copyright (c) 2015 Frederico Schnekenberg. All rights reserved.
//

import UIKit
import CoreMotion

class ViewController: UIViewController
{
    // MARK: --- Properties ---
    let handImageName = "hand"
    let accelerometerPollingInterval: NSTimeInterval = 1.0/1.5
    
    let springAnchorDistance: CGFloat = 4.0
    let springDamping: CGFloat = 0.7
    let springFrequency: CGFloat = 0.5
    
    var dialView: DialView!
    var needleView: UIImageView!
    
    var animator: UIDynamicAnimator!
    var springBehavior: UIAttachmentBehavior?
    
    lazy var motionManager = CMMotionManager()
    /*  Caution: Never create more than one instance of CMMotionManager!
        If needed, share a single instance!
        lazy vars are automatically initialized, but instead of
        being initialized when the VC object is created, it 
        waits until requested
    */
    
    // MARK: --- IBOutlets ---
    @IBOutlet weak var angleLabel: UILabel!
    
    // MARK: --- VC Lifecycle ---
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // create dial image view
        dialView = DialView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.addSubview(dialView)
        
        // create needle image view
        needleView = UIImageView(image: UIImage(named: handImageName))
        needleView.contentMode = UIViewContentMode.ScaleAspectFit
        view.insertSubview(needleView, aboveSubview: dialView)
        
        adaptInterface()
    }
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        
        // position the dial view
        positionDialViews()
        attachDialBehaviors()
        
        // configure the motion manager to report accelerometer changes
        motionManager.accelerometerUpdateInterval = accelerometerPollingInterval
        
        // tell the motion manager to begin collecting data
        motionManager.startAccelerometerUpdates()
        
        // start a timer to periodically poll the accelerometer
        NSTimer.scheduledTimerWithTimeInterval(
            accelerometerPollingInterval,
            target: self,
            selector: "updateAccelerometerTime:",
            userInfo: nil,
            repeats: true
        )
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator)
    {
        coordinator.animateAlongsideTransition(
            { (context) -> Void in
                self.positionDialViews()
            },
            completion: { (context) in
                self.attachDialBehaviors()
            }
        )
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
    
    override func supportedInterfaceOrientations() -> Int
    {
        return Int(UIInterfaceOrientationMask.All.rawValue)
    }
    
    // MARK: --- Utility Methods ---
    func adaptInterface()
    {
        if let label = angleLabel {
            var fontSize: CGFloat = 90.0
            if traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.Compact {
                fontSize = 60.0
            }
            label.font = UIFont.systemFontOfSize(fontSize)
        }
    }
    
    func positionDialViews()
    {
        let viewBounds = view.bounds
        let labelFrame = angleLabel.frame
        let topEdge = ceil(labelFrame.maxY + labelFrame.height / 3.0)
        let dialRadius = viewBounds.maxY - topEdge
        let dialHeight = dialRadius * 2.0
        
        dialView.frame = CGRect(x: 0.0, y: 0.0, width: dialHeight, height: dialHeight)
        dialView.center = CGPoint(x: viewBounds.midX, y: viewBounds.maxY)
        
        let needleSize = needleView.image?.size
        let needleScale = dialRadius / needleSize!.height
        var needleFrame = CGRect(x: 0.0, y: 0.0, width: needleSize!.width * needleScale, height: needleSize!.height * needleScale)
        
        needleFrame.origin.x = viewBounds.midX - needleFrame.width / 2.0
        needleFrame.origin.y = viewBounds.maxY - needleFrame.height
        needleView.frame = CGRectIntegral(needleFrame)
    }
    
    func attachDialBehaviors()
    {
        // lazily create or reset the dynamic behavior
        if animator != nil {
            animator.removeAllBehaviors()
        }
        else {
            animator = UIDynamicAnimator(referenceView: view)
        }
        
        // pin the center of the dial at tis current center
        let dialCenter = dialView.center
        let pinBehavior = UIAttachmentBehavior(item: dialView, attachedToAnchor: dialCenter)
        animator.addBehavior(pinBehavior)
        
        // create a springy attachment at the top-center point of the view
        let dialRect = dialView.frame
        let topCenter = CGPoint(x: dialRect.midX, y: dialRect.minY)
        let topOffset = UIOffset(horizontal: 0.0, vertical: topCenter.y - dialCenter.y)
        springBehavior = UIAttachmentBehavior(
            item: dialView,
            offsetFromCenter: topOffset,
            attachedToAnchor: topCenter
        )
        springBehavior!.damping = springDamping
        springBehavior!.frequency = springFrequency
        animator.addBehavior(springBehavior)
        
        // add some resistence to the dial
        let drag = UIDynamicItemBehavior(items: [dialView])
        drag.angularResistance = 2.0
        animator.addBehavior(drag)
    }
    
    // MARK: --- Accelerometer Methods ---
    func updateAccelerometerTime(timer: NSTimer)
    {
        if let data = motionManager.accelerometerData {
            let acceleration = data.acceleration
            let rotation = atan2(-acceleration.x, -acceleration.y)
            rotateDialView(rotation)
        }
    }
    
    func rotateDialView(rotation: Double)
    {
        // rotate the dial by the angle of "up"
        if let spring = springBehavior {
            // calculate the distance of the spring attachment point from the center of dialView
            let center = dialView.center
            let radius = dialView.frame.height / 2.0 + springAnchorDistance
            
            // combine with rotation to find the new attachment point
            let anchorPoint = CGPoint(
                x: center.x + CGFloat(sin(rotation)) * radius,
                y: center.y - CGFloat(cos(rotation)) * radius
            )
            
            // move the attachment point; the dynamic animator will do the rest
            spring.anchorPoint = anchorPoint
        }
        
        // convert radians to degrees, update the label
        var degrees = Int(round(-rotation * 180.0 / M_PI))
        if degrees < 0 {
            degrees += 360
        }
        angleLabel.text = "\(degrees)°"
    }
}

