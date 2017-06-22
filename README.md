# hammer
Hammer your iOS code into shape without having to rebuild.

![hammer in action](https://github.com/maranas/hammer/blob/master/hammer-demo.gif?raw=true)


### What?
Have you ever experienced any of these:
- gotten tired of having to rebuild/compile your app whenever you make a small change, e.g. changing a label’s text, changing the background color of a view, changing the layer properties etc.
- have a large codebase and want to make quick edits without having to go through the whole save/build/run process?
- just want to be able to “refresh” a page after editing your code, just like how those fancy web developers do it?

If you answered YES to any of those questions, hammer might be for you.

### How?
Hammer works by taking advantage of the Objective-C runtime, and dynamic libraries.
- Objective-C resolves function pointers at runtime.
- We can change/swizzle these implementations ;)
- Dynamic libraries can be loaded while the app is running ;)
- Why not compile only the file you edited as a dynamic library? ;)

### Wew?
Hammer is a very simple (right now, proof of concept) piece of code, in two parts.
- A Python script that compiles whatever you are editing in Xcode into a dynamic library and copies it into the Simulator, in the latest App container’s Documents directory
- An Objective-C class with a method that loads whatever dynamic libs were “hammered” into the App container

### Instructions
Right now this is a proof of concept and a very rough implementation with several assumptions:
- You are working with Objective-C (Swift to follow!)
- You only have one class per .m file, and the class name is the same as the filename!

To integrate it with your project, you only have to:
- add a reference to Hammer.m and Hammer.h in your project
- Build your project once in Xcode, and run it once in the simulator

To “hammer” in code while your app is running in the Simulator:
- make your changes in Xcode, save
- run `python hammer.py`. No parameters needed, the only requirement is the edited file has to be currently open in Xcode.
- pause the debugger, and `po [[Hammer sharedInstance] triggerHammer]`

Done. This is a proof of concept for now so there is a lot of things still to do.

### TODOs:
- loading multiple successive changes
- detect all changed files, instead of just the currently edited file in Xcode
- Swift
- xibs/storyboards/assets

### License
See LICENSE
