//
//  ViewController.swift
//  FeedPlayer
//
//  Created by aboelbisher.176@gmail.com on 07/08/2018.
//  Copyright (c) 2018 aboelbisher.176@gmail.com. All rights reserved.
//

import UIKit
import AVKit

extension Int
{
    func mod(_ n : Int) -> Int
    {
        let r = self % n
        return r >= 0 ? r : r + n
    }
}

class ViewController: UIViewController
{
    
    let arr = [("https://djv923km0vre4.cloudfront.net/v1_processed_EFB6B787-10FB-4F33-A43D-40E23BB6193E_1530991938382_59e0adfc33c76f2e2cf40038.mp4", 72),
               ("https://djv923km0vre4.cloudfront.net/v1_processed_78F9BA4C-2B4B-477D-B47F-9710721EEB56_1530961033134_59e0adfc33c76f2e2cf40038.mp4" , 93) ,
               ("https://djv923km0vre4.cloudfront.net/v1_processed_DCA5C5A2-221D-4FE4-BCCA-3EC0030E588F_1530790077587_59e0adfc33c76f2e2cf40038.mp4", 96) ,
               ("https://djv923km0vre4.cloudfront.net/v1_processed_84984F07-EF3D-4B18-97FD-6F39A53FDFC1_1530729479669_59e0adfc33c76f2e2cf40038.mp4" , 98)]
    
    private var holderView : UIView!
    private var videoLayer : AVPlayerLayer!
    
    private var player : FeedPlayer!
    
    private var playPauseBtn : UIButton!
    private var prevBtn : UIButton!
    private var nextBtn : UIButton!
    
    private var index = 0
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        
        let options = FeedPlayer.Options(maxDiskStorageSpace: 500 * 1024 * 1024, removeUnusedFileAge: -7 * 24 * 60 * 60)
        self.player = FeedPlayer(options: options)
        for mem in arr
        {
            self.player.addObjectToPlay(signedUrl: mem.0, forId: mem.0, duration: mem.1)
        }
        
        
        self.initSubViews()
        
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    private func initSubViews()
    {
        self.initPlayerLayer()
        self.initBtns()
    }
    
    
    private func initPlayerLayer()
    {
        self.holderView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.width))
        self.view.addSubview(self.holderView)
        self.holderView.backgroundColor = .yellow
        
        self.videoLayer = AVPlayerLayer()
        self.videoLayer.frame = self.holderView.frame
        self.holderView.layer.addSublayer(self.videoLayer)
        
        
    }
    
    private func initBtns()
    {
        let size = CGSize(width: 50, height: 50)
        
        self.playPauseBtn = UIButton(frame: CGRect(x: self.view.bounds.width / 2 - size.width / 2 ,
                                                   y: self.holderView.frame.origin.y + self.holderView.frame.height + CGFloat(15),
                                                   width: size.width, height: size.height))
        self.view.addSubview(self.playPauseBtn)
        self.playPauseBtn.setTitle("play", for: .normal)
        self.playPauseBtn.setTitle("pause", for: .selected)
        self.playPauseBtn.setTitleColor(.black, for: .normal)
        self.playPauseBtn.setTitleColor(.black, for: .selected)
        self.playPauseBtn.addTarget(self, action: #selector(self.playBtnClicked(sender:)), for: .touchUpInside)
        
        
        self.prevBtn = UIButton(frame: CGRect(x: CGFloat(10), y: self.playPauseBtn.frame.origin.y,
                                              width: size.width, height: size.height))
        self.view.addSubview(self.prevBtn)
        self.prevBtn.setTitleColor(.black, for: .normal)
        self.prevBtn.setTitle("<", for: .normal)
        self.prevBtn.addTarget(self, action: #selector(self.prevBtnClicked(sender:)), for: .touchUpInside)
        
        
        self.nextBtn = UIButton(frame: CGRect(x: self.view.bounds.width - self.playPauseBtn.frame.width - CGFloat(10), y: self.playPauseBtn.frame.origin.y,
                                              width: size.width, height: size.height))
        self.view.addSubview(self.nextBtn)
        self.nextBtn.setTitleColor(.black, for: .normal)
        self.nextBtn.setTitle(">", for: .normal)
        self.nextBtn.addTarget(self, action: #selector(self.nextBtnClicked(sender:)), for: .touchUpInside)
        
    }
    
    
    @objc func playBtnClicked(sender: UIButton)
    {
        if sender.isSelected
        {
            self.player.pause()
        }
        else
        {
            self.playCurrentObject()
        }
        
        sender.isSelected = !sender.isSelected
    }
    
    private func playCurrentObject()
    {
        let object = self.arr[self.index]
        self.player.playFileWith(id: object.0)
        self.videoLayer.player = self.player.currentPlayer
    }
    
    @objc func nextBtnClicked(sender : UIButton)
    {
        self.index = (self.index + 1).mod(self.arr.count)
        self.playCurrentObject()
    }
    
    
    @objc func prevBtnClicked(sender : UIButton)
    {
        self.index = (self.index - 1).mod(self.arr.count)
        self.playCurrentObject()
    }
    
    
    
}
