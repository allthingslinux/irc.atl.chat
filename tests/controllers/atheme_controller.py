"""Atheme services controller for testing.

Adapted from irctest's Atheme controller for our testing infrastructure.
"""

from typing import Optional

from .base_controllers import BaseServicesController, DirectoryBasedController


TEMPLATE_CONFIG = """
me {{
    name "My.Little.Services";
    sid "001";
    description "test services";
    uplink "My.Little.Server";
}}

numeric "001";

connpass {{
    password "password";
}}

log {{
    method {{
        file {{
            filename "{log_file}";
        }}
    }}
    level {{
        all;
    }}
}}

modules {{
    load "modules/protocol/unreal4";
    load "modules/backend/file";
    load "modules/crypto/pbkdf2";
    load "modules/crypto/scram-sha";
}}

database {{
    type "file";
    name "{db_file}";
}}

nickserv {{
    guestnick "Guest";
}}

chanserv {{
    maxchans "100";
}}

operserv {{
    autokill "30";
    akilltime "30";
}}

global {{
    language "en";
}}

serverinfo {{
    name "My.Little.Services";
    description "test services";
    numeric "001";
    reconnect "10";
    netname "ExampleNET";
}}

ulines {{
    "My.Little.Services";
}}
"""


class AthemeController(BaseServicesController, DirectoryBasedController):
    """Controller for managing Atheme services during testing."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.services_hostname: str | None = None
        self.services_port: int | None = None

    def create_config(self) -> None:
        """Create the configuration directory and basic files."""
        super().create_config()
        if self.directory:
            (self.directory / "atheme.conf").touch()

    def run(self, protocol: str, server_hostname: str, server_port: int) -> None:
        """Start the Atheme services."""
        if self.proc is not None:
            raise RuntimeError("Services already running")

        self.services_hostname = server_hostname
        self.services_port = server_port
        self.create_config()

        if self.directory:
            # Create log and database files
            log_file = self.directory / "atheme.log"
            db_file = self.directory / "services.db"

            config_content = TEMPLATE_CONFIG.format(
                log_file=log_file,
                db_file=db_file,
            )

            config_file = self.directory / "atheme.conf"
            with config_file.open("w") as f:
                f.write(config_content)

            self.proc = self.execute(
                [
                    "atheme-services",
                    "-f",
                    config_file,
                    "-p",
                    str(server_port),
                    "-h",
                    server_hostname,
                ]
            )

    def wait_for_services(self) -> None:
        """Wait for Atheme services to be ready."""
        super().wait_for_services()


def get_atheme_controller_class() -> type[AthemeController]:
    """Factory function to get the Atheme controller class."""
    return AthemeController
