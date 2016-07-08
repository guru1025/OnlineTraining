//
//  MAVOutgoingFileTransferTableViewCell.m
//  RCS
//
//  Created by Igor Bremec on 3.7.2013..
//  Copyright (c) 2013. Mavenir Systems. All rights reserved.
//

#import "MAVOutgoingFileTransferTableViewCell.h"
#import "MAVFileTransfer.h"
#import "UIImage+ImageEffects.h"
#import <AVFoundation/AVFoundation.h>


#define kMessageBubbleLongPressDuration 0.75;
#define kMessageBubbleSelectedOverlayAlpha 0.25
#define kCellHeight 302.0

@interface MAVOutgoingFileTransferTableViewCell ()
{
  NSString *_currentFileURL;
  UILongPressGestureRecognizer *_longPressRecognizer;
  IBOutlet NSLayoutConstraint *_thumbnailImageViewWidthConstraint;
  CGFloat _thumbnailImageViewWidthConstraintDefaultConstant;
}

@end

@implementation MAVOutgoingFileTransferTableViewCell
-(void)initGestureRecognizerWithLongPressReceiver:(UIView*)longPressReceiver
{
  self.longPressTargetView = longPressReceiver;
  if (self.longPressTargetView)
  {
    if (_longPressRecognizer)
    {
      [self.longPressTargetView removeGestureRecognizer:_longPressRecognizer];
    }
    
    // Add long press gesture recognizer to the message bubble view
    _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestureRecognizerAction:)];
    _longPressRecognizer.minimumPressDuration = kMessageBubbleLongPressDuration;
    [self.longPressTargetView addGestureRecognizer:_longPressRecognizer];
  }
}


+(NSString *)getReuseIdentifier
{
  return @"outgoingFileTransferCell";
}

+(CGFloat)cellHeightForMessage:(MAVMessage *)message inTableView:(UITableView *)tableView
{
  if (message.messageTypeValue == MAVMessageTypeContact)
  {
    return 120;
  }
  else
  {
    return kCellHeight;
  }
}

-(void)awakeFromNib
{
  [super awakeFromNib];
  
  _thumbnailImageViewWidthConstraintDefaultConstant = _thumbnailImageViewWidthConstraint.constant;
  
  //  self.thumbnailImageView.layer.borderColor = self.thumbnailImageView.backgroundColor.CGColor;
  self.thumbnailImageView.userInteractionEnabled = YES;
  
  UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(thumbnailTapped)];
  [self.thumbnailImageView addGestureRecognizer:tapGesture];
  
  // Listen for updates to MAVFileTransfer objects
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(fileTransferManagedObjectUpdated:)
                                               name:kMAVFileTransferUpdated
                                             object:nil];
  
  [self initGestureRecognizerWithLongPressReceiver:self.thumbnailImageView];
}

-(void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)prepareForReuse
{
  [super prepareForReuse];
  _currentFileURL = nil;
  // Reset some UI elements
  _thumbnailImageView.image = nil;
  [self.progressView setValue:0 animateWithDuration:0];
  
}

-(BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  if(action == @selector(ACTION_COPY) && (self.message.messageTypeValue != MAVMessageTypeFax))
    return NO;
  else if(action == @selector(ACTION_RETRY))
    return NO;
  else if(action == @selector(ACTION_DELETE))
    return YES;
  else
    return NO;
}

