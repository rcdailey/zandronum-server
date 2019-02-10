Host your Zandronum server using Docker!

# Installation and Usage

It's recommended to use Docker Compose to configure your Zandronum instance(s). This will allow you
great flexibility over the configuration of your containers. Below is an example that will help get
you started on setting up your own server. There isn't one true way to configure things; there's a
lot of flexibility. But it is easier to start by using this example and then adjusting it as needed.

```yml
version: '3.7'

services:
  doom2:
    image: rcdailey/zandronum-server
    restart: always
    network_mode: bridge
    command: >
      -port 10667
      -iwad /data/doom2.wad
      -file /data/BD21RC7.pk3
      -file /data/mapsofchaos-hc.wad
      -file /data/DoomMetalVol4.wad
      +exec /configs/global.cfg
      +exec /configs/coop.cfg
      +exec /configs/doom2.cfg
    ports:
    - 10667:10667/udp
    volumes:
    - ./data:/data:ro
    - ./configs:/configs:ro
```

Customization of your Zandronum instance will be done through a combination of command arguments and
configuration files. Use the `>` character (as shown above) after the `command:` property to allow
your list of options to be on multiple lines for readability.

## Bridge Networking

I do not recommend using `host` network mode. Docker containers provide excellent isolation, and for
a service as simple as Zandronum, there is no benefit to running network mode as `host` over
`bridge`. Of course, using `host` doesn't hurt either; this is just my personal recommendation. If
you do choose to use bridge networking, please read this section for information relevant to port &
ip address configuration.

### Port Numbers

Typically with Docker containers, if you want to run multiple instances of a service and run them
each on different ports, you would simply map a different port on the host. However, the way
Zandronum works requires some special configuration. Zandronum reports its own listening port to the
master server

Because of this, you *must* specify a different listening port for Zandronum by giving the `-port`
option. Note that this is only a requirement if you plan to run two or more instances of this
container.

If you change the port, make sure you map that to the host (if you're using bridge network mode,
which is recommended). In the example above, I used port `10667` and mapped it to the host using
`10667:10667/udp`.

### IP Address

It's worth nothing that in bridge network mode, the IP address that Zandronum is listening on is
*not* reported to the master server. Actually, the master server will list whatever IP address it
received packets from, which will be your public IP, not the Docker bridge IP. So, no additional
configuration is needed!

## PWAD / IWAD Selection

Put all your PWAD files in a directory and map that as a volume into the container. You can put it
anywhere. In my case, I mounted my PWAD directory to `/data` in the container.

From there, provide the path to the main IWAD by using the `-iwad` option. Specify the `-file`
argument one or more times to add more PWADs to your server (such as the Brutal Doom mod). Depending
on how you mapped your volumes, you may specify individual PWAD files:

    -file /data/mywad.pk3

Or you can use wildcards to tell Zandronum to load all PWAD files in that directory:

    -file /data/*

## Configuration Files

For in-depth configuration, especially related to controlling how gameplay will work on your server,
you should provide configuration files. How you structure these files and how they are named are up
to you. I personally choose the `.cfg` extension. I also like to have my config files mounted in a
different volume and directory than my WAD files, which is why in this example I have a `/configs`
mount (for only `.cfg` files) and a `/data` mount where I keep all my WAD files.

I'll provide the contents of the config files I used in the above example. Some of these you will
want, such as the master server list configuration. But mostly this is meant to give you some ideas
on how to set up your server.

### `/configs/global.cfg`

This is the configuration I give to *all* of my servers, regardless of their purpose.

```
set sv_broadcast 0
set sv_updatemaster 1
set sv_enforcemasterbanlist true
set sv_markchatlines true
set masterhostname "master.zandronum.com:15300"
```

### `/configs/coop.cfg`

I keep my cooperative gameplay settings in its own config file. This allows me to share these
settings between multiple server instances (I run more than one server from Docker Compose).

```
set sv_maxplayers 8
set sv_maxclients 8
set sv_unblockplayers 1
set sv_coop_loseinventory 0
set sv_coop_losekeys 0
set sv_coop_loseweapons 0
set sv_coop_loseammo 0
set sv_sharekeys 1

set skill 3
set cooperative 1
set teamdamage 0
set compatflags 620756992
```

### `/configs/doom2.cfg`

This last config is dedicated to just the doom2 service in my `docker-compose.yml`, which represents
a single server instance:

```
set sv_hostname "This is the DOOM2 Server"
set sv_maprotation true
set sv_randommaprotation 1
set sv_samelevel false

addmap MAP01
addmap MAP02
addmap MAP03
addmap MAP04
addmap MAP05
```
