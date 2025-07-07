//
//  CMSHelper.h
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMSHelper : NSObject

/**
 * 使用CMS签名数据
 * @param data 需要签名的数据
 * @param p12Data P12/PFX证书数据
 * @param password 证书密码
 * @param error 如果发生错误，将设置此参数
 * @return 签名后的数据，如果失败则返回nil
 */
+ (nullable NSData *)signData:(NSData *)data 
                withP12Data:(NSData *)p12Data 
                   password:(NSString *)password 
                      error:(NSError **)error;

/**
 * 使用CMS签名数据（简化版本，不返回详细错误）
 * @param data 需要签名的数据
 * @param p12Data P12/PFX证书数据
 * @param password 证书密码
 * @return 签名后的数据，如果失败则返回nil
 */
+ (nullable NSData *)signData:(NSData *)data 
                withP12Data:(NSData *)p12Data 
                   password:(NSString *)password;

 // 使用CMS API签名数据
+ (nullable NSData *)signDataWithCMS:(NSData *)data 
                          identity:(SecIdentityRef)identity 
                             error:(NSError **)error;

// 使用CMS API签名数据（简化版本）
+ (nullable NSData *)signDataWithCMS:(NSData *)data 
                            identity:(SecIdentityRef)identity;

/**
 * 检查CMS签名功能是否可用
 * @return 如果可用返回YES，否则返回NO
 */
+ (BOOL)isSigningAvailable;

@end

NS_ASSUME_NONNULL_END 