//
//  GSDMediaCacheLogDefine.h
//  GSDMediaCache
//
//  Created by xq on 2020/12/4.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#ifndef GSDMediaCacheLogDefine_h
#define GSDMediaCacheLogDefine_h

#if __has_include(<MATLog/MATLogger.h>)
    #define GSDMediaCacheLoggingEnabled 1
    #import <MATLog/MATLogger.h>
#else
    #define GSDMediaCacheLoggingEnabled 0
#endif


#if GSDMediaCacheLoggingEnabled

#define LogError(frmt, ...)   MATLogError(frmt, ##__VA_ARGS__)
#define LogWarn(frmt, ...)    MATLogWarning(frmt, ##__VA_ARGS__)
#define LogInfo(frmt, ...)    MATLogInfo(frmt, ##__VA_ARGS__)
#define LogDebug(frmt, ...)   MATLogDebug(frmt, ##__VA_ARGS__)
#define LogVerbose(frmt, ...) MATLogVerbose(frmt, ##__VA_ARGS__)
#define SetLogLevel(lvl)      [MATLog setLogLevel:lvl]

#else

// Logging Disabled

#define LogError(frmt, ...)
#define LogWarn(frmt, ...)
#define LogInfo(frmt, ...)
#define LogDebug(frmt, ...)
#define LogVerbose(frmt, ...)
#define SetLogLevel(lvl)          

#endif

#endif /* GSDMediaCacheLogDefine_h */
