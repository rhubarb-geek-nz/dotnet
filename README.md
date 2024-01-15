# dotnet
Create ARM and ARM64 packages for dotnet-sdk

The goal is to quickly get .NET Core up and running on a target system with correctly made packages.
## Instructions
Run from a shell on a Debian based Raspberry Pi and it will download and create the appropriate packages. 

For 32bit ARM, first create the LTS packages

~~~
$ ./package.sh
.......
ar: creating dotnet-apphost-pack-3.1.4-armhf.deb
ar: creating dotnet-host-3.1.4-armhf.deb
ar: creating dotnet-hostfxr-3.1.4-armhf.deb
ar: creating dotnet-runtime-3.1.4-armhf.deb
ar: creating dotnet-runtime-deps-3.1.4-all.deb
ar: creating dotnet-sdk-3.1.300-armhf.deb
ar: creating dotnet-targeting-pack-3.1.0-armhf.deb
ar: creating aspnetcore-runtime-3.1.4-armhf.deb
ar: creating aspnetcore-targeting-pack-3.1.2-armhf.deb
ar: creating netstandard-targeting-pack-2.1.0-armhf.deb
~~~

Then you can create packages for the earlier 2.1 release

~~~
$ ./package.sh 2.1
.......
ar: creating dotnet-host-2.1.18-armhf.deb
ar: creating dotnet-hostfxr-2.1.18-armhf.deb
ar: creating dotnet-runtime-2.1.18-armhf.deb
ar: creating dotnet-runtime-deps-2.1.18-all.deb
ar: creating dotnet-sdk-2.1.804-armhf.deb
ar: creating aspnetcore-runtime-2.1.18-armhf.deb
~~~

For 64bit ARM64 this is the same

~~~
$ ./package.sh
.......
ar: creating dotnet-apphost-pack-3.1.4-arm64.deb
ar: creating dotnet-host-3.1.4-arm64.deb
ar: creating dotnet-hostfxr-3.1.4-arm64.deb
ar: creating dotnet-runtime-3.1.4-arm64.deb
ar: creating dotnet-runtime-deps-3.1.4-all.deb
ar: creating dotnet-sdk-3.1.300-arm64.deb
ar: creating dotnet-targeting-pack-3.1.0-arm64.deb
ar: creating aspnetcore-runtime-3.1.4-arm64.deb
ar: creating aspnetcore-targeting-pack-3.1.2-arm64.deb
ar: creating netstandard-targeting-pack-2.1.0-arm64.deb
~~~

Except the ASP Core runtime does not exist for ARM64 2.1

~~~
$ ./package.sh 2.1
.......
dotnet_install: Error: Could not find/download: `ASP.NET Core Runtime` with version = 2.1.18
....
ar: creating dotnet-host-2.1.18-arm64.deb
ar: creating dotnet-hostfxr-2.1.18-arm64.deb
ar: creating dotnet-runtime-2.1.18-arm64.deb
ar: creating dotnet-runtime-deps-2.1.18-all.deb
ar: creating dotnet-sdk-2.1.804-arm64.deb
~~~

Firstly, if you want both 3.1 and 2.1 then only install the most recent dotnet-host package.
Also, you can't install the 2.1 SDK on ARM64 due to the missing ASP package.

The arm/arm64 and all packages can be installed with 

~~~
sudo dpkg -i ...
~~~

If you having missing dependencies then use

~~~
sudo apt --fix-broken install
~~~

The resulting install packages should now look like

~~~
$ dpkg -l "aspnet*" "dotnet*" "netstandard*"
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name                         Version             Architecture        Description
+++-============================-===================-===================-=============================================================
ii  aspnetcore-runtime-2.1       2.1.18-1            armhf               Microsoft ASP.NET Core 2.1.18 Shared Framework
ii  aspnetcore-runtime-3.1       3.1.4-1             armhf
ii  aspnetcore-targeting-pack-3. 3.1.2-1             armhf
un  dotnet                       <none>              <none>              (no description available)
ii  dotnet-apphost-pack-3.1      3.1.4-1             armhf               Microsoft.NETCore.App.Host 3.1.4
ii  dotnet-host                  3.1.4-1             armhf               Microsoft .NET Core Host - 3.1.4
ii  dotnet-hostfxr-2.1           2.1.18-1            armhf               Microsoft .NET Core Host FX Resolver - 2.1.18 2.1.18
ii  dotnet-hostfxr-3.1           3.1.4-1             armhf               Microsoft .NET Core Host FX Resolver - 3.1.4 3.1.4
un  dotnet-nightly               <none>              <none>              (no description available)
ii  dotnet-runtime-2.1           2.1.18-1            armhf               Microsoft .NET Core Runtime - 2.1.18 Microsoft.NETCore.App 2.
ii  dotnet-runtime-3.1           3.1.4-1             armhf               Microsoft .NET Core Runtime - 3.1.4 Microsoft.NETCore.App 3.1
ii  dotnet-runtime-deps-2.1      2.1.18-1            all                 dotnet-runtime-deps-2.1 2.1.18
ii  dotnet-runtime-deps-3.1      3.1.4-1             all                 dotnet-runtime-deps-3.1 3.1.4
ii  dotnet-sdk-2.1               2.1.804-1           armhf               Microsoft .NET Core SDK 2.1.804
ii  dotnet-sdk-3.1               3.1.300-1           armhf               Microsoft .NET Core SDK 3.1.300
ii  dotnet-targeting-pack-3.1    3.1.0-1             armhf               Microsoft.NETCore.App.Ref 3.1.0
ii  netstandard-targeting-pack-2 2.1.0-1             armhf               NETStandard.Library.Ref 2.1.0
~~~

