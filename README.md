# Zandronum Server Docker Images

Host your Zandronum server using Docker!

* [Docker Hub](https://hub.docker.com/r/rcdailey/zandronum-server)
* [Github Repository](https://github.com/rcdailey/zandronum-server)

[![Actions Status](https://github.com/rcdailey/zandronum-server/workflows/build/badge.svg)](https://github.com/rcdailey/zandronum-server/actions)

## Docker Tags

There are various versions and forks of Zandronum available. The tags are in a `<distro>-<version>`
format. The various distributions are described in the list below. Each distro has a latest tag, in
the format `<distro>-latest`.

* [**TSPG**](https://bitbucket.org/thesentinelsplayground/zatspg-release)<br>
  A fork of the official Zandronum code base that is used for servers hosted on [The Sentinel's
  Playground](https://allfearthesentinel.net/) (TSPG).<br>
  Tags: `tspg-latest`, `tspg-v12`, etc
* [**Official**](https://bitbucket.org/Torr_Samaho/zandronum)<br>
  The unmodified & official version of Zandronum.<br>
  Tags: `official-latest`, `official-3.0`, etc

## Installation and Usage

It's recommended to use Docker Compose to configure your Zandronum instance(s). This will allow you
great flexibility over the configuration of your containers. Below is an example that will help get
you started on setting up your own server. There isn't one true way to configure things; there's a
lot of flexibility. But it is easier to start by using this example and then adjusting it as needed.

```yml
version: '3.7'

services:
  doom2:
    image: rcdailey/zandronum-server:official-latest
    restart: always
    network_mode: host
    command: >
      -port 10667
      -iwad /data/doom2.wad
      -file /data/BD21RC7.pk3
      -file /data/mapsofchaos-hc.wad
      -file /data/DoomMetalVol4.wad
      +exec /configs/global.cfg
      +exec /configs/coop.cfg
      +exec /configs/doom2.cfg
    volumes:
    - ./data:/data:ro
    - ./configs:/configs:ro
```

Customization of your Zandronum instance will be done through a combination of command arguments and
configuration files. Use the `>` character (as shown above) after the `command:` property to allow
your list of options to be on multiple lines for readability.

For more examples, see the `examples` directory in this repository.

## Networking

### Host Networking

Due to the inflexible nature of how Zandronum's networking code functions, I recommend using `host`
network mode (reflected in my example above). If you prefer more network isolation and would like to
use `bridge` network mode, please read the following section.

### Bridge Networking

If you use `bridge` networking, LAN broadcasting (via `sv_broadcast`) does not work properly. This
is because Zandronum advertises the bound IP address (which is on the docker bridge subnet), which
your LAN subnet will not have direct access to. Other than that, though, everything works. The
sub-sections below go into more detail.

#### Port Numbers

Typically with Docker containers, if you want to run multiple instances of a service and run them
each on different ports, you would simply map a different port on the host. However, the way
Zandronum works requires some special configuration. Zandronum reports its own listening port to the
master server.

Because of this, you *must* specify a different listening port for Zandronum by giving the `-port`
option. Note that this is only a requirement if you plan to run two or more instances of this
container.

If you change the port, make sure you map that to the host. Using the example above, I used port
`10667` and which you would map to the host by adding the following additional YAML to your
`docker-compose.yml` file:

```yml
    ports:
    - 10667:10667/udp
```

#### IP Address

It's worth noting that in bridge network mode, the IP address that Zandronum is listening on is
*not* reported to the master server. Actually, the master server will list whatever IP address it
received packets from, which will be your public IP, not the Docker bridge IP. So, no additional
configuration is needed for connecting via master server.

Do remember, however, that the incorrect IP address is broadcast for LAN games, so if this is
important, please use `host` for your `network_mode:` setting.

## PWAD / IWAD Selection

Put all your WAD files (PWAD + IWAD) in a directory and map that as a volume into the container. You
can put it anywhere. In my case, I mounted my WAD directory to `/data` in the container.

From there, provide the path to the main IWAD by using the `-iwad` option. Specify the `-file`
argument one or more times to add more PWADs to your server (such as the Brutal Doom mod). Depending
on how you mapped your volumes, you may specify individual PWAD files:

    -file /data/mywad.pk3

Or you can use wildcards to tell Zandronum to load all PWAD files in that directory:

    -file /data/*

## User & Group

Inside the container, `zandronum-server` runs as user `doomguy` and group `zandronum`. The
corresponding UID and GID is determined by Docker. If you want to have explicit control over either
the UID or GID used inside the container, you can specify the following environment variables. Note
that overriding this behavior is really only useful if you want to properly map file permissions in
your host volumes to the user running in the container.

* `ZANDRONUM_UID`<br>
  The User ID on the *host machine* that will be assigned to the `doomguy` user in the container.
* `ZANDRONUM_GID`<br>
  The Group ID on the *host machine* that will be assigned to the `zandronum` group in the
  container.

Note that it is an error to run this image using the `-u`/`--user` argument to `docker run` or the
`user:` property in `docker-compose.yml`. The container *itself* must start as a root user, but the
`zandronum-server` process is started using the local user & group.

### Examples

As an example, you can add the following attributes to the existing YAML example file (shown
earlier) which will assign the `doomguy` user to UID 1000 and GID 1050:

```yml
environment:
- ZANDRONUM_UID=1000
- ZANDRONUM_GID=1050
```

Or you can map these to environment variables you defined in your `~/.bashrc`, for example (based on
Ubuntu 18.04):

```bash
export UID
export GID="$(id -g)"
```

Which you would use in your `docker-compose.yml` like so:

```yml
environment:
- ZANDRONUM_UID=$UID
- ZANDRONUM_GID=$GID
```

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

## Building the Images

The `Dockerfile` takes two arguments when you run `docker build` (provided via the `--build-arg`
option):

* `REPO_URL`<br>
  The Mercurial repository URL (HTTPS only) of the Zandronum code base. This can be the official
  repo or a compatible fork.
* `REPO_TAG`<br>
  The tag in the repository to clone & build.
