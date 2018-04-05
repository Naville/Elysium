// clang -shared -undefined dynamic_lookup -o /Applications/iMazing.app/Contents/MacOS/liMazing.dylib iMazing.m
// optool install -c load -p @executable_path/liMazing.dylib -t /Applications/iMazing.app/Contents/MacOS/iMazing
// Nice Obfuscation you got there. Too bad I don't even remotely need to deobfuscate it
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
static BOOL foo2(id obj){
  [[objc_getClass("DDNAConfig") sharedInstance] setAppRegistered:1];
  return YES;
}
__attribute__((constructor))
static void fool() {
  Method m1 = class_getInstanceMethod(NSClassFromString(@"Activation"),NSSelectorFromString(@"checkIfIsActivated"));
  method_setImplementation(m1, (IMP)foo2);
}
