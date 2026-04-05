# communicator48-modern

Launch Netscape Communicator 4.8 on a modern Linux system in a self-contained environment.

This repo does not include the Communicator binary. You must supply:

- `communicator-v48-us.x86-unknown-linux2.2.tar.gz`

Put that tarball in the repo root, then run:

```bash
./setup.sh
./run-communicator.sh
```

If you want to use a different archive path, set `COMMUNICATOR_ARCHIVE` when running `setup.sh`.

## What it does

- extracts the supplied Communicator archive into `app/`
- downloads old Debian X11, glibc, libstdc++, and bitmap font packages into `compat/`
- stages a local 32-bit runtime under `compat/glibc`, `compat/lib`, and `compat/x11`
- patches a pair of startup probes in the Communicator binary that modern X servers can reject
- launches Communicator inside `bwrap` with a local state directory under `state/`
- temporarily adds bundled `misc`, `75dpi`, and `100dpi` bitmap font paths before startup and removes them again on exit

## Requirements

- Linux with 32-bit x86 execution enabled
- a working X11 display or Xwayland session
- `bash`, `curl`, `ar`, `find`, `tar`, `gzip`
- `bwrap` (`bubblewrap`) to launch the isolated runtime
- optional: `xset` to register the bundled bitmap fonts with the X server
  - Common package names: `xorg-xset` on Arch, `x11-xserver-utils` on Debian/Ubuntu, `xset` on Fedora.

## Notes

- This is a compatibility hack, not a period-correct environment.
- Modern HTTPS is still mostly out of scope. Plain HTTP and very simple sites are the realistic target.
- The launcher writes local `hosts` and `nsswitch.conf` files under `compat/etc/` for the bubblewrap environment.
- `MOZILLA_NO_ASYNC_DNS=True` is enabled by default. Override it if you specifically want to test Communicator's built-in async DNS behavior.

## Compatibility proxies

If you want to reach more of the modern web, run a compatibility proxy on another machine or locally and point Communicator at it as an HTTP proxy.

- WebOne: <https://github.com/atauenis/webone>
- WRP (Web Rendering Proxy): <https://github.com/tenox7/wrp>
