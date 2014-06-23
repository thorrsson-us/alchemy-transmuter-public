---
title: Examples
modified: 2014-06-07 23-18-54
layout: page
tags: []
permalink: "examples.html"
comments: true
---

<section id='overview'>
# Overview

The Alchemy Transmuter talks HTTP, so you can the answers to your requests with simple cURL calls. We'll cover a few basic examples here, demonstrating the main endpoints.

<section id='dependencies'>
## Dependencies

Required:

+ A unix-like operating system (only tested on Linux).
+ Ruby 1.9+ (ruby 2.0+ preferred)
+ cURL

Optional:

+ nginx (for production)
+ runit (to run as service)
+ capistrano (to deploy)
+ collins (for intake)

<section id='setup'>
## Getting set up

First, make sure you have cloned an up-to-date copy of the code:

```
git clone https://github.com/Shopify/alchemy-transmuter-public.git
```

If you already have the repo, ensure it is up-to-date:

```
git pull --rebase origin master
```

Of course, follow normal git procedures for stashing changes, etc before updating.

Once you have the repo, change directory into it and install required gems with bundler:

```
bundle install
```

Verify that you can run the transmuter by executing:

```
bundle exec ruby transmuter.rb
```

<section id='endpoints'>
# Endpoints

<section id='root'>
## /

This is boot "Stage 1"

The / endpoint is what will be called by iPXE if you are using the recommended embedded callback script procedure. It will supply a script to iPXE, requesting additional information about the server being booted. This allows us to dynamically tell iPXE what to do, without having to build advanced scripting logic directly into the image, so we have to rebuild / replace the iPXE image much less, but don't sacrifice scriptability.

Sample call, as iPXE would make it via hardcoded bootstrap script:

```
curl localhost:7000/
```

Sample result, as iPXE would recieve it:

```
#!ipxe
# see http://etherboot.org/wiki/commandline for details on smbios strings
set boot-url http://${dhcp-server}/boot

set uri-params  mac=${mac}
set uri-params  ${uri-params}&serial=${serial}
set uri-params  ${uri-params}&product=${product}
set uri-params  ${uri-params}&manufacturer=${manufacturer}
set uri-params  ${uri-params}&board-serial=${board-serial}
set uri-params  ${uri-params}&board-product=${smbios/2.5.0}
set uri-params  ${uri-params}&dhcp-server=${dhcp-server}

set boot-uri ${boot-url}?${uri-params}
chain --replace --autofree ${boot-uri}? ||

```

<section id='boot'>
## /boot

This is boot "Stage 2"

The /boot endpoint is where iPXE to respond back to the transmuter with the requested in Stage 1.

There are a few required parameters:

| Parameter name | Sample                 | Description                                            |
|:---------------|:-----------------------|:---------------------------------------------------    |
| mac            | 00:00:00:00:00:00      |The mac address of the NIC being booted                 |
| serial         | 123456789              |The unique chassis serial of the asset being booted     |
| product        | X4887H                 |The chassis product name of the asset being booted      |
| manufacturer   | Supermicro             |The manufacturer of the asset being bootid              |
| board-serial   | 00123456789            |The unique motherboard serial of the asset being booted |
| board-product  | 041HH                  |The motherboard product name of the asset being booted  |

***Note:*** there is currently no parameter validation, besides required a paramter be present (even empty is acceptable).

Sample call, as iPXE would make it

```
curl 'localhost:7000/boot?mac=00:00:00:00:00:00&serial=123456789&product=X4887H&manufacturer=Supermicro&board-serial=00123456789&board-product=041HH'
```

Sample result, as iPXE would recieve it:

