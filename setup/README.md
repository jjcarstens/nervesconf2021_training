# Setup

Used when provisioning SD cards for NervesConf training firmware

```sh
fwup /path/to/nerves_livebook_rpi0.fw
```

Ensure this is running

```sh
iex -S mix
```

Connect device via USB gadget. This lib will:

* Detect connected devices and log the hostname to `tmp/found.txt`
* Force the connected device to reboot (So that FS is ready on next boot)
  * logged to `tmp/rebooted.txt`
  * Write `REBOOT` to the `ScrollHat.Display`
* Detects after reboot
  * logs to `tmp/completed.txt`
  * Writes `OK` to the `ScrollHat.Display`
