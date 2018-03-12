
//clang -m32 -shared -undefined dynamic_lookup -o libCX.dylib CrossOver.m
/*
@interface CXApplication : XApplication
{
    NSString *crossOverRoot;
    NSString *x11Root;
    NSString *demoString;
    BOOL isDemo;
    NSString *licenseID;
    NSDate *licenseExpirationDate;
    int daysLeft;
    NSMenuItem *registerMenuItem;
    BOOL inFullScreenMode;
}

+ (BOOL)accessInstanceVariablesDirectly;
- (void)setLicenseID:(id)arg1;
- (id)licenseID;
- (void)setLicenseExpirationDate:(id)arg1;
- (id)licenseExpirationDate;
- (id)systemInformationString;
- (void)orderFrontStandardAboutPanel:(id)arg1;
- (BOOL)validateUserInterfaceItem:(id)arg1;
- (void)switchToNonFullScreenMode;
- (void)switchToFullScreenMode:(id)arg1;
- (BOOL)isInFullScreenMode;
- (void)setDaysLeft;
- (int)daysLeft;
- (void)setDemoString:(id)arg1;
- (id)demoString;
- (void)setIsDemo;
- (BOOL)isDemo;
- (id)x11Root;
- (id)crossOverRoot;
- (id)CXServer;
- (void)dealloc;
- (id)init;

@end

*/
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
static int foo(id obj){
  return INT_MAX;
}
static BOOL foo2(id obj){
  return NO;
}
__attribute__((constructor))
static void fool() {
  Method m1 = class_getInstanceMethod(NSClassFromString(@"CXApplication"),NSSelectorFromString(@"daysLeft"));
  Method m2 = class_getInstanceMethod(NSClassFromString(@"CXApplication"),NSSelectorFromString(@"isDemo"));
  method_setImplementation(m1, (IMP)foo);
  method_setImplementation(m2, (IMP)foo2);
  if(m1!=NULL && m2!=NULL){
    NSLog(@"Ball\' in");
  }
}
