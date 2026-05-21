// Adapted from YouPiP by PoomSmart
// Updated for YouTube 21.20.4 - removed dead hooks, fixed signatures
// TVHTML5 client spoofing via NSMutableURLRequest to obtain hlsManifestUrl

#import <Foundation/Foundation.h>
#import <YouTubeHeader/MLAVPlayer.h>
#import <YouTubeHeader/MLDefaultPlayerViewFactory.h>
#import <YouTubeHeader/MLHLSMasterPlaylist.h>
#import <YouTubeHeader/MLHLSStreamSelector.h>
#import <YouTubeHeader/MLPlayerPool.h>
#import <YouTubeHeader/MLPlayerPoolImpl.h>
#import <YouTubeHeader/MLVideoDecoderFactory.h>
#import <YouTubeHeader/YTHotConfig.h>
#import "Header.h"

extern BOOL FixPlayback();

@interface YTGLMediaPlayerViewFactory : NSObject
@end

static MLAVPlayer *makeAVPlayer(id self, MLVideo *video, MLInnerTubePlayerConfig *playerConfig, MLPlayerStickySettings *stickySettings) {
    BOOL externalPlaybackActive = [(MLAVPlayer *)[self valueForKey:@"_activePlayer"] externalPlaybackActive];
    MLAVPlayer *player = [[%c(MLAVPlayer) alloc] initWithVideo:video playerConfig:playerConfig stickySettings:stickySettings externalPlaybackActive:externalPlaybackActive];
    if (stickySettings)
        player.rate = stickySettings.rate;
    return player;
}

static void forceRenderViewTypeBase(YTIHamplayerConfig *hamplayerConfig) {
    if (!hamplayerConfig) return;
    hamplayerConfig.renderViewType = 2;
}

static void forceRenderViewTypeHot(YTIHamplayerHotConfig *hamplayerHotConfig) {
    if (!hamplayerHotConfig) return;
    hamplayerHotConfig.renderViewType = 2;
}

static void forceRenderViewType(YTHotConfig *hotConfig) {
    YTIHamplayerHotConfig *hamplayerHotConfig = [hotConfig hamplayerHotConfig];
    forceRenderViewTypeHot(hamplayerHotConfig);
}

%hook MLPlayerPoolImpl

// Only surviving signature in 21.20.4
- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings latencyLogger:(id)latencyLogger reloadContext:(id)reloadContext mediaPlayerResources:(id)mediaPlayerResources recompositeProvider:(id)recompositeProvider {
    return makeAVPlayer(self, video, playerConfig, stickySettings);
}

