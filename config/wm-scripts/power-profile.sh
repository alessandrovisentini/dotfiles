#!/usr/bin/env bash
# power-profile <power-saver|balanced|performance>
# Sets CPU governor, turbo and platform_profile for the bar's performance menu.
# The sysfs knobs are made group-writable by perf-profile-perms.service, so no
# root is needed here.
set -u

case "${1:-}" in
    power-saver) gov=powersave;   turbo=1; pp=low-power ;;
    balanced)    gov=powersave;   turbo=0; pp=balanced ;;
    performance) gov=performance; turbo=0; pp=performance ;;
    *) echo "usage: $0 <power-saver|balanced|performance>" >&2; exit 64 ;;
esac

pf=/sys/firmware/acpi/platform_profile
[[ -w "$pf" ]] && printf '%s\n' "$pp" >"$pf" 2>/dev/null

nt=/sys/devices/system/cpu/intel_pstate/no_turbo
[[ -w "$nt" ]] && printf '%s\n' "$turbo" >"$nt" 2>/dev/null

for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [[ -w "$g" ]] && printf '%s\n' "$gov" >"$g" 2>/dev/null
done
exit 0
