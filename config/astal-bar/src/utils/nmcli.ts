import { execAsync } from "astal/process"

// nmcli's "this needs a password" failure modes. The error text is parsed by
// the Wi-Fi and VPN connect flows to decide whether to prompt for a secret.
export const NEEDS_SECRETS = /no valid secrets|secrets were required|not given/i

// nmcli localizes its messages via gettext, so on a non-English locale the
// NEEDS_SECRETS match would never fire. Force a C locale for every call whose
// stderr we parse (terse -t data output is locale-independent either way).
export const nmcli = (args: string[]) =>
  execAsync(["env", "LC_ALL=C", "nmcli", ...args])
