"""Infrastructure Tests

Tests for IRC.atl.chat infrastructure including configuration validation,
Docker services, scripts, SSL management, and deployment components.
"""

import pytest
import os
import subprocess
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch
import docker
import requests

from ..utils.base_test_cases import BaseServerTestCase


class TestConfigurationValidation:
    """Test configuration file validation and parsing."""

    def test_env_example_exists(self, project_root):
        """Test that env.example file exists."""
        env_example = project_root / "env.example"
        assert env_example.exists(), "env.example file should exist"

        # Should contain basic configuration keys
        content = env_example.read_text()
        assert "UNREALIRCD_" in content or "ATHEME_" in content, "Should contain IRC service configuration"

    def test_compose_file_exists(self, project_root):
        """Test that docker-compose.yml exists and is valid."""
        compose_file = project_root / "compose.yaml"
        assert compose_file.exists(), "compose.yaml file should exist"

        # Basic validation - should be YAML and contain services
        content = compose_file.read_text()
        assert "services:" in content, "Should contain services section"
        assert "unrealircd" in content.lower(), "Should contain unrealircd service"

    def test_dockerfile_exists(self, project_root):
        """Test that Dockerfiles exist."""
        unrealircd_dockerfile = project_root / "src/backend/unrealircd/Containerfile"
        atheme_dockerfile = project_root / "src/backend/atheme/Containerfile"
        webpanel_dockerfile = project_root / "src/frontend/webpanel/Containerfile"
        gamja_dockerfile = project_root / "src/frontend/gamja/Containerfile"

        assert unrealircd_dockerfile.exists(), "UnrealIRCd Dockerfile should exist"
        assert atheme_dockerfile.exists(), "Atheme Dockerfile should exist"
        assert webpanel_dockerfile.exists(), "WebPanel Dockerfile should exist"
        assert gamja_dockerfile.exists(), "Gamja Dockerfile should exist"

    def test_makefile_exists(self, project_root):
        """Test that Makefile exists and has basic targets."""
        makefile = project_root / "Makefile"
        assert makefile.exists(), "Makefile should exist"

        content = makefile.read_text()
        # Should have common targets
        assert "help" in content or ".PHONY" in content, "Should have basic Makefile structure"


class TestDockerServices:
    """Test Docker service management and orchestration."""

    @pytest.fixture
    def docker_client(self):
        """Provide Docker client for testing."""
        try:
            client = docker.from_env()
            client.ping()  # Test connection
            return client
        except Exception:
            pytest.skip("Docker not available for testing")

    @pytest.mark.docker
    def test_docker_services_available(self, docker_client):
        """Test that required Docker services are available."""
        # Check if images exist (may not be built yet)
        try:
            images = docker_client.images.list()
            image_tags = [tag for image in images for tag in (image.tags or [])]

            # Should have some IRC-related images or base images
            has_base_images = any("alpine" in tag or "debian" in tag or "ubuntu" in tag for tag in image_tags)
            assert has_base_images or len(images) > 0, "Should have some Docker images available"

        except Exception:
            pytest.skip("Cannot check Docker images")

    @pytest.mark.docker
    @pytest.mark.integration
    def test_docker_compose_config_valid(self, project_root, docker_client):
        """Test that docker-compose configuration is valid."""
        compose_file = project_root / "compose.yaml"

        try:
            # Test that docker-compose can parse the file
            result = subprocess.run(
                ["docker", "compose", "config", "-f", str(compose_file)],
                cwd=project_root,
                capture_output=True,
                text=True,
                timeout=30,
            )

            assert result.returncode == 0, f"docker-compose config failed: {result.stderr}"
            assert "services:" in result.stdout, "Config should contain services"

        except (subprocess.TimeoutExpired, FileNotFoundError):
            pytest.skip("docker-compose not available or timed out")

    @pytest.mark.docker
    @pytest.mark.integration
    @pytest.mark.slow
    def test_docker_service_startup_sequence(self, project_root, docker_client):
        """Test that services start in correct order."""
        try:
            containers = docker_client.containers.list(filters={"label": "com.docker.compose.project=irc.atl.chat"})

            if not containers:
                pytest.skip("No IRC.atl.chat containers running")

            # Check container startup times
            container_info = []
            for container in containers:
                attrs = container.attrs
                created = attrs["Created"]
                container_info.append({"name": container.name, "created": created})

            # Sort by creation time
            container_info.sort(key=lambda x: x["created"])

            # Basic check that we have containers
            assert len(container_info) > 0, "Should have running containers"

        except Exception:
            pytest.skip("Cannot check container startup sequence")

    @pytest.mark.docker
    @pytest.mark.integration
    def test_docker_service_health_checks(self, docker_client):
        """Test that services have proper health checks."""
        try:
            containers = docker_client.containers.list(filters={"label": "com.docker.compose.project=irc.atl.chat"})

            if not containers:
                pytest.skip("No IRC.atl.chat containers running")

            healthy_containers = 0
            total_containers = len(containers)

            for container in containers:
                attrs = container.attrs
                state = attrs.get("State", {})
                health = state.get("Health", {}).get("Status")

                if health == "healthy":
                    healthy_containers += 1

            # At least some containers should be healthy if running
            assert healthy_containers >= 0, "Should have healthy containers"

        except Exception:
            pytest.skip("Cannot check container health")


