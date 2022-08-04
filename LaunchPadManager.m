//clang -shared -undefined dynamic_lookup -arch x86_64 -o /Applications/Launchpad\ Manager.app/Contents/MacOS/libCrack.dylib LaunchPadManager.m
//optool install -c load -p @executable_path/libCrack.dylib -t /Applications/Launchpad\ Manager.app/Contents/MacOS/Launchpad\ Manager
//codesign --remove-signature /Applications/Launchpad\ Manager.app/Contents/MacOS/Launchpad\ Manager
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
static BOOL foo(id obj){
  return YES;
}
__attribute__((constructor))
static void fool() {
  Method m = class_getClassMethod(NSClassFromString(@"RegistrationService"),NSSelectorFromString(@"isRegistered"));
  method_setImplementation(m, (IMP)foo);
  if(m!=NULL){
    NSLog(@"Ball\' in");
  }
}
