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
    
    let arr = [("https://www.sample-videos.com/video/mp4/240/big_buck_bunny_240p_5mb.mp4", 27),
               ("http://techslides.com/demos/sample-videos/small.mp4" , 5) ]
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