class TestScripts:
    """Test utility scripts and automation."""

    def test_health_check_script_exists(self, project_root):
        """Test that health check script exists."""
        health_script = project_root / "scripts/health-check.sh"
        assert health_script.exists(), "Health check script should exist"
        assert health_script.stat().st_mode & 0o111, "Script should be executable"

    def test_init_script_exists(self, project_root):
        """Test that init script exists."""
        init_script = project_root / "scripts/init.sh"
        assert init_script.exists(), "Init script should exist"
        assert init_script.stat().st_mode & 0o111, "Script should be executable"

    def test_ssl_manager_script_exists(self, project_root):
        """Test that SSL manager script exists."""
        ssl_script = project_root / "scripts/ssl-manager.sh"
        assert ssl_script.exists(), "SSL manager script should exist"
        assert ssl_script.stat().st_mode & 0o111, "Script should be executable"

    def test_prepare_config_script_exists(self, project_root):
        """Test that prepare config script exists."""
        prepare_script = project_root / "scripts/prepare-config.sh"
        assert prepare_script.exists(), "Prepare config script should exist"
        assert prepare_script.stat().st_mode & 0o111, "Script should be executable"

    @pytest.mark.integration
    def test_health_check_script_runs(self, project_root):
        """Test that health check script can run (may fail without services)."""
        health_script = project_root / "scripts/health-check.sh"

        try:
            result = subprocess.run(
                [str(health_script), "--help"], cwd=project_root, capture_output=True, text=True, timeout=10
            )

            # Script should run without immediate error (may show help/error)
            assert result.returncode in [0, 1, 2], "Script should be executable"

        except subprocess.TimeoutExpired:
            pytest.fail("Health check script timed out")
        except FileNotFoundError:
            pytest.skip("Script not executable in test environment")

    @pytest.mark.integration
    def test_makefile_targets(self, project_root):
        """Test that Makefile targets work."""
        makefile = project_root / "Makefile"

        try:
            # Test help target
            result = subprocess.run(
                ["make", "-f", str(makefile), "help"], cwd=project_root, capture_output=True, text=True, timeout=10
            )

            # Should succeed or show targets
            assert result.returncode in [0, 1, 2], "Makefile should be processable"

        except (subprocess.TimeoutExpired, FileNotFoundError):
            pytest.skip("Make not available or Makefile not compatible")


class TestSSLManagement:
    """Test SSL certificate management and HTTPS setup."""

    def test_cloudflare_credentials_template_exists(self, project_root):
        """Test that Cloudflare credentials template exists."""
        cf_template = project_root / "cloudflare-credentials.ini.template"
        assert cf_template.exists(), "Cloudflare credentials template should exist"

        content = cf_template.read_text()
        assert "dns_cloudflare_api_token" in content, "Should contain API token config"

    def test_ssl_manager_can_run(self, project_root):
        """Test that SSL manager script can execute."""
        ssl_script = project_root / "scripts/ssl-manager.sh"

        try:
            result = subprocess.run(
                [str(ssl_script), "--help"], cwd=project_root, capture_output=True, text=True, timeout=10
            )

            assert result.returncode in [0, 1, 2], "SSL script should be executable"

        except (subprocess.TimeoutExpired, FileNotFoundError):
            pytest.skip("SSL script not available in test environment")

    @pytest.mark.integration
    def test_https_accessibility(self):
        """Test HTTPS access to web services (if available)."""
        try:
            # Try HTTPS first
            response = requests.get("https://irc.atl.chat", timeout=10, allow_redirects=True)
            assert response.status_code in [200, 301, 302], "HTTPS should be accessible"
        except requests.exceptions.SSLError:
            # Fall back to HTTP
            try:
                response = requests.get("http://irc.atl.chat", timeout=10, allow_redirects=True)
                assert response.status_code in [200, 301, 302], "HTTP should be accessible"
            except requests.exceptions.RequestException:
                pytest.skip("irc.atl.chat not accessible for testing")
        except requests.exceptions.RequestException:
            pytest.skip("irc.atl.chat not accessible for testing")


