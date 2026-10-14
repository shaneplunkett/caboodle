# Unraid VM

## Summary

Unraid server running as a VM on PVE, declared in `terraform/pve-unraid.tf`.

## Updates

Unraid checks for OS and plugin updates and posts them to the homelab
alerts channel through its own Discord webhook, set up under Settings,
Notification Settings, Notification Agents. Updates are applied from its UI.
The notification grid has to have Agents ticked for Notices, Warnings and
Alerts, or Unraid finds updates but never tells Discord.

## Disk health

The monitoring host reads SMART from every Unraid disk over SSH, with its
own key (`unraid-smart-ssh-key` in agenix). On Unraid that key is locked to
one forced command that runs `smartctl` on each disk, so it can't open a
shell or run anything else. Add it again after replacing the USB stick:

```sh
ssh root@<unraid> 'cat >> ~/.ssh/authorized_keys' < modules/services/unraid-smart/authorized_key
```

- **Root's keys live on the flash drive.** `/root/.ssh` links to
  `/boot/config/ssh/root`, which is why the key survives reboots.
- **The disks never spin down**, so reading SMART doesn't wake anything. If
  spin down is ever turned on, add `-n standby` to the forced command, or the
  checks will keep every disk spinning.

## Notes

- Boots from USB, because the Unraid licence key lives on the USB stick
- Uses an `e1000` network adapter (not virtio), because Unraid's boot environment needs it
- The array starts by itself (Disk Settings, Enable auto start), so a PVE
  reboot doesn't leave the shares unavailable
