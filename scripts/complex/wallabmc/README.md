This demo showcases connecting to
[WallaBMC](https://github.com/tenstorrent-riscv-software/wallabmc)
emulated on Renode through TAP.

The Renode script takes care of setting up the TAP interface and connecting
the emulation to it. Having loaded the script, you'll need to assign
an IP address on the host end of the TAP. The example WallaBMC build is
configured to have a default IP address of 192.0.2.55, so assign an IP
on the host from the same subnet, ex.:
    host# ip addr add 192.0.2.1/24 dev tap0

Once you start the emulation, you can connect from your host machine
through telnet or browse the web interface at http://192.0.2.55

The password for the web interface is `demo`, the username is `admin`
