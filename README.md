# Docker Traffic Control

![Version](https://img.shields.io/badge/version-18.12-lightgrey.svg?style=flat)
[![Docker pulls](https://img.shields.io/docker/pulls/lukaszlach/docker-tc.svg?label=docker+pulls)](https://hub.docker.com/r/lukaszlach/docker-tc)
[![Docker stars](https://img.shields.io/docker/stars/lukaszlach/docker-tc.svg?label=docker+stars)](https://hub.docker.com/r/lukaszlach/docker-tc)

**Docker Traffic Control** allows to set a rate limit on the container network and can emulate network conditions like delay,
packet loss, duplication, and corrupt for the Docker containers, all that basing only on labels. [HTTP API](#http-api) allows
to [fetch](#get) and [pause](#delete) existing rules and to [manually overwrite](#post) them, [command-line interface](#command-line)
is also available. **Project is written entirely in Bash** and is distributed as a [Docker image](https://hub.docker.com/r/lukaszlach/docker-tc/).

## Running

First run Docker Traffic Control daemon in Docker. The container needs `NET_ADMIN` capability and the `host` network mode
to manage network interfaces on the host system, `/var/run/docker.sock` volume allows to observe Docker events and query
container details.

```bash
docker run -d                                       \
    --name docker-tc                                \
    --network host                                  \
    --cap-add NET_ADMIN                             \
    --restart always                                \
    -v /var/run/docker.sock:/var/run/docker.sock    \
    -v /var/docker-tc:/var/docker-tc                \
    lukaszlach/docker-tc
```

> You can also pass `HTTP_BIND` and `HTTP_PORT` environment variables, which default to `127.0.0.1:4080`.

This repository contains `docker-compose.yml` file in root directory, you can use it instead of manually running
`docker run` command. Newest version of image will be pulled automatically and the container will run in daemon mode.

```bash
git clone https://github.com/lukaszlach/docker-tc.git
cd docker-tc
docker-compose up -d
```

> When using `docker-compose.yml` configuration is stored in the `.env` file, also provided in this repository.

## Usage

After the daemon is up it scans all running containers and starts listening for `container:start` events triggered by Docker
Engine. When a new container is up (also a new Swarm service) and contains `com.docker-tc.enabled` label set to `1`, Docker
Traffic Control starts applying network traffic rules according to the rest of the labels from `com.docker-tc` namespace
it finds.

Docker Traffic Control recognizes the following labels:

* `com.docker-tc.enabled` - when set to `1` the container network rules will be set automatically, any other value or if
  the label is not specified - the container will be ignored
* `com.docker-tc.limit` - bandwidth or rate limit for the container, accepts a floating point number, followed by a unit,
  or a percentage value of the device's speed (e.g. 70.5%). Following units are recognized:
    * `bit`, `kbit`, `mbit`, `gbit`, `tbit`
    * `bps`, `kbps`, `mbps`, `gbps`, `tbps`
    * to specify in IEC units, replace the SI prefix (k-, m-, g-, t-) with IEC prefix (ki-, mi-, gi- and ti-) respectively
* `com.docker-tc.delay` - length of time packets will be delayed, accepts a floating point number followed by an optional unit:
    * `s`, `sec`, `secs`
    * `ms`, `msec`, `msecs`
    * `us`, `usec`, `usecs` or a bare number
* `com.docker-tc.loss` - percentage loss probability to the packets outgoing from the chosen network interface
* `com.docker-tc.duplicate` - percentage value of network packets to be duplicated before queueing
* `com.docker-tc.corrupt` - emulation of random noise introducing an error in a random position for a chosen percent of packets

Docker Traffic Control can also apply rules on a specific network, to do so add the network name as a prefix the of previously
describe parameters. For example: `com.docker-tc.limit` will become `com.docker-tc.test-net.limit` where `test-net` is one
of the networks used by the container. Note that this rule doesn't apply on the label `com.docker-tc.enabled`. Also when
you are using `docker-compose` network name describe and create by the docker-compose will be prefix by the name of the
project (`--project-name` or working directory if the option is not provide).

> Read the [tc command manual](http://man7.org/linux/man-pages/man8/tc.8.html) to get detailed information about parameter
> types and possible values.

Run the `busybox` container on custom network to create virtual network interface, specify all possible labels and try to
`ping google.com` domain.

```bash
docker network create test-net
docker run -it                              \
    --net test-net                          \
    --label "com.docker-tc.enabled=1"       \
    --label "com.docker-tc.limit=1mbps"     \
    --label "com.docker-tc.delay=100ms"     \
    --label "com.docker-tc.loss=50%"        \
    --label "com.docker-tc.duplicate=50%"   \
    --label "com.docker-tc.corrupt=10%"     \
    busybox                                 \
    ping google.com
```

You should see output similar to shown below, `ping` correctly reports duplicates, packets are delayed and some of them lost.

```text
PING google.com (216.58.215.78): 56 data bytes
64 bytes from 216.58.215.78: seq=0 ttl=54 time=1.010 ms
64 bytes from 216.58.215.78: seq=1 ttl=54 time=101.031 ms
64 bytes from 216.58.215.78: seq=2 ttl=54 time=101.045 ms
64 bytes from 216.58.215.78: seq=3 ttl=54 time=101.011 ms
64 bytes from 216.58.215.78: seq=4 ttl=54 time=101.028 ms
64 bytes from 216.58.215.78: seq=5 ttl=54 time=101.060 ms
64 bytes from 216.58.215.78: seq=5 ttl=54 time=154.685 ms (DUP!)
64 bytes from 216.58.215.78: seq=6 ttl=54 time=101.084 ms
64 bytes from 216.58.215.78: seq=8 ttl=54 time=101.085 ms
64 bytes from 216.58.215.78: seq=8 ttl=54 time=1001.130 ms (DUP!)
64 bytes from 216.58.215.78: seq=11 ttl=54 time=102.218 ms
64 bytes from 216.58.215.78: seq=15 ttl=54 time=114.437 ms
64 bytes from 216.58.215.78: seq=16 ttl=54 time=101.471 ms
64 bytes from 216.58.215.78: seq=17 ttl=54 time=101.068 ms
64 bytes from 216.58.215.78: seq=17 ttl=54 time=1001.162 ms (DUP!)
64 bytes from 216.58.215.78: seq=19 ttl=54 time=101.104 ms
--- google.com ping statistics ---
20 packets transmitted, 13 packets received, 3 duplicates, 35% packet loss
round-trip min/avg/max = 1.010/152.299/1001.162 ms
```

## HTTP API

API available via HTTP allows you to manage network control rules manually on chosen container.

If you have running containers already or do not want to add Docker Traffic Control labels, you can use the
[`POST` endpoint](#post) to set the rules manually or in an automated process.

> HTTP was chosen for local management instead of `docker exec` so that you can still easily control Docker Traffic
> Control on Swarm Nodes, utilize any service discovery and manage remotely using any HTTP client.

### GET

```text
GET /<container-id|container-name> HTTP/1.1
```

Get traffic control rules for a single container.

```bash
curl localhost:4080/221517ae59d1
curl localhost:4080/my-container-name
```

### LIST

```text
LIST /<container-id|container-name> HTTP/1.1
```

List all traffic control rules for all running containers.

```bash
curl -X LIST localhost:4080
```

### DELETE

```text
DELETE /<container-id|container-name> HTTP/1.1
```

Delete all container's traffic control rules. Container is also added to the ignore list to prevent further changes whether
it has proper labels set or not.

```bash
curl -X DELETE localhost:4080/my-container-name
```

### PUT

```text
PUT /<container-id|container-name> HTTP/1.1
```

Put back the container to the scanning poll and remove it from the ignore list.

```bash
curl -X PUT localhost:4080/221517ae59d1
```

### POST

```text
POST /<container-id|container-name> HTTP/1.1
<rate|delay|loss|corrupt|duplicate>=<value>&...
```

Update container's traffic control rules. Container does not have to have any labels set, it can be any running container.
All previous rules for this container are removed.

```bash
curl -d'delay=300ms' localhost:4080/my-container-name
curl -d'delay=300ms' localhost:4080/my-container-name/my-net
curl -d'rate=512kbps' localhost:4080/221517ae59d1
curl -d'rate=1mbps&loss=10%' localhost:4080/my-container-name
```

## Command-line

Set up a command that may be available for all users...

```bash
echo 'curl -sSf -X "$1" "localhost:4080/$2?$3"' > /usr/bin/docker-tc
chmod +x /usr/bin/docker-tc
```

... or set up a local command alias:

```bash
alias docker-tc='curl -sSf -X "$1" "localhost:4080/$2?$3"'
```

### Usage

```bash
docker-tc get 221517ae59d1
docker-tc get 221517ae59d1/my-net
docker-tc list
docker-tc delete my-container-name
docker-tc put 221517ae59d1
docker-tc set my-container-name 'delay=300ms&rate=1000kbps'
docker-tc set my-container-name/my-net 'delay=300ms&rate=1000kbps'
```

## Build

```bash
git clone https://github.com/lukaszlach/docker-tc.git
cd docker-tc
make
docker images | grep docker-tc
```

## Supported platforms

Docker Traffic Control only works on Linux distributions like Debian, Ubuntu, CentOS or Fedora.

* MacOS - not supported due to lack of host network mode support
* Windows - not supported due to separate network stack between Linux and Windows containers

## Deploy on Swarm

**Warning:** Although this project is prepared for Docker Swarm you will not be able to deploy it as a service because of
the [moby/moby#25885](https://github.com/moby/moby/issues/25885) issue. This section is theoretical.

Create a global service named `docker-tc` that will scan all containers and other services that are currently running or
will start in the future.

```bash
docker service create                                                       \
    --name docker-tc                                                        \
    --mode global                                                           \
    --restart-condition any                                                 \
    --network host                                                          \
    --cap-add NET_ADMIN                                                     \
    --mount "type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock"   \
    --mount "type=bind,src=/var/docker-tc,dst=/var/docker-tc"               \
    lukaszlach/docker-tc
```

> `/var/docker-tc` directory has to exist on Docker Swarm nodes before deploying the service

## Contributors

[![](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/images/0)](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/links/0)
[![](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/images/1)](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/links/1)
[![](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/images/2)](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/links/2)
[![](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/images/3)](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/links/3)
[![](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/images/4)](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/links/4)
[![](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/images/5)](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/links/5)
[![](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/images/6)](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/links/6)
[![](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/images/7)](https://sourcerer.io/fame/lukaszlach/lukaszlach/docker-tc/links/7)

## Licence

MIT License

Copyright (c) 2018-2019 Łukasz Lach <llach@llach.pl>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
