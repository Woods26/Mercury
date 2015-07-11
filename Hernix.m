#import <Foundation/Foundation.h>
#import "Instantiator.h"
#import "HMPart.h"
#import "AppController.h"

BOOL is10_6 = NO;

int main (int argc, const char * argv[]) {
	if (argc < 2) {
		NSLog(@"No setup file specified");
		return 1;
	}
#if __APPLE__
//	SInt32 versionMajor, versionMinor, versionBugFix;
//	Gestalt(gestaltSystemVersionMajor, &versionMajor);
//	Gestalt(gestaltSystemVersionMinor, &versionMinor);
//	Gestalt(gestaltSystemVersionBugFix, &versionBugFix);	
//	is10_6 = versionMajor == 10 && versionMinor >= 6;
    is10_6 = YES;
#endif
	//is10_6 = NO;
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    // insert code here...
    // create an app controller instance
    AppController *controller = [[AppController alloc] init];
    // if only one parameter was passed (as in a normal call from Crocus
    if(argc == 2) {
        NSString *setupPath = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
        [controller runSimulation:setupPath];
    }
    // if two parameters were passed (if called from command line with custom output directory)
    else if(argc == 3) {
        NSString *setupPath = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
        NSString *customOutputPath = [NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding];
        [controller runSimulation:setupPath withCustomPath:customOutputPath];
    }
    else {
        NSLog(@"Too many parameters previded. Usage: mercury <setupPath> or: mercury <setupPath> <customOutputPath>");
        return 1;
    }
	// Clang suggests
	[controller release];
	[pool release];
    return 0;
}