-(void)refresh:(BOOL)animated
{
  if (self.message.messageTypeValue == MAVMessageTypeContact)
  {
    _thumbnailImageViewWidthConstraint.constant = 100.0;
  }
  else
  {
    _thumbnailImageViewWidthConstraint.constant = _thumbnailImageViewWidthConstraintDefaultConstant;
  }
    if (self.message.messageTypeValue == MAVMessageTypeVideo)
    {
        self.videoPlayButton.hidden = false;
    }
    else {
        self.videoPlayButton.hidden = true;

    }
  self.progressView.hidden = NO;
  self.progressView.layer.borderColor = [UIColor colorWithRed:226.0/255.0 green:0.0/255.0 blue:116.0/255.0 alpha:1.0].CGColor;
  self.progressView.layer.borderWidth = 2;
  self.progressView.layer.cornerRadius = 34;
  self.progressView.backgroundColor = [UIColor whiteColor];
  
  self.timeLabel.text = [self formatTimestamp:self.message.timestamp];
  
  MAVFileTransfer *fileTransfer = self.message.fileTransfer;
  self.backgroundImageBubble.image = [[UIImage imageNamed:@"MessageBubbleOutgoing.png"] resizableImageWithCapInsets: UIEdgeInsetsMake(17, 18, 18, 24)];
  
  if(self.message.messageTypeValue == MAVMessageTypeFax){
    
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)[NSURL URLWithString:self.message.fileUrl]);
    CGPDFPageRef page = CGPDFDocumentGetPage(pdf, 1);
    CGRect aRect = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
    UIGraphicsBeginImageContext(aRect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0.0, aRect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, -(aRect.origin.x), -(aRect.origin.y));
    
    CGContextSetGrayFillColor(context, 1.0, 1.0);
    CGContextFillRect(context, aRect);
    
    CGAffineTransform pdfTransform = CGPDFPageGetDrawingTransform(page, kCGPDFCropBox, aRect, 0, false);
    CGContextConcatCTM(context, pdfTransform);
    CGContextDrawPDFPage(context, page);
    
    UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
    
    if(thumbnail != nil){
      _thumbnailImageView.image = thumbnail;
      _currentFileURL = self.message.fileUrl;
      
    }
    else {
      _thumbnailImageView.image = [UIImage imageNamed:@"MessageFaxThumbnail"];
      _currentFileURL = self.message.fileUrl;
      
      
    }
    
    
    CGContextRestoreGState(context);
    UIGraphicsEndImageContext();
    CGPDFDocumentRelease(pdf);
    
    
  }
  else
  {
    // Set thumbnail image
    if (![fileTransfer.fileUrl isEqual:_currentFileURL])
    {
      _currentFileURL = fileTransfer.fileUrl;
      
      [fileTransfer thumbnail:^(UIImage *image) {
        dispatch_async(dispatch_get_main_queue(), ^{
          
          if (image)
          {
            _thumbnailImageView.image = image;

            _thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
            //[self createMaskedImageFrom:image];
//              if(self.message.messageTypeValue == MAVMessageTypeVideo)
//              {
//                  //UIImage *playImage = [UIImage imageNamed:@"videoPlayButton"];
//                  _thumbnailImageView.image = image;//[self drawImage:playImage inImage:image];
//
//              }
          }
          else if(self.message.messageTypeValue == MAVMessageTypeVideo)
          {
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[fileTransfer.fileName lastPathComponent]]])
            {
              _currentFileURL =[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[fileTransfer.fileName lastPathComponent]];
              
              
            }
            else
            {
              NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
              _currentFileURL =[[paths objectAtIndex:0] stringByAppendingPathComponent: fileTransfer.fileUrl];
              
            }

//            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//            _currentFileURL =[[paths objectAtIndex:0] stringByAppendingPathComponent: fileTransfer.fileUrl];
            
            NSURL *videoURL = [NSURL fileURLWithPath:_currentFileURL];// filepath is your video file path
            
            
            
            AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
            AVAssetImageGenerator *generateImg = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            NSError *error = NULL;
            CMTime time = CMTimeMake(1, 1);
            CGImageRef refImg = [generateImg copyCGImageAtTime:time actualTime:NULL error:&error];
            NSLog(@"error==%@, Refimage==%@", error, refImg);
            
            UIImage *FrameImage= [[UIImage alloc] initWithCGImage:refImg];
            _thumbnailImageView.image = FrameImage;
             // UIImage *playImage = [UIImage imageNamed:@"videoPlayButton"];
              //_thumbnailImageView.image = [self drawImage:playImage inImage:FrameImage];
          }
          else if ((self.message.messageTypeValue == MAVMessageTypeImage) && ([[NSFileManager defaultManager]fileExistsAtPath:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[fileTransfer.fileUrl lastPathComponent]]]))
          {
            _thumbnailImageView.image = [UIImage imageWithContentsOfFile:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[fileTransfer.fileUrl lastPathComponent]]];
            _thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
          }
          else if (self.message.messageTypeValue == MAVMessageTypeContact)
          {
              _thumbnailImageView.image = [UIImage imageNamed:@"vcard.png"];
              _thumbnailImageView.contentMode = UIViewContentModeCenter;
          }
          else if (self.message.messageTypeValue == MAVMessageTypeFile)
          {
            CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)[[NSURL alloc]initFileURLWithPath:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[fileTransfer.fileUrl lastPathComponent]]]);
            NSLog(@"urlx:%@", self.message.fileUrl);
            CGPDFPageRef page = CGPDFDocumentGetPage(pdf, 1);
            CGRect aRect = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
            UIGraphicsBeginImageContext(aRect.size);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, 0.0, aRect.size.height);
            CGContextScaleCTM(context, 1.0, -1.0);
            CGContextTranslateCTM(context, -(aRect.origin.x), -(aRect.origin.y));
            
            CGContextSetGrayFillColor(context, 1.0, 1.0);
            CGContextFillRect(context, aRect);
            
            CGAffineTransform pdfTransform = CGPDFPageGetDrawingTransform(page, kCGPDFCropBox, aRect, 0, false);
            CGContextConcatCTM(context, pdfTransform);
            CGContextDrawPDFPage(context, page);
            
            UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
            
            
            if(thumbnail != nil){
              _thumbnailImageView.image = thumbnail;
              _currentFileURL = self.message.fileUrl;
              
            }
            else {
              _thumbnailImageView.image = [UIImage imageNamed:@"MessageFaxThumbnail"];
              _currentFileURL = self.message.fileUrl;
              
              
            }
            
            
            CGContextRestoreGState(context);
            UIGraphicsEndImageContext();
            CGPDFDocumentRelease(pdf);
            
          }
          else
          {
            _thumbnailImageView.image = [fileTransfer defaultThumbnail];
            _thumbnailImageView.contentMode = UIViewContentModeCenter;
            //[self createMaskedImageFrom:[fileTransfer defaultThumbnail]];
          }
          
        });
      }];
    }
  }
  // <filename> (<filesize>)
  //_filenameLabel.text = [NSString stringWithFormat:@"%@ (%@)", fileTransfer.fileName, [fileTransfer formattedFileSize]];
  
  // Set view based on transfer status
  MAVFileTransferStatusType status = [fileTransfer.status intValue];
  float percent = [fileTransfer.bytesTransfered floatValue] / [fileTransfer.fileSize floatValue];
  
  switch (status)
  {
    case MAVFileTransferNotStarted:
      _transferStatusLabel.text = @"";
      break;
      
    case MAVFileTransferInProgress:
      
      if ([self.message.messageType isEqual:@(MAVMessageTypeFax)] )
      {
        _transferStatusLabel.text = @"Sending in Progress";
        
      }
      else
      {
        [self.progressView setValue:percent * 100 animateWithDuration:1];
        
        _transferStatusLabel.text = [NSString stringWithFormat:@"%.f%%", percent * 100];
      }
      break;
      
    case MAVFileTransferRejected:
      _transferStatusLabel.text = @"Rejected by recipient.";
      break;
      
    case MAVFileTransferCanceledBySender:
      _transferStatusLabel.text = @"Canceled by sender.";
      break;
      
    case MAVFileTransferCanceledByRecipient:
      _transferStatusLabel.text = @"Canceled by recipient.";
      break;
      
    case MAVFileTransferFailed:
      _transferStatusLabel.text = @"Failed.";
      break;
      
    case MAVFileTransferComplete:
      _transferStatusLabel.text = @"Delivered"; // Tick will be displayed instead
      break;
  }


  if (self.message.deliveryStatusValue == MAVMessageDeliveryStatusRead)
  {
     _transferStatusLabel.text = @"Seen";
  }
  if ([self.message.messageType isEqual:@(MAVMessageTypeFax)] )
  {
    _cancelButton.hidden = YES;
    
  }
  else
  {
    _cancelButton.hidden = (status != MAVFileTransferNotStarted && status != MAVFileTransferInProgress);
    
  }
  //  _cancelButton.hidden = (status != MAVFileTransferNotStarted && status != MAVFileTransferInProgress);
  _retryButton.hidden = (status != MAVFileTransferFailed);
  if(status == MAVFileTransferCanceledBySender) _retryButton.hidden = false;
  
  if([fileTransfer.errorCode  isEqual: @13]){
    _retryButton.hidden = true;
    _transferStatusLabel.text = @"File is too big.";
    
  }
  _transferCompleteImageView.hidden = true;// (status != MAVFileTransferComplete);
  //_transferProgressView.hidden = (status != MAVFileTransferInProgress);
  self.progressView.hidden = (status != MAVFileTransferInProgress);
  self.messageBubbleArrow.hidden = !self.isFirstMessageInAuthorGroup;
}


