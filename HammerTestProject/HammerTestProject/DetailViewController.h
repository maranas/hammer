//
//  DetailViewController.h
//  HammerTestProject
//
//  Created by Moises Anthony Aranas on 6/22/17.
//  Copyright © 2017 Moises Anthony Aranas. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) NSDate *detailItem;
@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end

