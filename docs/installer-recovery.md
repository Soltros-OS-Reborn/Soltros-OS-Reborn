# Live Installer Recovery

The Live installer keeps its recoverable session data under
`$XDG_RUNTIME_DIR/soltros-installer`. The directory contains:

- `state`: the last completed installer stage;
- `installation.json`: the selected variant, verified source digest, stable
  update reference, build identifier, and installation mode;
- `installation.ks`: the generated Anaconda Kickstart;
- `online-oci`: the verified, digest-pinned online image when the optional update
  path was selected.

The installed metadata initially sets `update_source_configured` to `false`
because Anaconda installs from the ISO-local OCI layout. The first
`soltros update` switches bootc to the recorded signed stable reference and only
then marks the update source configured. Later updates use `bootc upgrade`.

The installer writes online downloads to `online-oci.part` and only renames the
directory after signature and digest verification. Cancellation, signals, and
copy failures remove that partial directory. A failed online update falls back
to the already verified embedded image without changing the selected desktop.

`cancelled` means no installer was started. `failed` means the selector,
preflight, metadata generation, or installer launcher exited unsuccessfully.
`installer-exited` means Anaconda returned control to the Live session; inspect
the Anaconda UI result and `/tmp/anaconda.log` before retrying. Restart the
installer from the desktop icon to create a new Kickstart. Anaconda owns target
disk selection and mount cleanup; never reuse a disk with active Anaconda mounts
until `findmnt /mnt/sysroot /mnt/sysimage` reports no mounted target.
