/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-12-19 22:48:02
 */

/**
 * Copyright (C) 2009  Lance Fetters (aka. ashikase)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#import "FavoritesController.h"

#import <QuartzCore/CALayer.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconBadge.h>
#import <SpringBoard/SBIconModel.h>

#import "SpringBoardHooks.h"
#import "TaskListCell.h"


@implementation FavoritesController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Setup tab bar button
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"Favorites" image:[UIImage imageNamed:@"Kirikae_Favorites.png"] tag:1];
        self.tabBarItem = item;
        [item release];

        // Preferences may have changed since last read; synchronize
        CFPreferencesAppSynchronize(CFSTR(APP_ID));

        // Read favorites from preferences
        CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("favorites"), CFSTR(APP_ID));
        if (propList) {
            if (CFGetTypeID(propList) == CFArrayGetTypeID()) {
                favorites = [[NSMutableArray alloc] init];

                SBApplicationController *appCont = [objc_getClass("SBApplicationController") sharedInstance];
                for (NSString *displayId in (NSArray *)propList) {
                    // Check that favorite still exists, add to list if it does
                    SBApplication *app = [appCont applicationWithDisplayIdentifier:displayId];
                    if (app)
                        // Favorite exists
                        [favorites addObject:displayId];
                }

                if ([favorites count] != [(NSArray *)propList count]) {
                    // Some favorites were missing; update  preferences file
                    CFPreferencesSetAppValue(CFSTR("favorites"), favorites, CFSTR(APP_ID));
                    CFPreferencesAppSynchronize(CFSTR(APP_ID));
                }
            }

            CFRelease(propList);
        }

        // Determine the row height and badge padding to use
        BOOL useLargeRows = YES;
        propList = CFPreferencesCopyAppValue(CFSTR("useLargeRows"), CFSTR(APP_ID));
        if (propList) {
            if (CFGetTypeID(propList) == CFBooleanGetTypeID())
                useLargeRows = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
            CFRelease(propList);
        }
        if (useLargeRows) {
            rowHeight = 60.0f;
            badgePadding = 8.0f;
        } else {
            rowHeight = 44.0f;
            badgePadding = 4.0f;
        }

        // Determine whether to use themed or unthemed icons
        useThemedIcons = YES;
        propList = CFPreferencesCopyAppValue(CFSTR("useThemedIcons"), CFSTR(APP_ID));
        if (propList) {
            if (CFGetTypeID(propList) == CFBooleanGetTypeID())
                useThemedIcons = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
            CFRelease(propList);
        }
    }
    return self;
}

- (void)dealloc
{
    [favorites release];
    [super dealloc];
}

- (void)loadView
{
    [super loadView];

    if ([favorites count] == 0) {
        // No favorites
        [self.tableView setHidden:YES];

        // Create a notice to inform use how to add favorites
        // FIXME: Try to find a simpler/cleaner way to implement this
        //        ... or, consider making this dialog into a separate class
        UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
        self.view = view;
        [view release];

        view = [[UIView alloc] initWithFrame:CGRectMake(40.0f, 110.0f, 240.0f, 180.0f)];
        [view setBackgroundColor:[UIColor colorWithWhite:0.13f alpha:1.0f]];
        [view.layer setCornerRadius:10.0f];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 10.0f, view.bounds.size.width - 20.0f, 21.0f)];
        label.text = @"No Favorites";
        label.font = [UIFont boldSystemFontOfSize:17.0f];
        label.textAlignment = UITextAlignmentCenter;
        label.textColor = [UIColor whiteColor];
        label.backgroundColor = [UIColor clearColor];
        [view addSubview:label];
        [label release];

        UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(10.0f, 31.0f, view.bounds.size.width - 20.0f, 105.0f)];
        textView.text = @"Applications can be added to the list of favorites via the Kirikae preferences application.";
        textView.font = [UIFont systemFontOfSize:16.0f];
        textView.textAlignment = UITextAlignmentCenter;
        textView.textColor = [UIColor whiteColor];
        textView.backgroundColor = [UIColor clearColor];
        [textView setScrollEnabled:NO];
        [view addSubview:textView];
        [textView release];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        btn.frame = CGRectMake(20.0f, view.bounds.size.height - 47.0f, view.bounds.size.width - 40.0f, 37.0f);
        btn.backgroundColor = [UIColor clearColor];
        [btn setTitle:@"Open Preferences..." forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(openPreferences:) forControlEvents:UIControlEventTouchUpInside];
        [view addSubview:btn];

        [self.view addSubview:view];
        [view release];
    }
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    return @"Favorites";
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return [favorites count];
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    float height = rowHeight;

    // Get the icon for this application
    NSString *identifier = [favorites objectAtIndex:indexPath.row];
    SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
    SBApplicationIcon *icon = [iconModel iconForDisplayIdentifier:identifier];
    if (!icon) {
        // Application may have multiple roles; try again with default role
        SBApplicationController *appCont = [objc_getClass("SBApplicationController") sharedInstance];
        SBApplication *app = [appCont applicationWithDisplayIdentifier:identifier];
        icon = [iconModel iconForDisplayIdentifier:[NSString stringWithFormat:@"%@-%@", identifier, [app roleIdentifier]]];
    }
    if (MSHookIvar<SBIconBadge *>(icon, "_badge"))
        // Make room for badge icon
        height += badgePadding;

    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"TaskMenuCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    TaskListCell *cell = (TaskListCell *)[tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[TaskListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier] autorelease];
        [cell setSelectionStyle:UITableViewCellSelectionStyleGray];
    }

    // Get the display identifier of the application for this cell
    NSString *identifier = [favorites objectAtIndex:indexPath.row];

    // Get the application icon object
    SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
    SBApplicationIcon *icon = [iconModel iconForDisplayIdentifier:identifier];
    if (!icon) {
        // Application may have multiple roles; try again with default role
        // FIXME: This check is being done twice (also in height check)
        SBApplicationController *appCont = [objc_getClass("SBApplicationController") sharedInstance];
        SBApplication *app = [appCont applicationWithDisplayIdentifier:identifier];
        icon = [iconModel iconForDisplayIdentifier:[NSString stringWithFormat:@"%@-%@", identifier, [app roleIdentifier]]];
    }

    if (icon) {
        // Set the cell's text to the name of the application
        cell.textLabel.text = [icon displayName];

        // Set the cell's image to the application's icon image
        UIImage *image = nil;
        if (useThemedIcons) {
            image = [icon icon];
        } else {
            SBApplication *app = [icon application];
            NSString *bundlePath = [app path];
            NSString *roleId = [app roleIdentifier];
            if (roleId != nil) {
                // NOTE: Should only be true for iPod/Video/Audio and Camera/Photos
                image = [UIImage imageWithContentsOfFile:
                    [NSString stringWithFormat:@"%@/icon-%@.png", bundlePath, roleId]];
            } else {
                // First try with uppercase filename
                image = [UIImage imageWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"Icon.png"]];
                if (image == nil)
                    // Try again with lowercase filename
                    image = [UIImage imageWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"icon.png"]];
            }
        }
        cell.iconImage = image;

        // Set the cell's badge image (if applicable)
        SBIconBadge *&badge = MSHookIvar<SBIconBadge *>(icon, "_badge");
        if (badge) {
            UIGraphicsBeginImageContext(badge.frame.size);
            [badge.layer renderInContext:UIGraphicsGetCurrentContext()];
            cell.badgeImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
    }
    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Switch to selected application
    [(SpringBoard *)UIApp switchToAppWithDisplayIdentifier:[favorites objectAtIndex:indexPath.row]];
}

#pragma mark - Actions

- (void)openPreferences:(id)sender
{
    // Switch to the Kirikae preferences application
    [(SpringBoard *)UIApp switchToAppWithDisplayIdentifier:@APP_ID];
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