```
#!ipxe


# Some menu defaults
set menu-timeout 5000
set submenu-timeout ${menu-timeout}

# Allow overriding the menu default for automation


isset ${menu-default} || set menu-default exit

# Figure out if client is 64-bit capable
cpuid --ext 29 && set arch x64 || set arch x86
cpuid --ext 29 && set archl amd64 || set archl i386

###################### MAIN MENU ####################################


# This menu should be dynamically generated from spells, probably just make a metadata format

:start
menu iPXE boot menu for ${initiator-iqn}
item --gap --             ------------------------- OS Installation --------------------------------
item --key o menu-coreos Select CoreOS channel to boot...
item --key u menu-ubuntu Select preseeds for ubuntu installer...
item --gap --             ------------------------- Tools and utilities ----------------------------
item --key a alchemy Boot Alchemy Linux
item --gap --             ------------------------- Advanced opts -------------------------------
item --key c config       Configure settings
item shell                Drop to iPXE shell
item reboot               Reboot computer
item
item --key x exit         Exit iPXE and continue BIOS boot
choose --timeout ${menu-timeout} --default ${menu-default} selected || goto cancel
set menu-timeout 0
goto ${selected}


:alchemy
chain --replace --autofree  http://${dhcp-server}/spell/render/alchemy/boot?sku=SPM-00123456789

:menu-coreos
menu CoreOS Channels
    item  upstream_364 Boot Upstream build 364
    item  coreos_alpha Boot Internal Alpha Channel
    item  coreos_beta Boot Internal Beta Channel
    item  coreos_test Boot Internal Test Channel
item
item --key 0x08 back      Back to top menu...
iseq ${menu-default} menu-coreos && isset ${submenu-default} && goto menu-coreos-timed ||
choose selected && goto ${selected} || goto start


:upstream_364
chain --replace --autofree  http://${dhcp-server}/spell/render/coreos/boot?sku=SPM-00123456789&build=upstream_364

:coreos_alpha
chain --replace --autofree  http://${dhcp-server}/spell/render/coreos/boot?sku=SPM-00123456789&build=coreos_alpha

:coreos_beta
chain --replace --autofree  http://${dhcp-server}/spell/render/coreos/boot?sku=SPM-00123456789&build=coreos_beta

:coreos_test
chain --replace --autofree  http://${dhcp-server}/spell/render/coreos/boot?sku=SPM-00123456789&build=coreos_test


:menu-ubuntu
menu Ubuntu preseeds for ${initiator-iqn}
    item  ubuntu-trusty-install Install Ubuntu Trusty 14.04 Automatic
    item  ubuntu-trusty-install-select-swap Install Ubuntu Trusty 14.04 Select Swap
    item  ubuntu-trusty-install-select-network Install Ubuntu Trusty 14.04 Select Network Interface
    item  ubuntu-trusty-install-select-swap-network Install Ubuntu Trusty 14.04 Select Swap and Network Interface
    item  ubuntu-trusty-install-manual Install Ubuntu Trusty 14.04 Manual Install
    item  ubuntu-precise-install Install Ubuntu Precise 12.04 Automatic
    item  ubuntu-precise-install-select-swap Install Ubuntu Precise 12.04 Select Swap
    item  ubuntu-precise-install-select-network Install Ubuntu Precise 12.04 Select Network Interface
    item  ubuntu-precise-install-select-swap-network Install Ubuntu Precise 12.04 Select Swap and Network Interface
    item  ubuntu-precise-install-manual Install Ubuntu Precise 12.04 Manual Install
item
item --key 0x08 back      Back to top menu...
iseq ${menu-default} menu-ubuntu && isset ${submenu-default} && goto menu-ubuntu-timed ||
choose selected && goto ${selected} || goto start



:ubuntu-trusty-install
chain --replace --autofree  http://${dhcp-server}/spell/render/ubuntu/boot?sku=SPM-00123456789&iso=trusty&mac=${mac}

:ubuntu-trusty-install-select-swap
echo -n Enter a swap value (in MB): && read swapsize
chain --replace --autofree  http://${dhcp-server}/spell/render/ubuntu/boot?sku=SPM-00123456789&iso=trusty&mac=${mac}&swapsize=${swapsize}

:ubuntu-trusty-install-select-network
chain --replace --autofree  http://${dhcp-server}/spell/render/ubuntu/boot?sku=SPM-00123456789&iso=trusty&mac=${mac}&netinterface=manual

:ubuntu-trusty-install-select-swap
echo -n Enter a swap value (in MB): && read swapsize
chain --replace --autofree  http://${dhcp-server}/spell/render/ubuntu/boot?sku=SPM-00123456789&iso=trusty&mac=${mac}&swapsize=${swapsize}&netinterface=manual

:ubuntu-trusty-install-manual
echo Starting Ubuntu  ${archl} manual install for ${initiator-iqn}
set base-url http://${dhcp-server}/ubuntu/
kernel ${base-url}/install/netboot/ubuntu-installer/${archl}/linux
initrd ${base-url}/install/netboot/ubuntu-installer/${archl}/initrd.gz
imgargs linux \
  tasks=standard  \
  -- console=tty0 console=ttyS1,115200n8
boot || goto failed
goto start


:ubuntu-precise-install
chain --replace --autofree  http://${dhcp-server}/spell/render/ubuntu/boot?sku=SPM-00123456789&iso=precise&mac=${mac}

:ubuntu-precise-install-select-swap
echo -n Enter a swap value (in MB): && read swapsize
chain --replace --autofree  http://${dhcp-server}/spell/render/ubuntu/boot?sku=SPM-00123456789&iso=precise&mac=${mac}&swapsize=${swapsize}

:ubuntu-precise-install-select-network
chain --replace --autofree  http://${dhcp-server}/spell/render/ubuntu/boot?sku=SPM-00123456789&iso=precise&mac=${mac}&netinterface=manual

:ubuntu-precise-install-select-swap
echo -n Enter a swap value (in MB): && read swapsize
chain --replace --autofree  http://${dhcp-server}/spell/render/ubuntu/boot?sku=SPM-00123456789&iso=precise&mac=${mac}&swapsize=${swapsize}&netinterface=manual

:ubuntu-precise-install-manual
echo Starting Ubuntu  ${archl} manual install for ${initiator-iqn}
set base-url http://${dhcp-server}/ubuntu/
kernel ${base-url}/install/netboot/ubuntu-installer/${archl}/linux
initrd ${base-url}/install/netboot/ubuntu-installer/${archl}/initrd.gz
imgargs linux \
  tasks=standard  \
  -- console=tty0 console=ttyS1,115200n8
boot || goto failed
goto start


:cancel
echo You cancelled the menu, dropping you to a shell

:shell
echo Type 'exit' to get the back to the menu
shell
set menu-timeout 0
set submenu-timeout 0
goto start

:failed
echo Booting failed, dropping to shell
goto shell

:reboot
reboot

:exit
exit

:config
config
goto start

:back
set submenu-timeout 0
clear submenu-default
goto start

```