#pragma mark - Private methods
//creates mask then applies it to image
-(void)createMaskedImageFrom:(UIImage *)origImage{
  UIImage *bubbleMask = [[UIImage imageNamed:@"BubbleMaskOutgoing"] resizableImageWithCapInsets: UIEdgeInsetsMake(18, 19, 17, 23)];
  
  
  //CGSize newSize = CGSizeMake(floorf(origImage.size.width), floorf(origImage.size.height));
  
  CGSize newSize = CGSizeMake(self.thumbnailImageView.frame.size.width, self.thumbnailImageView.frame.size.height);
  
  UIImage *newMaskImage = [UIImage maskImageFromImage:bubbleMask withSize:newSize];
  self.thumbnailImageView.image = [UIImage applyMask:newMaskImage toImage:origImage];
  //self.thumbnailImageView.image = newMaskImage;
}


#pragma mark - Event handlers

-(IBAction)cancelButtonPressed:(id)sender
{
  if([self.delegate respondsToSelector:@selector(outgoingFileTransferCancelButtonPressed:)])
  {
    [self.delegate outgoingFileTransferCancelButtonPressed:self];
  }
}

-(IBAction)retryButtonPressed:(id)sender
{
  if([self.delegate respondsToSelector:@selector(outgoingFileTransferRetryButtonPressed:)])
  {
    [self.delegate outgoingFileTransferRetryButtonPressed:self];
  }
}
- (IBAction)playVideo:(id)sender {
    [self thumbnailTapped];
}

