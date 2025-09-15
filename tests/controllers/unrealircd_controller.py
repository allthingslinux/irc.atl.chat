"""UnrealIRCd controller for testing.

Adapted from irctest's UnrealIRCd controller for our testing infrastructure.
"""

import contextlib
import fcntl
import functools
from pathlib import Path
import shutil
import subprocess
import textwrap
from typing import Callable, ContextManager, Iterator, Optional, Type

from .atheme_controller import AthemeController
from .base_controllers import BaseServerController, DirectoryBasedController


TEMPLATE_CONFIG = """
include "modules.default.conf";
include "operclass.default.conf";
{extras}
include "help/help.conf";

me {{
    name "My.Little.Server";
    info "test server";
    sid "001";
}}
admin {{
    "Bob Smith";
    "bob";
    "email@example.org";
}}
class clients {{
    pingfreq 90;
    maxclients 1000;
    sendq 200k;
    recvq 8000;
}}
class servers {{
    pingfreq 60;
    connfreq 15; /* try to connect every 15 seconds */
    maxclients 10; /* max servers */
    sendq 20M;
}}

allow {{
    mask *;
    class clients;
    maxperip 50;
        {password_field}
}}

listen {{
    ip {hostname};
    port {port};
}}

listen {{
    ip {tls_hostname};
    port {tls_port};
    options {{ tls; }}
        tls-options {{
            certificate "{pem_path}";
            key "{key_path}";
        }};
}}

/* Special SSL/TLS servers-only port for linking */
listen {{
    ip {services_hostname};
    port {services_port};
    options {{ serversonly; }}
}}

link My.Little.Services {{
    incoming {{
        mask *;
    }}
    password "password";
    class servers;
}}
ulines {{
    My.Little.Services;
}}

set {{
    sasl-server My.Little.Services;
    kline-address "example@example.org";
    network-name "ExampleNET";
    default-server "irc.example.org";
    help-channel "#Help";
    cloak-keys {{ "aaaA1"; "bbbB2"; "cccC3"; }}
    options {{
        identd-check;  // Disable it, so it doesn't prefix idents with a tilde
    }}
    anti-flood {{
        // Prevent throttling, especially test_buffering.py which
        // triggers anti-flood with its very long lines
        unknown-users {{
            nick-flood 255:10;
            lag-penalty 1;
            lag-penalty-bytes 10000;
        }}
    }}
    modes-on-join "+H 100:1d";  // Enables CHATHISTORY

    {set_v6only}

}}
tld {{
    mask *;
    motd "{empty_file}";
    botmotd "{empty_file}";
    rules "{empty_file}";
}}

files {{
    tunefile "{empty_file}";
}}

oper "operuser" {{
    password "operpassword";
    mask *;
    class clients;
    operclass netadmin;
}}
"""

SET_V6ONLY = """
// Remove RPL_WHOISSPECIAL used to advertise security groups
whois-details {
    security-groups { everyone none; self none; oper none; }
}

plaintext-policy {
    server warn; // https://www.unrealircd.org/docs/FAQ#server-requires-tls
    oper warn; // https://www.unrealircd.org/docs/FAQ#oper-requires-tls
}

anti-flood {
    everyone {
        connect-flood 255:10;
    }
}
"""


def _filelock(path: Path) -> Callable[[], ContextManager]:
    """Alternative to multiprocessing.Lock that works with pytest-xdist"""

    @contextlib.contextmanager
    def f() -> Iterator[None]:
        with open(path, "a") as fd:
            fcntl.flock(fd.fileno(), fcntl.LOCK_EX)
            yield

    return f


@functools.lru_cache()
def _installed_version() -> int:
    """Get the installed UnrealIRCd version."""
    try:
        output = subprocess.check_output(["unrealircd", "-v"], universal_newlines=True)
        if "UnrealIRCd-5." in output:
            return 5
        elif "UnrealIRCd-6." in output:
            return 6
        else:
            # Default to version 6 features if we can't determine
            return 6
    except (subprocess.CalledProcessError, FileNotFoundError):
        # If unrealircd is not found or fails, assume version 6
        return 6