// Force renderViewType=2 into the config before the original factory reads it.
// The old approach used KVC @"_playerViewFactory" which returns nil in 21.20.4
// (ivar renamed), causing a nil view → "No stream" UI while AVPlayer buffered
// happily in the background. %orig with renderViewType already set returns the
// correct MLAVPlayerLayerView without any KVC.
- (id)playerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig mediaPlayerResources:(id)mediaPlayerResources {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

// Only surviving canQueuePlayerPlay signature in 21.20.4
- (BOOL)canQueuePlayerPlayVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig reloadContext:(id)reloadContext error:(NSError **)error {
    return NO;
}

- (BOOL)canUsePlayerView:(id)playerView forPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

%end

%hook MLPlayerPool

// Only surviving signature in 21.20.4
- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings latencyLogger:(id)latencyLogger reloadContext:(id)reloadContext mediaPlayerResources:(id)mediaPlayerResources recompositeProvider:(id)recompositeProvider {
    return makeAVPlayer(self, video, playerConfig, stickySettings);
}

// Same fix as MLPlayerPoolImpl above — force renderViewType=2 then %orig.
- (id)playerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig mediaPlayerResources:(id)mediaPlayerResources {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (BOOL)canUsePlayerView:(id)playerView forVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (BOOL)canQueuePlayerPlayVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig reloadContext:(id)reloadContext error:(NSError **)error {
    return NO;
}

%end

%hook MLDefaultPlayerViewFactory

- (id)hamPlayerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewType([self valueForKey:@"_hotConfig"]);
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (id)hamPlayerViewForPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewType([self valueForKey:@"_hotConfig"]);
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (id)AVPlayerViewForPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewType([self valueForKey:@"_hotConfig"]);
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (BOOL)canUsePlayerView:(id)playerView forVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (BOOL)canUsePlayerView:(id)playerView forPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

%end

%hook MLVideoDecoderFactory

- (void)prepareDecoderForFormatDescription:(id)formatDescription delegateQueue:(id)delegateQueue {
    forceRenderViewTypeHot([self valueForKey:@"_hotConfig"]);
    %orig;
}

- (void)prepareDecoderForFormatDescription:(id)formatDescription setPixelBufferTypeOnlyIfEmpty:(BOOL)setPixelBufferTypeOnlyIfEmpty delegateQueue:(id)delegateQueue {
    forceRenderViewTypeHot([self valueForKey:@"_hotConfig"]);
    %orig;
}

%end

%hook YTGLMediaPlayerViewFactory

- (BOOL)canUsePlayerView:(id)playerView forPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (id)hamPlayerViewForPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewType([self valueForKey:@"_hotConfig"]);
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (id)AVPlayerViewForPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewType([self valueForKey:@"_hotConfig"]);
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (id)viewForPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewType([self valueForKey:@"_hotConfig"]);
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

%end

// ---------------------------------------------------------------------------
// Client type spoofing: IOS → WEB (web_safari)
//
// Problem: IOS client responses contain only DASH streams which require a
// PO Token for GVS (CDN) access. Sideloaded apps cannot obtain a valid PO
// Token because iOSGuard/DeviceCheck/AppAttest reject the wrong Team ID.
//
// Solution: spoof as the WEB client with a Safari user-agent (yt-dlp calls
// this "web_safari"). This client:
//   1. Returns DASH adaptiveFormats  → satisfies YouTube's stream checker,
//      preventing the false Code=2 "No stream" error
//   2. Returns hlsManifestUrl        → AVPlayer uses HLS for actual playback
//   3. HLS GVS requests are PO Token-exempt for web_safari (per yt-dlp PO
//      Token Guide: "provides HLS formats which do not require PO Token for
//      GVS at this time")
//
// The body is JSON even though transport is QUIC (Cronet reads the
// NSMutableURLRequest body before handing it to the transport layer).
// ---------------------------------------------------------------------------

static NSData *spoofClientInBody(NSData *bodyData) {
    if (!bodyData || bodyData.length == 0) return bodyData;
    NSError *err = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:bodyData
                                               options:NSJSONReadingMutableContainers
                                                 error:&err];
    if (err || ![parsed isKindOfClass:[NSMutableDictionary class]]) return bodyData;
    NSMutableDictionary *body   = (NSMutableDictionary *)parsed;
    NSMutableDictionary *ctx    = body[@"context"];
    NSMutableDictionary *client = ctx[@"client"];
    if (![client isKindOfClass:[NSMutableDictionary class]]) return bodyData;
    if (![client[@"clientName"] isEqualToString:@"IOS"])     return bodyData;

    // web_safari context (from yt-dlp _base.py, INNERTUBE_CONTEXT_CLIENT_NAME=1)
    client[@"clientName"]    = @"WEB";
    client[@"clientVersion"] = @"2.20260114.08.00";
    client[@"userAgent"]     = @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                                "AppleWebKit/605.1.15 (KHTML, like Gecko) "
                                "Version/15.5 Safari/605.1.15,gzip(gfe)";
    // Remove iOS-only fields that would look inconsistent in a WEB context
    [client removeObjectForKey:@"deviceMake"];
    [client removeObjectForKey:@"deviceModel"];
    [client removeObjectForKey:@"osName"];
    [client removeObjectForKey:@"osVersion"];
    [client removeObjectForKey:@"deviceExperimentId"];

    NSData *result = [NSJSONSerialization dataWithJSONObject:body options:0 error:&err];
    return err ? bodyData : result;
}

%hook NSMutableURLRequest

- (void)setHTTPBody:(NSData *)data {
    if (data.length > 0 && [self.URL.path containsString:@"/youtubei/v1/player"]) {
        NSData *spoofed = spoofClientInBody(data);
        if (spoofed && spoofed != data) {
            [self setValue:@"1"                  forHTTPHeaderField:@"X-Youtube-Client-Name"];
            [self setValue:@"2.20260114.08.00"   forHTTPHeaderField:@"X-Youtube-Client-Version"];
            %orig(spoofed);
            return;
        }
    }
    %orig;
}

%end

// ---------------------------------------------------------------------------
// Suppress false "No stream" (Code=2) error
//
// When the TVHTML5 client spoof is active the player response has no DASH
// adaptiveFormats list. YouTube's player framework checks adaptiveFormats
// early in response processing, finds zero entries, generates:
//   NSError(domain="com.google.ios.youtube.ErrorDomain.playback", code=2)
// and calls -[YTMainAppVideoPlayerOverlayViewController handleError:].
//
// This happens BEFORE the HLS path runs, so the state machine enters the
// error branch and never calls [avPlayer play] — even though AVPlayer has
// already been handed hlsManifestUrl and is actively pre-buffering (proven
// by 7+ MB of 200-OK segment downloads visible in Proxyman).
//
// Suppressing Code=2 lets the state machine continue past the error branch
// and issue the play command against the already-buffered HLS content.
// ---------------------------------------------------------------------------
%hook YTMainAppVideoPlayerOverlayViewController
- (void)handleError:(NSError *)error {
    if (FixPlayback()
        && error.code == 2
        && [error.domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"])
        return;
    %orig;
}
%end

// ---------------------------------------------------------------------------
// HLS stream availability fix
//
// When the TVHTML5 spoof is active the player response has hlsManifestUrl
// but no DASH adaptiveFormats list. YouTube's stream-availability system
// normally learns about HLS tracks through:
//   -[MLHLSStreamSelector didLoadHLSMasterPlaylist:] → %delegate streamSelectorHasSelectableVideoFormats:
//
// The original YTUHD hook used KVC key @"_completeMasterPlaylist" which
// returns nil in 21.20.4 (ivar was renamed), so the delegate was called with
// an empty array → Code=2 "No stream" in the UI even though AVPlayer was
// buffering segments successfully in the background.
//
// Fix: arg1 IS the master playlist — use it directly, no KVC.
// ---------------------------------------------------------------------------
%hook MLHLSStreamSelector
- (void)didLoadHLSMasterPlaylist:(MLHLSMasterPlaylist *)playlist {
    %orig;
    NSArray *variants = [playlist remotePlaylists];
    if (variants.count > 0)
        [[self delegate] streamSelectorHasSelectableVideoFormats:variants];
}
%end

%ctor {
    if (!FixPlayback()) return;
    %init;
}
