// Adapted from YouPiP by PoomSmart
// Updated for YouTube 21.20.4 - removed dead hooks, fixed signatures
//
// Root cause (confirmed via HAR + binary analysis):
//
// 1. makeAVPlayer() was creating MLAVPlayer WITHOUT mediaPlayerResources /
//    recompositeProvider → player never loaded a URL → Code=2 immediately.
//    Fix: set renderViewType=2 then call %orig so the pool creates a fully-
//    initialised player with all resources.
//
// 2. WEB client spoof via setHTTPBody: was a no-op: the /player call goes
//    over QUIC and never touches NSMutableURLRequest.  (Removed.)
//
// 3. (Root cause of Code=14 "Something went wrong", confirmed via HAR)
//    YouTube sends Apple AppAttest tokens to iosantiabuse-pa.googleapis.com
//    to obtain PO (Proof of Origin) tokens for GVS authentication.  Inside
//    LiveContainer the AppAttest carries LiveContainer's Team ID
//    (LSMHR68PG6) instead of YouTube's, so every exchange returns
//    400 "Precondition check failed."  After 9 consecutive failures the
//    YouTube app aborts the SABR stream and shows Code=14.
//
//    Critically, GVS CDN is NOT enforcing PO tokens server-side — every
//    segment request returns 200 regardless.  The YouTube app itself is
//    the entity that kills the stream.
//
//    Fix A: Disable the PO token system via YTHotConfig flags so
//    iosantiabuse is never called.
//    Fix B: Hook YTIOSGuardSnapshotControllerImpl to intercept the
//    attestation response handler and strip the error before it reaches
//    the stream-kill logic (belt-and-suspenders fallback).

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

@interface YTIOSGuardSnapshotControllerImpl : NSObject
@end

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

// Force renderViewType=2 on playerConfig BEFORE the pool creates its player.
// In 21.20.4 the pool passes mediaPlayerResources + recompositeProvider to
// the player init, which are required for the player to load any URL.
// Previously we called makeAVPlayer() here which skipped those arguments,
// producing a player that was never wired up → Code=2 immediately.
- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings latencyLogger:(id)latencyLogger reloadContext:(id)reloadContext mediaPlayerResources:(id)mediaPlayerResources recompositeProvider:(id)recompositeProvider {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (id)playerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig mediaPlayerResources:(id)mediaPlayerResources {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (BOOL)canQueuePlayerPlayVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig reloadContext:(id)reloadContext error:(NSError **)error {
    return NO;
}

- (BOOL)canUsePlayerView:(id)playerView forPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

%end

%hook MLPlayerPool

- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings latencyLogger:(id)latencyLogger reloadContext:(id)reloadContext mediaPlayerResources:(id)mediaPlayerResources recompositeProvider:(id)recompositeProvider {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

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
// PO Token bypass
//
// Confirmed via HAR: LiveContainer2 Team ID LSMHR68PG6 is embedded in the
// Apple AppAttest payload sent to iosantiabuse-pa.googleapis.com/v1/exchange.
// Google rejects it (400 "Precondition check failed.") because it's not
// YouTube's real Team ID.  After 9 consecutive 400s the YouTube app aborts
// the SABR stream (status 999) and shows Code=14.  GVS CDN serves all
// segments at 200 without PO token enforcement — the app itself kills.
//
// Fix A: Disable PO token system via YTHotConfig flags (primary).
// Fix B: Strip error from attestation response handler (fallback).
// ---------------------------------------------------------------------------
%hook YTHotConfig
- (BOOL)iosClientGlobalConfigDisableIosPoTokens { return YES; }
- (BOOL)iosPlayerClientSharedConfigEnablePoTokenManagerMedia { return NO; }
- (BOOL)iosPlayerClientSharedConfigEnablePoTokenManagerInjection { return NO; }
- (BOOL)iosPlayerClientSharedConfigIosSpsEnablePoTokenCabr { return NO; }
%end

%hook YTIOSGuardSnapshotControllerImpl
// Strip the attestation error before it reaches the SABR-kill logic.
// Passing nil for response + error simulates "no snapshot obtained, no
// error" — the caller skips the failure path and does not abort the stream.
- (void)handleAttestationChallengeResponse:(id)response
                                     error:(NSError *)error
                                   videoID:(NSString *)videoID
                                identityID:(NSString *)identityID
                         completionHandler:(id)completionHandler {
    %orig(nil, nil, videoID, identityID, completionHandler);
}
%end

// ---------------------------------------------------------------------------
// HLS stream availability
//
// When AVPlayer mode is active (renderViewType=2) the player uses
// hlsManifestUrl from the IOS client response.  MLHLSStreamSelector loads
// the master playlist and notifies its delegate so the quality selector UI
// can populate.
//
// KVC key @"_completeMasterPlaylist" was renamed in 21.20.4 and returns nil,
// so the delegate was called with an empty array.  Use arg1 directly instead.
// ---------------------------------------------------------------------------
%hook MLHLSStreamSelector
- (void)didLoadHLSMasterPlaylist:(MLHLSMasterPlaylist *)playlist {
    %orig;
    NSArray *variants = [playlist remotePlaylists];
    if (variants.count > 0)
        [[self delegate] streamSelectorHasSelectableVideoFormats:variants];
}
%end

// ---------------------------------------------------------------------------
// Code=2 safety net
//
// YouTube's player framework checks adaptiveFormats during stream-setup.
// If renderViewType=2 is set correctly and the pool creates a proper
// MLAVPlayer, this error should never fire.  The hook is kept as a safety
// net in case the framework still raises it for an unrelated reason.
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

%ctor {
    if (!FixPlayback()) return;
    %init;
}