<section id='dynamic-endpoint'>
## r/spell/render/

This is a dynamic URL. It is used to request a spell to render a specific endpoint. This is most useful where you need something to be rendered by a spell, where no state is required. For instance, this is used to render the actual iPXE boot calls, so that booting can be automated when a user selects a boot menu item, or to notify the transmuter that spell boot endpoint was successfully rendered.

Sample call, as encoded into the iPXE menu with variables substituted by iPXE:

```
curl 'http://localhost:7000/spell/render/ubuntu/boot?sku=SPM-00123456789&iso=trusty&mac=00:00:00:00:00:00'
```

Sample result:

```
#!ipxe
echo Starting Ubuntu 14.04 local installer for ${initiator-iqn}
set base-url http://${dhcp-server}/ubuntu/trusty
kernel ${base-url}/install/netboot/ubuntu-installer/${archl}/linux
initrd ${base-url}/install/netboot/ubuntu-installer/${archl}/initrd.gz
# Note: https://bugs.launchpad.net/ubuntu/+source/netcfg/+bug/56679 fixes bug with auto selecting interfaces
imgargs linux \
  debian-installer/locale=en_US.utf8 \
  console-setup/ask_detect=false \
  keyboard-configuration/layoutcode=us \
  url=http://${dhcp-server}/spell/render/ubuntu/preseed?dhcp-server=${dhcp-server}&sku=SPM-00123456789&codename=trusty&swapsize=4000 \
  live-installer/net-image=${base-url}/install/filesystem.squashfs \
  netcfg/get_hostname=SPM-00123456789 \
  netcfg/choose_interface=auto \
  BOOTIF=00:00:00:00:00:00:00 \
  net.ifnames=1 biosdevname=0 \
  mirror/http/hostname=${dhcp-server} mirror/http/directory=/ubuntu/trusty \
    \
  -- console=tty0 console=ttyS1,115200n8 DEBCONF_DEBUG=5
boot || goto failed
goto start

```