-(void)thumbnailTapped
{
  if([self.delegate respondsToSelector:@selector(outgoingFileTransferThumbnailTapped:)])
  {
    [self.delegate outgoingFileTransferThumbnailTapped:self];
  }
}

#pragma mark - MAVFileTransferUpdated notification handler

-(void)fileTransferManagedObjectUpdated:(NSNotification *)notification
{
  NSParameterAssert([NSThread isMainThread]);
  
  MAVFileTransferID *fileTransferID = notification.userInfo[kMAVFileTransferUpdatedTransferIDKey];
  
  if ([self.message.fileTransfer.objectID isEqual:fileTransferID])
  {
    [self refresh:NO];
  }
  else if ([self.message.messageType isEqual:@(MAVMessageTypeFax)] )
  {
    [self refresh:NO];
    
  }
  
}
-(void)setActionMenuVisible:(BOOL)visible animated:(BOOL)animated
{
  NSParameterAssert(self.longPressTargetView);
  self.messageBubbleSelected = visible;
  
  UIMenuItem *copyItem =   [[UIMenuItem alloc] initWithTitle:@"Copy"   action:@selector(ACTION_COPY)]; //copyMessage implemented in base class
  UIMenuItem *deleteItem = [[UIMenuItem alloc] initWithTitle:@"Delete" action:@selector(ACTION_DELETE)]; //deleteMessage implemented in base class
  
  UIMenuController *menuController = [UIMenuController sharedMenuController];
  menuController.menuItems = @[copyItem, deleteItem];
  
  CGRect targetRect = [self.longPressTargetView.superview convertRect:self.longPressTargetView.frame toView:self];
  [menuController setTargetRect:targetRect inView:self];
  [menuController setMenuVisible:visible animated:animated];
}
-(void)handleLongPressGestureRecognizerAction:(UILongPressGestureRecognizer *)recognizer
{
  if (recognizer.state == UIGestureRecognizerStateBegan)
  {
    if ([self.delegate respondsToSelector:@selector(cellDidReceiveLongPress:)])
    {
      [self.delegate cellDidReceiveLongPress:self];
    }
  }
}

// Menu controller action method
-(void)copyMessage
{
  [UIPasteboard generalPasteboard].string = self.message.fileTransfer.fileUrl;
  //[UIPasteboard pasteboardWithName:@"myPasteboard" create:YES].string = self.message.fileTransfer.fileUrl;
  // NSString *xdd = self.message.fileTransfer.fileUrl;
  // [UIPasteboard generalPasteboard].items = [NSArray arrayWithObjects:xdd, nil];
  
}
-(void)setEditing:(BOOL)editing animated:(BOOL)animated
{
  [super setEditing:editing animated:animated];
  
  // Remove the long-press gesture recognizer from the message bubble view when
  // the cell is in edit mode. This will prevent weird behaviour when the user
  // long-presses the cell in edit mode.
  if (editing)
  {
    [self.longPressTargetView removeGestureRecognizer:_longPressRecognizer];
  }
  else if (![self.messageBubble.gestureRecognizers containsObject:_longPressRecognizer])
  {
    [self.longPressTargetView addGestureRecognizer:_longPressRecognizer];
  }
}
@end
