#!/usr/bin/env python3
"""Tablet/laptop mode detector for detachable convertibles.

Watches SW_TABLET_MODE and detachable-keyboard presence; on each
confirmed transition runs `apply-mode <mode>` and writes mode-state /
mode-source into XDG_RUNTIME_DIR.

Signals:
    USR1  cycle auto → laptop → tablet → external → auto
    USR2  reset to auto, re-eval from hardware
"""

import errno
import fcntl
import logging
import os
import selectors
import signal
import subprocess
import sys
import time
from pathlib import Path

import evdev
from evdev import ecodes

LOG = logging.getLogger("mode-daemon")
DEBOUNCE_SEC = 0.4
# Substrings matched against /proc/bus/input/devices to decide whether
# the detachable keyboard is currently attached. Pipe-separated.
DETACHABLE_KEYBOARD_HINTS = tuple(
    h for h in os.environ.get("DETACHABLE_KEYBOARD_HINTS", "").split("|") if h
)


class NoTabletHardware(Exception):
    """Raised when no SW_TABLET_MODE input device is present."""

def _eviocgsw(length: int) -> int:
    DIR_READ = 2
    return (DIR_READ << 30) | (length << 16) | (ord('E') << 8) | 0x1b


def read_switch_state(dev: evdev.InputDevice, sw_code: int) -> bool | None:
    nbytes = (ecodes.SW_MAX + 7) // 8
    buf = bytearray(nbytes)
    try:
        fcntl.ioctl(dev.fd, _eviocgsw(nbytes), buf, True)
    except OSError as e:
        LOG.warning("EVIOCGSW failed on %s: %s", dev.path, e)
        return None
    byte = buf[sw_code // 8]
    return bool((byte >> (sw_code % 8)) & 1)


def find_tablet_switch() -> evdev.InputDevice | None:
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
        except OSError as e:
            LOG.debug("skip %s: %s", path, e)
            continue
        caps = d.capabilities()
        sw_codes = caps.get(ecodes.EV_SW, [])
        if ecodes.SW_TABLET_MODE in sw_codes:
            LOG.info("Tablet-mode switch: %s (%s)", d.name, d.path)
            return d
        d.close()
    return None


def detachable_keyboard_present() -> bool:
    if not DETACHABLE_KEYBOARD_HINTS:
        return True  # no hints configured → trust the SW_TABLET_MODE switch alone
    try:
        text = Path("/proc/bus/input/devices").read_text()
    except OSError:
        return True  # undetectable → assume attached
    return any(hint in text for hint in DETACHABLE_KEYBOARD_HINTS)


# A real typing keyboard exposes the whole letter range; power buttons, lid
# switches and media remotes only advertise a handful of EV_KEY codes.
_KEYBOARD_SIGNATURE = (
    ecodes.KEY_A,
    ecodes.KEY_Z,
    ecodes.KEY_M,
    ecodes.KEY_ENTER,
    ecodes.KEY_SPACE,
)
# External keyboards arrive over USB or Bluetooth; this excludes the built-in
# i8042 "AT Translated Set 2 keyboard" that exists even on keyboard-less
# tablets (the folio is on USB too, so it's excluded by name below).
_EXTERNAL_BUSES = (ecodes.BUS_USB, ecodes.BUS_BLUETOOTH)


def external_keyboard_present() -> bool:
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
        except OSError:
            continue
        try:
            if d.info.bustype not in _EXTERNAL_BUSES:
                continue
            keys = d.capabilities().get(ecodes.EV_KEY, [])
            if not all(k in keys for k in _KEYBOARD_SIGNATURE):
                continue
            # The folio is the detachable keyboard, not an external one.
            if any(h in (d.name or "") for h in DETACHABLE_KEYBOARD_HINTS):
                continue
            return True
        finally:
            d.close()
    return False


def write_runtime_mode(mode: str, source: str) -> None:
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime:
        runtime = f"/run/user/{os.getuid()}"
    base = Path(runtime)
    try:
        (base / "mode-state").write_text(mode + "\n")
        (base / "mode-source").write_text(source + "\n")
    except OSError as e:
        LOG.warning("Could not write runtime state files: %s", e)


def apply_mode(mode: str, source: str = "auto") -> None:
    LOG.info("Applying mode: %s (source=%s)", mode, source)
    write_runtime_mode(mode, source)
    try:
        subprocess.run(
            ["apply-mode", mode],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        LOG.error("apply-mode failed: %s", e)


def compute_mode(switch_state: bool, kbd_present: bool, external_kbd: bool) -> str:
    # An external keyboard wins outright: desk use regardless of posture/folio.
    if external_kbd:
        return "external"
    # Tablet if the switch fires OR the folio is gone.
    if switch_state or not kbd_present:
        return "tablet"
    return "laptop"


class ModeDaemon:
    def __init__(self) -> None:
        self.dev = find_tablet_switch()
        if self.dev is None:
            raise NoTabletHardware
        self.sw_state = False
        self.current_mode = "laptop"
        # None = follow hardware; otherwise latched mode.
        self.manual_mode: str | None = None
        self.pending_mode: str | None = None
        self.pending_since: float = 0.0
        self.force_apply = False
        signal.signal(signal.SIGUSR1, self._on_usr1)
        signal.signal(signal.SIGUSR2, self._on_usr2)
        signal.signal(signal.SIGTERM, self._on_term)
        signal.signal(signal.SIGINT, self._on_term)
        self._running = True

    def _source(self) -> str:
        return "manual" if self.manual_mode is not None else "auto"

    def _on_usr1(self, *_a) -> None:
        nxt = {None: "laptop", "laptop": "tablet", "tablet": "external", "external": None}
        self.manual_mode = nxt.get(self.manual_mode)
        LOG.info("USR1: cycle → manual_mode=%s", self.manual_mode)

        if self.manual_mode is None:
            self.force_apply = True
            self._sample_and_maybe_apply(immediate=True)
        else:
            self.current_mode = self.manual_mode
            apply_mode(self.manual_mode, source="manual")
        self.pending_mode = None

    def _on_usr2(self, *_a) -> None:
        LOG.info("USR2: reset to auto")
        self.manual_mode = None
        self.force_apply = True
        self._sample_and_maybe_apply(immediate=True)

    def _on_term(self, *_a) -> None:
        LOG.info("Shutdown requested")
        self._running = False

    def _sample_state(self) -> bool:
        if self.dev is None:
            return False
        s = read_switch_state(self.dev, ecodes.SW_TABLET_MODE)
        if s is None:
            return self.sw_state
        return s

    def _desired(self) -> str:
        return compute_mode(
            self.sw_state,
            detachable_keyboard_present(),
            external_keyboard_present(),
        )

    def _sample_and_maybe_apply(self, immediate: bool = False) -> None:
        self.sw_state = self._sample_state()
        desired = self._desired()
        if desired != self.current_mode or self.force_apply:
            if immediate:
                self.current_mode = desired
                apply_mode(desired, source=self._source())
                self.force_apply = False
            else:
                self.pending_mode = desired
                self.pending_since = time.monotonic()

    def _flush_pending(self) -> None:
        if self.pending_mode is None:
            return
        if (time.monotonic() - self.pending_since) < DEBOUNCE_SEC:
            return
        if self.pending_mode != self.current_mode:
            self.current_mode = self.pending_mode
            apply_mode(self.current_mode, source=self._source())
        self.pending_mode = None

    def run(self) -> int:
        self.sw_state = self._sample_state()
        self.current_mode = self._desired()
        apply_mode(self.current_mode, source=self._source())

        sel = selectors.DefaultSelector()
        if self.dev is not None:
            sel.register(self.dev.fd, selectors.EVENT_READ)
            LOG.info("Watching %s for SW_TABLET_MODE events", self.dev.path)
        else:
            LOG.warning("No SW_TABLET_MODE device — poll-only mode")

        while self._running:
            try:
                events = sel.select(timeout=DEBOUNCE_SEC)
            except (InterruptedError, OSError) as e:
                if getattr(e, "errno", None) == errno.EINTR:
                    continue
                LOG.error("select failed: %s", e)
                time.sleep(1)
                continue

            if events and self.dev is not None:
                try:
                    for ev in self.dev.read():
                        if ev.type == ecodes.EV_SW and ev.code == ecodes.SW_TABLET_MODE:
                            self.sw_state = bool(ev.value)
                            LOG.info("SW_TABLET_MODE → %s", self.sw_state)
                except (BlockingIOError, OSError) as e:
                    LOG.warning("read() failed: %s", e)

            if self.manual_mode is not None:
                self.pending_mode = None
                continue

            desired = self._desired()
            if desired != self.current_mode:
                if self.pending_mode != desired:
                    self.pending_mode = desired
                    self.pending_since = time.monotonic()
                    LOG.debug("Pending transition → %s", desired)
            else:
                self.pending_mode = None

            self._flush_pending()

        return 0


def main() -> int:
    logging.basicConfig(
        level=os.environ.get("MODE_LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%H:%M:%S",
    )
    try:
        return ModeDaemon().run()
    except NoTabletHardware:
        LOG.info("No SW_TABLET_MODE device — not a detachable, exiting.")
        # Re-assert laptop state silently in case a previous buggy run
        # left persistent settings (e.g. gsettings OSK) in tablet state.
        try:
            subprocess.run(
                ["apply-mode", "laptop"],
                check=False,
                env={**os.environ, "MODE_QUIET": "1"},
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass
        return 0


if __name__ == "__main__":
    sys.exit(main())