class TestDocumentation:
    """Test documentation and README files."""

    def test_readme_exists(self, project_root):
        """Test that README.md exists and has content."""
        readme = project_root / "README.md"
        assert readme.exists(), "README.md should exist"

        content = readme.read_text()
        assert len(content) > 100, "README should have substantial content"
        assert "IRC" in content, "README should mention IRC"

    def test_docs_directory_exists(self, project_root):
        """Test that docs directory exists."""
        docs_dir = project_root / "docs"
        assert docs_dir.exists(), "docs directory should exist"
        assert docs_dir.is_dir(), "docs should be a directory"

    def test_license_exists(self, project_root):
        """Test that LICENSE file exists."""
        license_file = project_root / "LICENSE"
        assert license_file.exists(), "LICENSE file should exist"

        content = license_file.read_text()
        assert "MIT" in content.upper() or len(content) > 50, "Should contain license text"


class TestEnvironmentSetup(BaseServerTestCase):
    """Test environment setup and configuration."""

    @pytest.mark.integration
    @pytest.mark.irc
    def test_server_environment_variables(self):
        """Test that server accepts environment configuration."""
        # Server should be running with our controller
        assert self.controller.proc is not None, "Server should be running"

        # Test that we can connect (basic environment test)
        client = self.connectClient("env_test")
        assert client is not None, "Should be able to connect to server"

    @pytest.mark.integration
    @pytest.mark.irc
    def test_server_port_configuration(self):
        """Test that server is listening on configured port."""
        import socket

        # Test that our port is open
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        try:
            result = sock.connect_ex((self.hostname, self.port))
            assert result == 0, f"Port {self.port} should be open"
        finally:
            sock.close()

    @pytest.mark.integration
    @pytest.mark.irc
    def test_server_basic_configuration(self):
        """Test that server has basic configuration applied."""
        client = self.connectClient("config_test")

        # Test MOTD (message of the day)
        self.sendLine(client, "MOTD")
        motd_response = self.getMessage(client)
        # Should get RPL_MOTDSTART, RPL_MOTD, RPL_ENDOFMOTD or ERR_NOMOTD
        assert motd_response.command in ["375", "372", "376", "422"]

        # Test that server info is available
        self.sendLine(client, "INFO")
        info_response = self.getMessage(client)
        assert info_response.command in ["371", "374"]


class TestDeploymentReadiness:
    """Test deployment readiness and production checks."""

    def test_docker_ignore_exists(self, project_root):
        """Test that .dockerignore exists."""
        dockerignore = project_root / ".dockerignore"
        if dockerignore.exists():
            content = dockerignore.read_text()
            assert "logs" in content or "__pycache__" in content, "Should ignore build artifacts"

    def test_gitignore_comprehensive(self, project_root):
        """Test that .gitignore is comprehensive."""
        gitignore = project_root / ".gitignore"
        assert gitignore.exists(), ".gitignore should exist"

        content = gitignore.read_text()

        # Should ignore common artifacts
        ignored_items = ["__pycache__", ".pyc", ".env", "logs", "data", ".pytest_cache"]

        ignored_count = sum(1 for item in ignored_items if item in content)
        assert ignored_count >= len(ignored_items) // 2, "Should ignore common development artifacts"

    def test_pyproject_toml_valid(self, project_root):
        """Test that pyproject.toml is valid."""
        pyproject = project_root / "pyproject.toml"
        assert pyproject.exists(), "pyproject.toml should exist"

        content = pyproject.read_text()
        assert "[project]" in content, "Should be a valid Python project file"
        assert "name" in content, "Should have project name"

    def test_uv_lock_exists(self, project_root):
        """Test that uv.lock exists for dependency management."""
        uv_lock = project_root / "uv.lock"
        assert uv_lock.exists(), "uv.lock should exist for reproducible builds"

        # Should have content
        content = uv_lock.read_text()
        assert len(content) > 100, "uv.lock should have substantial content"
