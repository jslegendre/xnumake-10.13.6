# xnumake-10.13.6
A self contained build system for creating a bootable xnu-4570.71.2 kernel. There are tons of XNU build scripts and Makefiles floating around the internet but I could not find any that specifially deal with making a _bootable_ build of 4570.71.2 (macOS 10.13.6). 

The problem with 4570.71.2 is that Apple did not include a vital function that makes prelinking possible and thus will not boot.  However, thanks to Shaneee from [AMD-OSX](https://amd-osx.com/) for pointing me to a [twitter post by Panicall](https://twitter.com/panicaII/status/1049906905576087552) showing a fix, I was able to prelink and boot my custom kernel.  

This build system also creates a local "XNU-specific" SDK so as to NOT modify your original SDK.  This was a major annoyance for me during testing so I opted to take this route instead. 

### How to Build
To download all dependencies, make the SDK, patch the necessary XNU files, and build a release version of the kernel:
```
sudo make
```

This take a long time and is not ideal if you want to build other versions of the kernel or have been working on your own version and just want the appropriate SDK.  So to build *only* the XNU-SDK you can use:
```
sudo make sdk
```  
Please note this will not patch xnu but you are free to use the included patches in your own on-going projects

It is also not recommended to use this to repeatedly rebuild the kernel as both `make` and `make sdk` will overwrite any modifications made to the xnu source.  Building the kernel is done strictly as test to make sure everything worked.  You are encouraged to use XNU's included Makefile for continuous development like so:

```
path/to/xnu-src$ make SDKROOT=$(PWD)/MacOSX10.13-xnu.sdk [XNU_LOGCOLORS=y] ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=(RELEASE/DEVELOPMENT/DEBUG/etc)
```
You are also welcome to install the XNU-SDK using `make install_sdk` and using the XNU Makefile as such:
```
path/to/xnu-src$ make SDKROOT=macosx10.13-xnu [XNU_LOGCOLORS=y] ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=(RELEASE/DEVELOPMENT/DEBUG/etc)
```

### Notes
This does not have flags to configure or build `libsyscall` yet.  This feature is coming soon though!
This was originally something I made for myself after trying out a few different XNU build scripts/Makefiles for older XNU versions so large chunks of this are copy/pasted/modified from those. Check them out if you want to add some features to your XNU build system!

[xnu-make by ddeville](https://github.com/ddeville/xnu-make)

[xnubuild by PureDarwin](https://github.com/PureDarwin/xnubuild)

[xnudeps by Jeremy Andrus](https://kernelshaman.blogspot.com/2018/01/building-xnu-for-macos-high-sierra-1013.html)
