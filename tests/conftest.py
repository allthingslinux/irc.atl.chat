"""Test configuration and shared fixtures for IRC.atl.chat testing."""

import pytest
import docker
import requests
import os
import time
from pathlib import Path
from typing import Generator, Optional


@pytest.fixture(scope="session")
def docker_client() -> docker.DockerClient:
    """Provide a Docker client for testing."""
    try:
        client = docker.from_env()
        # Test that Docker is available
        client.ping()
        return client
    except docker.errors.DockerException as e:
        pytest.skip(f"Docker not available: {e}")


# pytest-docker fixtures (automatic Docker Compose management)
@pytest.fixture(scope="session")
def docker_compose_file(pytestconfig):
    """Override default docker-compose.yml location."""
    import os

    return os.path.join(str(pytestconfig.rootdir), "compose.yaml")


@pytest.fixture(scope="session")
def docker_compose_project_name():
    """Generate unique project name for tests."""
    import uuid

    return f"irc_atl_test_{uuid.uuid4().hex[:8]}"


@pytest.fixture(scope="session")
def docker_setup():
    """Docker compose commands to run before tests."""
    return ["down -v", "up --build -d"]


@pytest.fixture(scope="session")
def docker_cleanup():
    """Docker compose commands to run after tests."""
    return ["down -v"]


def is_irc_service_responsive(host, port=6667):
    """Check if IRC service is responsive."""
    import socket

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except Exception:
        return False


@pytest.fixture(scope="session")
def irc_service(docker_ip, docker_services):
    """Ensure IRC service is up and responsive."""
    port = docker_services.port_for("unrealircd", 6667)
    url = f"{docker_ip}:{port}"

    docker_services.wait_until_responsive(
        timeout=60.0, pause=1.0, check=lambda: is_irc_service_responsive(docker_ip, port)
    )
    return url


@pytest.fixture(scope="session")
def project_root() -> Path:
    """Get the project root directory."""
    return Path(__file__).parent.parent


@pytest.fixture(scope="session")
def compose_file(project_root: Path) -> Path:
    """Get the docker-compose file path."""
    return project_root / "compose.yaml"


@pytest.fixture
def temp_dir(tmp_path: Path) -> Path:
    """Provide a temporary directory for tests."""
    return tmp_path


@pytest.fixture
def sample_config_data() -> dict:
    """Provide sample configuration data for testing."""
    return {
        "irc_server": {
            "host": "localhost",
            "port": 6667,
            "ssl_port": 6697,
            "network_name": "test.network",
        },
        "services": {
            "atheme": {"enabled": True, "port": 8080},
            "webpanel": {"enabled": True, "port": 8081},
        },
    }


@pytest.fixture
def mock_docker_container(mocker):
    """Mock Docker container for testing."""
    mock_container = mocker.Mock()
    mock_container.name = "test_container"
    mock_container.status = "running"
    mock_container.logs.return_value = [b"Test log output"]
    return mock_container


@pytest.fixture
def mock_requests_get(mocker):
    """Mock requests.get for testing HTTP calls."""
    mock_response = mocker.Mock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"status": "ok"}
    mock_response.text = "OK"

    mock_get = mocker.patch("requests.get")
    mock_get.return_value = mock_response
    return mock_get


class DockerComposeHelper:
    """Helper class for Docker Compose operations in tests."""

    def __init__(self, compose_file: Path, project_root: Path):
        self.compose_file = compose_file
        self.project_root = project_root

    def is_service_running(self, service_name: str) -> bool:
        """Check if a service is running."""
        try:
            import subprocess

            result = subprocess.run(
                ["docker", "compose", "ps", service_name],
                cwd=self.project_root,
                capture_output=True,
                text=True,
            )
            return "Up" in result.stdout
        except Exception:
            return False

    def get_service_logs(self, service_name: str, tail: int = 50) -> str:
        """Get logs from a service."""
        try:
            import subprocess

            result = subprocess.run(
                ["docker", "compose", "logs", "--tail", str(tail), service_name],
                cwd=self.project_root,
                capture_output=True,
                text=True,
            )
            return result.stdout
        except Exception:
            return ""


