//clang -shared -undefined dynamic_lookup -o /Applications/BaiduNetdisk_mac.app/Contents/MacOS/libPCS.dylib BaiduYun.m
//optool install -c load -p @executable_path/libPCS.dylib -t /Applications/BaiduNetdisk_mac.app/Contents/MacOS/BaiduNetdisk_mac
/*
  Their macOS client's download speed pretty much sucks even with a legitimate premium account.
  That's not very surprising since Baidu sucks dick anyway.
  ██████╗ ███████╗ █████╗ ██████╗     ██████╗  █████╗ ██╗██████╗ ██╗   ██╗
  ██╔══██╗██╔════╝██╔══██╗██╔══██╗    ██╔══██╗██╔══██╗██║██╔══██╗██║   ██║
  ██║  ██║█████╗  ███████║██████╔╝    ██████╔╝███████║██║██║  ██║██║   ██║
  ██║  ██║██╔══╝  ██╔══██║██╔══██╗    ██╔══██╗██╔══██║██║██║  ██║██║   ██║
  ██████╔╝███████╗██║  ██║██║  ██║    ██████╔╝██║  ██║██║██████╔╝╚██████╔╝▄█╗
  ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚═╝

  ███████╗██╗   ██╗ ██████╗██╗  ██╗    ███╗   ███╗██╗   ██╗     ██████╗ ██████╗  ██████╗██╗  ██╗
  ██╔════╝██║   ██║██╔════╝██║ ██╔╝    ████╗ ████║╚██╗ ██╔╝    ██╔════╝██╔═══██╗██╔════╝██║ ██╔╝
  ███████╗██║   ██║██║     █████╔╝     ██╔████╔██║ ╚████╔╝     ██║     ██║   ██║██║     █████╔╝
  ╚════██║██║   ██║██║     ██╔═██╗     ██║╚██╔╝██║  ╚██╔╝      ██║     ██║   ██║██║     ██╔═██╗
  ███████║╚██████╔╝╚██████╗██║  ██╗    ██║ ╚═╝ ██║   ██║       ╚██████╗╚██████╔╝╚██████╗██║  ██╗
  ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝     ╚═╝   ╚═╝        ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝


*/
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
static IMP request_increaseBytesTransferred=NULL;
static IMP setMaxBytesPerSecond=NULL;
static BOOL ISVIP(id obj){
  return YES;
}
static void getRekt(id obj){

}
static void hooked_request_increaseBytesTransferred(id obj,SEL _cmd,long long arg1,long long arg2){
  request_increaseBytesTransferred(obj,_cmd,MAXFLOAT,MAXFLOAT);
}
static void hooked_setMaxBytesPerSecond(id obj,SEL _cmd,unsigned long long arg1){
  setMaxBytesPerSecond(obj,_cmd,MAXFLOAT);
}
__attribute__((constructor))
static void fool() {
  Method m1 = class_getInstanceMethod(NSClassFromString(@"BandwidthManager"),NSSelectorFromString(@"request:increaseBytesTransferred:"));
  request_increaseBytesTransferred=method_getImplementation(m1);
  method_setImplementation(m1, (IMP)hooked_request_increaseBytesTransferred);
  Method m2 = class_getInstanceMethod(NSClassFromString(@"BandwidthManager"),NSSelectorFromString(@"setMaxBytesPerSecond:"));
  setMaxBytesPerSecond=method_getImplementation(m2);
  method_setImplementation(m2,(IMP)hooked_setMaxBytesPerSecond);
  Method m3 = class_getInstanceMethod(NSClassFromString(@"BandwidthManager"),NSSelectorFromString(@"performThrottling"));
  Method m4 = class_getInstanceMethod(NSClassFromString(@"BandwidthManager"),NSSelectorFromString(@"notifyThrottling"));
  method_setImplementation(m3,(IMP)getRekt);
  method_setImplementation(m4,(IMP)getRekt);
  Method m5 = class_getInstanceMethod(NSClassFromString(@"BDUser"),NSSelectorFromString(@"isSVip"));
  method_setImplementation(m5,(IMP)ISVIP);
  if(m1!=NULL&&m2!=NULL&&m3!=NULL&&m4!=NULL&&m5!=NULL){
    NSLog(@"Inj3ct3d");
  }
}