_UNREALIRCD_BIN = shutil.which("unrealircd")
if _UNREALIRCD_BIN:
    _UNREALIRCD_PREFIX = Path(_UNREALIRCD_BIN).parent.parent

    # Try to keep that lock file specific to this Unrealircd instance
    _LOCK_PATH = _UNREALIRCD_PREFIX / "irc_atl_unrealircd-startstop.lock"
else:
    # unrealircd not found; we are probably going to crash later anyway...
    _LOCK_PATH = Path("/tmp/irc_atl_unrealircd-startstop.lock")

_STARTSTOP_LOCK = _filelock(_LOCK_PATH)


class UnrealircdController(BaseServerController, DirectoryBasedController):
    """Controller for managing UnrealIRCd instances during testing."""

    software_name = "UnrealIRCd"
    supported_sasl_mechanisms = {"PLAIN"}
    supports_sts = False
    services_controller_class = AthemeController

    extban_mute_char = "quiet" if _installed_version() >= 6 else "q"
    software_version = _installed_version()

    def create_config(self) -> None:
        """Create the configuration directory and basic files."""
        super().create_config()
        if self.directory:
            (self.directory / "server.conf").touch()

    def run(
        self,
        hostname: str,
        port: int,
        *,
        password: Optional[str] = None,
        ssl: bool = False,
        run_services: bool = False,
        faketime: Optional[str] = None,
    ) -> None:
        """Start the UnrealIRCd server."""
        if self.proc is not None:
            raise RuntimeError("Server already running")

        self.port = port
        self.hostname = hostname
        self.create_config()

        if _installed_version() >= 6:
            extras = textwrap.dedent(
                """
                include "snomasks.default.conf";
                loadmodule "cloak_md5";
                loadmodule "third/metadata2";
                """
            )
            set_v6only = SET_V6ONLY
        else:
            extras = ""
            set_v6only = ""

        if self.directory:
            # Create empty files for MOTD, etc.
            empty_file = self.directory / "empty.txt"
            with empty_file.open("w") as f:
                f.write("\n")

            password_field = f'password "{password}";' if password else ""

            # Get ports for services
            (services_hostname, services_port) = self.get_hostname_and_port()
            (unused_hostname, unused_port) = self.get_hostname_and_port()

            self.gen_ssl()
            if ssl:
                (tls_hostname, tls_port) = (hostname, port)
                (hostname, port) = (unused_hostname, unused_port)
            else:
                # Unreal refuses to start without TLS enabled
                (tls_hostname, tls_port) = (unused_hostname, unused_port)

            config_content = TEMPLATE_CONFIG.format(
                hostname=hostname,
                port=port,
                services_hostname=services_hostname,
                services_port=services_port,
                tls_hostname=tls_hostname,
                tls_port=tls_port,
                password_field=password_field,
                key_path=self.key_path,
                pem_path=self.pem_path,
                empty_file=empty_file,
                set_v6only=set_v6only,
                extras=extras,
            )

            config_file = self.directory / "unrealircd.conf"
            with config_file.open("w") as f:
                f.write(config_content)

            faketime_cmd = []
            if faketime and shutil.which("faketime"):
                faketime_cmd = ["faketime", "-f", faketime]
                self.faketime_enabled = True

            with _STARTSTOP_LOCK():
                self.proc = self.execute(
                    [
                        *faketime_cmd,
                        "unrealircd",
                        "-t",  # Test configuration
                        "-F",  # Don't fork
                        "-f",
                        config_file,
                    ],
                )
                self.wait_for_port()

        if run_services and self.services_controller_class:
            self.services_controller = self.services_controller_class(self.test_config, self)
            self.services_controller.run(
                protocol="unreal4",
                server_hostname=services_hostname,
                server_port=services_port,
            )

    def kill_proc(self) -> None:
        """Kill the UnrealIRCd process."""
        if self.proc:
            with _STARTSTOP_LOCK():
                self.proc.kill()
                try:
                    self.proc.wait(5)  # wait for it to actually die
                except subprocess.TimeoutExpired:
                    pass  # Already killed
                self.proc = None


def get_unrealircd_controller_class() -> Type[UnrealircdController]:
    """Factory function to get the UnrealIRCd controller class."""
    return UnrealircdController
