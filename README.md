# Adding USB support to WSL 2

This method adds support to WSL 2 by using USBIP on Windows to forward USB packets to USBIP on Linux.
The Linux kernel on WSL 2 does not support USB devices by default. The instructions here will explain how to add USB functionality to the WSL Linux kernel and how to use USBIP to hook devices into Linux.

## USBIP-Win

If you require the latest version of usbip-win you'll have to build usbip-win yourself.

Install git for Windows if you haven't already:
> https://gitforwindows.org/


Open git bash in the start menu and clone usbip-win:
```
$ git clone https://github.com/cezuni/usbip-win.git
```

Follow the instructions to build usbip-win in README.md. You'll have to install Visual Studio (community and other SKU's work), the Windows SDK and the Windows Driver Kit. Install each one in the order that is given in the instructions and don't install more then 1 thing at a time or the Windows SDK or Windows Driver Kit will install in a broken state that took me hours to figure out.

If you don't need the latest version you can get prebuilt versions located here:
> https://github.com/cezuni/usbip-win/releases

Note that the prebuilt version (0.3.5-dev) crashed on me. usbip-win was developed in the pre-WinUSB era, so using it on Windows 10 requires that you enable testsigned drivers. This has some security implications.

## Adding USB support to WSL2 Linux

These instructions assume you already have WSL2 and Ubuntu for WSL2 installed. If not, follow the directions here:

> https://docs.microsoft.com/en-us/windows/wsl/wsl2-install

Please note that you must be running Windows 10 1903 build 18362 or higher as explained in the description. 

Open an Ubuntu shell to run the following commands. 

Update sources:
```
~$ sudo apt update
```

Install prerequisites to build the Linux kernel:
```
~$ sudo apt install build-essential flex bison libssl-dev libelf-dev libncurses-dev autoconf libudev-dev libtool
````

Clone this repository and run the mk-wsl-usbip.sh script:
```
~$ git clone https://github.com/supersat/usbip-wsl2-instructions.git
~$ cd usbip-wsl2-instructions
~/usbip-wsl2-instructions$ ./mk-wsl-usbip.sh
```

If all goes well, the `mk-wsl-usbip.sh` script should detect your kernel version, 
find the matching tag from Microsoft's WSL2 kernel git repository, clone that version
of the WSL2 kernel repository, enable building usbip and related modules, make
the kernel, install the modules, make the usbip userland tools, and install the
usbip userland tools!

Building the entire kernel is necessary to generate the Module.symvers file, which
allows modules to know that they're linking against known versions of functions
in the kernel. As far as I can tell, there's no other way to get this file.

Note that the LOCALVERSION= variable is passed to make. This ensures that the kernel
version doesn't have a plus added to it (meaning that it was built from a tree modified
from a particular git tag). If a plus is added to the kernel version, there will be
a mismatch between the running kernel and the version of the kernel the modules expect.

If you want to add driver support for other types of USB peripherals, you can do a
`make menuconfig` in the WSL2-Linux-Kernel directory to select which ones you want.
Be sure to specify building them as modules. Then, you can do another build:

```
~/usbip-wsl2-instructions/WSL2-Linux-Kernel$ make LOCALVERSION= -j $(nproc)
~/usbip-wsl2-instructions/WSL2-Linux-Kernel$ sudo make modules_install
```

Restart WSL. In a CMD window in Windows type:
```
C:\Users\rpasek>wsl --shutdown
```

Open WSL2 again and run the `startusb.sh` script which will load all of the new modules:
```
~$ ~/usbip-wsl2-instructions/startusb.sh
```

Check in dmesg that all your USB drivers got loaded:
```
~$ sudo dmesg
````

If so, cool, you've added USB support to WSL. 

## Using USBIP-Win and USBIP on Linux

This will generate a list of usb devices attached to Windows:
```
C:\Users\rpasek\usbip-win-driver>usbip list -l
```

The busid of the device I want to bind to is 1-220. Bind to it with: 
```
C:\Users\rpasek\usbip-win-driver>usbip bind --busid=1-220
```

Now start the usbip daemon. I start in debug mode to see more messages:
```
C:\Users\rpasek\usbip-win-driver>usbipd --debug
```

Now on Linux get a list of availabile USB devices:
```
~$ sudo usbip list --remote=172.30.64.1
```

The busid of the device I want to attach to is 1-220. Attach to it with:
```
~$ sudo usbip attach --remote=172.30.64.1 --busid=1-220
```

Your USB device should be usable now in Linux. Check dmesg to make sure everything worked correctly:
```
~$ sudo dmesg
```

## Couple of tips

* You need to bind to the base device of a composite device. Binding to children of a composite device does not work.
* You can't bind hubs. Sorry, it would be really cool but it doesn't work.
* If you'd like to unbind so you can access the device in Windows again: 
  1. Go into Device Manager in Windows,
  2. Find the USB/IP STUB device under System devices,
  3. Right click and select Update driver
  4. Click Browse my computer for driver software
  5. Click Let me pick from a list of available drivers on my computer
  6. Select the original driver that Windows uses to access the device
* Sometimes USBIP on Windows can't attach to a device. Try moving the device to a different hub and binding again. You can move the device back after you bind as binding sticks through attach/detach cycles.
* I had some trouble on one of my machines getting composite devices to show up in usbip list on the Windows side. To get around this:
  1. Download Zadig (https://zadig.akeo.ie) and run it
  2. Go to options and select "List All Devices" and deselect "Ignore Hubs or Composite Parents"
  3. Select your USB composite device in the list
  4. Install the libusbK driver
  5. Now your device should show up in the usbip list
  6. I don't really know why this works. It might be that the Windows default driver captures the composite device in a way that USBIP-Win can't see it and installing the libusbK frees it. USBIP-Win will essentially overwrite the libusbK driver with the USBIP-Win driver so you might be able to select any driver (not just libusbK). Either way it's probably a bug that needs to be worked out in USBIP-Win
