---
title: Examples
modified: 2014-06-07 23-18-54
layout: page
tags: []
permalink: "examples.html"
comments: true
---

# Overview

The Alchemy Transmuter talks HTTP, so you can the answers to your requests with simple cURL calls. We'll cover a few basic examples here, demonstrating the main endpoints.

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

# Endpoints

## /

The / endpoint is what will be called by iPXE if you are using the recommended embedded callback script procedure. It will supply a script to iPXE, requesting additional information about the server being booted.

Sample call:

```
curl localhost:7000/
```

Sample result:

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