Or on ARM64

~~~
$ dpkg -l "aspnet*" "dotnet*" "netstandard*"
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name                           Version      Architecture Description
+++-==============================-============-============-=================================================================
ii  aspnetcore-runtime-3.1         3.1.4-1      arm64
ii  aspnetcore-targeting-pack-3.1  3.1.2-1      arm64
un  dotnet                         <none>       <none>       (no description available)
ii  dotnet-apphost-pack-3.1        3.1.4-1      arm64        Microsoft.NETCore.App.Host 3.1.4
ii  dotnet-host                    3.1.4-1      arm64        Microsoft .NET Core Host - 3.1.4
ii  dotnet-hostfxr-2.1             2.1.18-1     arm64        Microsoft .NET Core Host FX Resolver - 2.1.18 2.1.18
ii  dotnet-hostfxr-3.1             3.1.4-1      arm64        Microsoft .NET Core Host FX Resolver - 3.1.4 3.1.4
un  dotnet-nightly                 <none>       <none>       (no description available)
ii  dotnet-runtime-2.1             2.1.18-1     arm64        Microsoft .NET Core Runtime - 2.1.18 Microsoft.NETCore.App 2.1.18
ii  dotnet-runtime-3.1             3.1.4-1      arm64        Microsoft .NET Core Runtime - 3.1.4 Microsoft.NETCore.App 3.1.4
ii  dotnet-runtime-deps-2.1        2.1.18-1     all          dotnet-runtime-deps-2.1 2.1.18
ii  dotnet-runtime-deps-3.1        3.1.4-1      all          dotnet-runtime-deps-3.1 3.1.4
ii  dotnet-sdk-3.1                 3.1.300-1    arm64        Microsoft .NET Core SDK 3.1.300
ii  dotnet-targeting-pack-3.1      3.1.0-1      arm64        Microsoft.NETCore.App.Ref 3.1.0
ii  netstandard-targeting-pack-2.1 2.1.0-1      arm64        NETStandard.Library.Ref 2.1.0
~~~

And when you run dotnet itself you should get

~~~
$ dotnet --info
.NET Core SDK (reflecting any global.json):
 Version:   3.1.300
 Commit:    b2475c1295

Runtime Environment:
 OS Name:     raspbian
 OS Version:  9
 OS Platform: Linux
 RID:         linux-arm
 Base Path:   /usr/share/dotnet/sdk/3.1.300/

Host (useful for support):
  Version: 3.1.4
  Commit:  0c2e69caa6

.NET Core SDKs installed:
  2.1.804 [/usr/share/dotnet/sdk]
  3.1.300 [/usr/share/dotnet/sdk]

.NET Core runtimes installed:
  Microsoft.AspNetCore.All 2.1.18 [/usr/share/dotnet/shared/Microsoft.AspNetCore.All]
  Microsoft.AspNetCore.App 2.1.18 [/usr/share/dotnet/shared/Microsoft.AspNetCore.App]
  Microsoft.AspNetCore.App 3.1.4 [/usr/share/dotnet/shared/Microsoft.AspNetCore.App]
  Microsoft.NETCore.App 2.1.18 [/usr/share/dotnet/shared/Microsoft.NETCore.App]
  Microsoft.NETCore.App 3.1.4 [/usr/share/dotnet/shared/Microsoft.NETCore.App]

To install additional .NET Core runtimes or SDKs:
  https://aka.ms/dotnet-download
~~~

Even the manual page works

~~~
$ man dotnet
dotnet-cli(1)                                                                                                          dotnet-cli(1)

NAME
       dotnet -- general driver for running the command-line commands

SYNOPSIS
       dotnet [--version] [--help] [--verbose] < command > [< args >]

DESCRIPTION
       dotnet is a generic driver for the CLI toolchain.  Invoked on its own, it will give out brief usage instructions.

       Each  specific  feature  is  implemented as a command.  In order to use the feature, it is specified after dotnet, i.e.  dot‐
       net compile.  All of the arguments following the command are command's own arguments.
~~~