@pytest.fixture
def docker_compose_helper(compose_file: Path, project_root: Path) -> DockerComposeHelper:
    """Provide a Docker Compose helper for tests."""
    return DockerComposeHelper(compose_file, project_root)


class IRCTestHelper:
    """Helper class for IRC-related testing operations."""

    def __init__(self, host: str = "localhost", port: int = 6667):
        self.host = host
        self.port = port

    def wait_for_irc_server(self, timeout: int = 30) -> bool:
        """Wait for IRC server to be ready."""
        import socket

        start_time = time.time()

        while time.time() - start_time < timeout:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(1)
                result = sock.connect_ex((self.host, self.port))
                sock.close()

                if result == 0:
                    return True

            except Exception:
                pass

            time.sleep(1)

        return False

    def send_irc_command(self, command: str) -> Optional[str]:
        """Send a command to the IRC server and get response."""
        import socket

        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            sock.connect((self.host, self.port))

            sock.send(f"{command}\r\n".encode())

            response = sock.recv(4096).decode()
            sock.close()

            return response

        except Exception:
            return None


@pytest.fixture
def irc_helper() -> IRCTestHelper:
    """Provide an IRC test helper."""
    return IRCTestHelper()


@pytest.fixture
def mock_irc_connection(mocker):
    """Mock IRC connection for testing."""
    mock_conn = mocker.Mock()
    mock_conn.connect.return_value = True
    mock_conn.send.return_value = None
    mock_conn.receive.return_value = ":server 001 test :Welcome to IRC"
    return mock_conn


class MockIRCClient:
    """Mock IRC client for testing."""

    def __init__(self):
        self.connected = False
        self.messages = []

    def connect(self):
        """Mock connection to IRC server."""
        self.connected = True
        return True

    def send(self, command):
        """Mock sending command."""
        self.messages.append(command)
        return True

    def wait_for_message(self, code=None):
        """Mock waiting for specific message."""
        if code == "001":
            return ":server 001 nick :Welcome to IRC"
        elif code == "432":
            return ":server 432 nick :Erroneous nickname"
        return None

    def disconnect(self):
        """Mock disconnect."""
        self.connected = False


@pytest.fixture
def irc_client():
    """Provide a mock IRC client for testing."""
    return MockIRCClient()


# Configuration for different test environments
@pytest.fixture(params=["minimal", "full"])
def test_config(request, sample_config_data):
    """Provide different test configurations."""
    if request.param == "minimal":
        return {k: v for k, v in sample_config_data.items() if k == "irc_server"}
    return sample_config_data


# Cleanup fixture for tests that create files/directories
@pytest.fixture
def cleanup_files():
    """Fixture to track and cleanup files created during tests."""
    created_files = []
    created_dirs = []

    def track_file(path: Path):
        created_files.append(path)

    def track_dir(path: Path):
        created_dirs.append(path)

    yield track_file, track_dir

    # Cleanup
    for file_path in created_files:
        if file_path.exists():
            file_path.unlink()

    for dir_path in created_dirs:
        if dir_path.exists():
            import shutil

            shutil.rmtree(dir_path)


# Environment setup fixture
@pytest.fixture(scope="session", autouse=True)
def setup_test_environment(project_root: Path, tmp_path_factory):
    """Setup test environment variables and configuration."""
    # Set test environment
    os.environ.setdefault("TESTING", "true")
    os.environ.setdefault("DOCKER_COMPOSE_FILE", str(project_root / "compose.yaml"))

    # Create temporary test directories that get cleaned up automatically
    temp_test_root = tmp_path_factory.mktemp("irc_atl_test")

    # Create temporary test directories
    test_dirs = {
        "data": temp_test_root / "data",
        "logs": temp_test_root / "logs",
        "temp": temp_test_root / "temp",
    }

    for test_dir in test_dirs.values():
        test_dir.mkdir(parents=True, exist_ok=True)

    yield

    # Cleanup test environment
    test_env_vars = ["TESTING", "DOCKER_COMPOSE_FILE"]
    for var in test_env_vars:
        os.environ.pop(var, None)
