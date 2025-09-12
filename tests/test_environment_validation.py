#!/usr/bin/env python3
"""
Environment Validation Tests for IRC.atl.chat

This test suite validates:
- Environment setup and configuration
- File permissions and accessibility
- Docker services health
- Configuration template processing
- JSON logging functionality
- Directory structure integrity
- Cross-environment compatibility

Run with: python3 tests/test_environment_validation.py
"""

import os
import sys
import json
import time
import subprocess
import socket
import tempfile
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import unittest
from unittest.mock import patch


class EnvironmentValidator:
    """Main environment validation class"""

    def __init__(self, project_root: str = None):
        self.project_root = Path(project_root or os.getcwd()).resolve()
        self.results = {}
        self.errors = []
        self.warnings = []

    def log_result(
        self, test_name: str, success: bool, message: str = "", error: str = ""
    ):
        """Log test result"""
        self.results[test_name] = {
            "success": success,
            "message": message,
            "error": error,
        }

        status = "✅" if success else "❌"
        print(f"{status} {test_name}: {message}")

        if error:
            print(f"   Error: {error}")
            self.errors.append(f"{test_name}: {error}")

    def log_warning(self, message: str):
        """Log warning message"""
        print(f"⚠️  Warning: {message}")
        self.warnings.append(message)


class DirectoryStructureTests(EnvironmentValidator):
    """Test directory structure and permissions"""

    def test_required_directories_exist(self):
        """Test that all required directories exist"""
        required_dirs = [
            "data/unrealircd",
            "data/atheme",
            "logs/unrealircd",
            "logs/atheme",
            "src/backend/unrealircd/conf",
            "src/backend/atheme/conf",
            "scripts",
            "tests",
        ]

        missing_dirs = []
        for dir_path in required_dirs:
            full_path = self.project_root / dir_path
            if not full_path.exists():
                missing_dirs.append(dir_path)

        if missing_dirs:
            self.log_result(
                "Directory Structure",
                False,
                f"Missing directories: {', '.join(missing_dirs)}",
            )
        else:
            self.log_result(
                "Directory Structure",
                True,
                f"All {len(required_dirs)} required directories exist",
            )

    def test_directory_permissions(self):
        """Test directory permissions are correct"""
        test_dirs = ["data/unrealircd", "data/atheme", "logs/unrealircd", "logs/atheme"]

        permission_issues = []
        for dir_path in test_dirs:
            full_path = self.project_root / dir_path
            if full_path.exists():
                # Test if directory is writable
                test_file = full_path / ".write_test"
                try:
                    test_file.touch()
                    test_file.unlink()
                except (PermissionError, OSError) as e:
                    permission_issues.append(f"{dir_path}: {e}")

        if permission_issues:
            self.log_result(
                "Directory Permissions",
                False,
                "Permission issues found",
                "; ".join(permission_issues),
            )
        else:
            self.log_result(
                "Directory Permissions",
                True,
                f"All {len(test_dirs)} directories are writable",
            )

    def test_config_directory_ownership(self):
        """Test config directories have correct ownership"""
        config_dirs = ["src/backend/unrealircd/conf", "src/backend/atheme/conf"]

        ownership_issues = []
        current_uid = os.getuid()

        for dir_path in config_dirs:
            full_path = self.project_root / dir_path
            if full_path.exists():
                stat_info = full_path.stat()
                if stat_info.st_uid != current_uid:
                    ownership_issues.append(
                        f"{dir_path}: owned by UID {stat_info.st_uid}, expected {current_uid}"
                    )

                # Test write access
                try:
                    test_file = full_path / ".ownership_test"
                    test_file.touch()
                    test_file.unlink()
                except (PermissionError, OSError) as e:
                    ownership_issues.append(f"{dir_path}: write test failed - {e}")

        if ownership_issues:
            self.log_result(
                "Config Directory Ownership",
                False,
                "Ownership issues found",
                "; ".join(ownership_issues),
            )
        else:
            self.log_result(
                "Config Directory Ownership",
                True,
                "Config directories have correct ownership and are writable",
            )


class ConfigurationTests(EnvironmentValidator):
    """Test configuration files and templates"""

    def test_environment_file_exists(self):
        """Test .env file exists and is readable"""
        env_file = self.project_root / ".env"
        env_example = self.project_root / "env.example"

        if env_file.exists():
            try:
                with open(env_file, "r") as f:
                    content = f.read()
                self.log_result(
                    "Environment File",
                    True,
                    f".env file exists and is readable ({len(content)} bytes)",
                )
            except Exception as e:
                self.log_result(
                    "Environment File",
                    False,
                    ".env file exists but cannot be read",
                    str(e),
                )
        elif env_example.exists():
            self.log_result(
                "Environment File",
                True,
                ".env not found but env.example exists (acceptable for first run)",
            )
        else:
            self.log_result(
                "Environment File", False, "Neither .env nor env.example found"
            )

    def test_template_files_exist(self):
        """Test configuration template files exist"""
        templates = [
            "src/backend/unrealircd/conf/unrealircd.conf.template",
            "src/backend/atheme/conf/atheme.conf.template",
        ]

        missing_templates = []
        for template_path in templates:
            full_path = self.project_root / template_path
            if not full_path.exists():
                missing_templates.append(template_path)

        if missing_templates:
            self.log_result(
                "Template Files",
                False,
                f"Missing templates: {', '.join(missing_templates)}",
            )
        else:
            self.log_result(
                "Template Files", True, f"All {len(templates)} template files exist"
            )

    def test_generated_config_files(self):
        """Test that generated config files exist and are valid"""
        configs = [
            "src/backend/unrealircd/conf/unrealircd.conf",
            "src/backend/atheme/conf/atheme.conf",
        ]

        config_issues = []
        for config_path in configs:
            full_path = self.project_root / config_path
            if not full_path.exists():
                config_issues.append(f"{config_path}: file does not exist")
                continue

            try:
                with open(full_path, "r") as f:
                    content = f.read()

                # Check if file contains unexpanded variables
                if "${" in content:
                    unexpanded = [
                        line.strip() for line in content.split("\n") if "${" in line
                    ][:3]  # First 3 examples
                    config_issues.append(
                        f"{config_path}: contains unexpanded variables: {unexpanded}"
                    )

                # Check file is not empty
                if len(content.strip()) < 100:
                    config_issues.append(
                        f"{config_path}: file seems too small ({len(content)} bytes)"
                    )

            except Exception as e:
                config_issues.append(f"{config_path}: read error - {e}")

        if config_issues:
            self.log_result(
                "Generated Configs",
                False,
                "Configuration issues found",
                "; ".join(config_issues),
            )
        else:
            self.log_result(
                "Generated Configs", True, f"All {len(configs)} config files are valid"
            )


class DockerEnvironmentTests(EnvironmentValidator):
    """Test Docker environment and services"""

    def test_docker_availability(self):
        """Test Docker is available and working"""
        try:
            result = subprocess.run(
                ["docker", "--version"], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                version = result.stdout.strip()
                self.log_result(
                    "Docker Availability", True, f"Docker available: {version}"
                )
            else:
                self.log_result(
                    "Docker Availability", False, "Docker command failed", result.stderr
                )
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            self.log_result(
                "Docker Availability", False, "Docker not available", str(e)
            )

    def test_docker_compose_availability(self):
        """Test Docker Compose is available"""
        try:
            result = subprocess.run(
                ["docker", "compose", "version"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                version = result.stdout.strip()
                self.log_result(
                    "Docker Compose", True, f"Docker Compose available: {version}"
                )
            else:
                self.log_result(
                    "Docker Compose",
                    False,
                    "Docker Compose command failed",
                    result.stderr,
                )
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            self.log_result(
                "Docker Compose", False, "Docker Compose not available", str(e)
            )

    def test_compose_config_validity(self):
        """Test Docker Compose configuration is valid"""
        compose_file = self.project_root / "compose.yaml"
        if not compose_file.exists():
            self.log_result("Compose Config", False, "compose.yaml not found")
            return

        try:
            result = subprocess.run(
                ["docker", "compose", "config", "--quiet"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=30,
            )
            if result.returncode == 0:
                self.log_result(
                    "Compose Config", True, "Docker Compose configuration is valid"
                )
            else:
                self.log_result(
                    "Compose Config",
                    False,
                    "Docker Compose configuration invalid",
                    result.stderr,
                )
        except subprocess.TimeoutExpired:
            self.log_result(
                "Compose Config", False, "Docker Compose config check timed out"
            )
        except Exception as e:
            self.log_result(
                "Compose Config", False, "Error checking compose config", str(e)
            )

    def test_service_health_status(self):
        """Test running services health status"""
        try:
            result = subprocess.run(
                ["docker", "compose", "ps", "--format", "json"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=15,
            )

            if result.returncode != 0:
                self.log_result(
                    "Service Health", False, "Cannot get service status", result.stderr
                )
                return

            if not result.stdout.strip():
                self.log_result(
                    "Service Health", True, "No services running (this is fine)"
                )
                return

            try:
                services = (
                    json.loads(result.stdout)
                    if result.stdout.strip().startswith("[")
                    else [
                        json.loads(line) for line in result.stdout.strip().split("\n")
                    ]
                )

                running_services = []
                unhealthy_services = []

                for service in services:
                    name = service.get("Name", "unknown")
                    status = service.get("Status", "")

                    running_services.append(name)

                    if "unhealthy" in status.lower():
                        unhealthy_services.append(f"{name}: {status}")

                if unhealthy_services:
                    self.log_result(
                        "Service Health",
                        False,
                        f"Unhealthy services found: {', '.join(unhealthy_services)}",
                    )
                else:
                    self.log_result(
                        "Service Health",
                        True,
                        f"{len(running_services)} services running and healthy",
                    )

            except json.JSONDecodeError as e:
                self.log_result(
                    "Service Health", False, "Cannot parse service status", str(e)
                )

        except subprocess.TimeoutExpired:
            self.log_result("Service Health", False, "Service health check timed out")
        except Exception as e:
            self.log_result(
                "Service Health", False, "Error checking service health", str(e)
            )


class LoggingTests(EnvironmentValidator):
    """Test logging functionality"""

    def test_log_file_accessibility(self):
        """Test log files are accessible from host"""
        log_files = ["logs/unrealircd/ircd.log", "logs/unrealircd/ircd.json.log"]

        accessible_logs = []
        inaccessible_logs = []

        for log_path in log_files:
            full_path = self.project_root / log_path
            if full_path.exists():
                try:
                    with open(full_path, "r") as f:
                        content = f.read(1000)  # Read first 1KB
                    accessible_logs.append(f"{log_path} ({len(content)} bytes preview)")
                except Exception as e:
                    inaccessible_logs.append(f"{log_path}: {e}")
            else:
                # Log file not existing is OK if services aren't running
                accessible_logs.append(f"{log_path} (not created yet - OK)")

        if inaccessible_logs:
            self.log_result(
                "Log File Access",
                False,
                f"Cannot access: {', '.join(inaccessible_logs)}",
            )
        else:
            self.log_result(
                "Log File Access",
                True,
                f"All log files accessible: {len(accessible_logs)} files",
            )

    def test_json_log_format(self):
        """Test JSON log format is valid"""
        json_log = self.project_root / "logs/unrealircd/ircd.json.log"

        if not json_log.exists():
            self.log_result(
                "JSON Log Format",
                True,
                "JSON log file not created yet (OK if services not running)",
            )
            return

        try:
            with open(json_log, "r") as f:
                lines = f.readlines()

            if not lines:
                self.log_result("JSON Log Format", True, "JSON log file empty (OK)")
                return

            valid_json_lines = 0
            invalid_lines = []

            # Test first few and last few lines
            test_lines = lines[:5] + lines[-5:] if len(lines) > 10 else lines

            for i, line in enumerate(test_lines):
                line = line.strip()
                if not line:
                    continue

                try:
                    log_entry = json.loads(line)

                    # Check for required JSON log fields
                    required_fields = ["timestamp", "level", "msg"]
                    missing_fields = [
                        field for field in required_fields if field not in log_entry
                    ]

                    if missing_fields:
                        invalid_lines.append(
                            f"Line {i}: missing fields {missing_fields}"
                        )
                    else:
                        valid_json_lines += 1

                except json.JSONDecodeError as e:
                    invalid_lines.append(f"Line {i}: JSON decode error - {e}")

            if invalid_lines:
                self.log_result(
                    "JSON Log Format",
                    False,
                    f"Invalid JSON found: {', '.join(invalid_lines[:3])}",  # Show first 3
                )
            else:
                self.log_result(
                    "JSON Log Format",
                    True,
                    f"JSON log format valid ({valid_json_lines} entries checked)",
                )

        except Exception as e:
            self.log_result("JSON Log Format", False, "Error reading JSON log", str(e))


class ScriptTests(EnvironmentValidator):
    """Test setup and utility scripts"""

    def test_required_scripts_exist(self):
        """Test all required scripts exist and are executable"""
        required_scripts = [
            "scripts/setup-and-start.sh",
            "scripts/fix-permissions.sh",
            "scripts/init.sh",
            "scripts/prepare-config.sh",
        ]

        script_issues = []
        for script_path in required_scripts:
            full_path = self.project_root / script_path
            if not full_path.exists():
                script_issues.append(f"{script_path}: does not exist")
                continue

            if not os.access(full_path, os.X_OK):
                script_issues.append(f"{script_path}: not executable")

        if script_issues:
            self.log_result(
                "Required Scripts", False, f"Script issues: {', '.join(script_issues)}"
            )
        else:
            self.log_result(
                "Required Scripts",
                True,
                f"All {len(required_scripts)} scripts exist and are executable",
            )

    def test_makefile_targets(self):
        """Test Makefile has required targets"""
        makefile = self.project_root / "Makefile"
        if not makefile.exists():
            self.log_result("Makefile Targets", False, "Makefile not found")
            return

        try:
            with open(makefile, "r") as f:
                content = f.read()

            required_targets = [
                "up",
                "down",
                "help",
                "fix-permissions",
                "setup",
                "start-only",
                "status",
            ]

            missing_targets = []
            for target in required_targets:
                if f"{target}:" not in content:
                    missing_targets.append(target)

            if missing_targets:
                self.log_result(
                    "Makefile Targets",
                    False,
                    f"Missing targets: {', '.join(missing_targets)}",
                )
            else:
                self.log_result(
                    "Makefile Targets",
                    True,
                    f"All {len(required_targets)} required targets found",
                )

        except Exception as e:
            self.log_result("Makefile Targets", False, "Error reading Makefile", str(e))


class ConnectivityTests(EnvironmentValidator):
    """Test network connectivity and ports"""

    def test_irc_port_accessibility(self):
        """Test IRC ports are accessible"""
        ports_to_test = [
            (6667, "IRC Standard"),
            (6697, "IRC SSL/TLS"),
            (8080, "Web Panel"),
        ]

        accessible_ports = []
        inaccessible_ports = []

        for port, description in ports_to_test:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(2)
                result = sock.connect_ex(("localhost", port))
                sock.close()

                if result == 0:
                    accessible_ports.append(f"{port} ({description})")
                else:
                    inaccessible_ports.append(f"{port} ({description})")

            except Exception as e:
                inaccessible_ports.append(f"{port} ({description}): {e}")

        # If no services are running, this is OK
        if not accessible_ports and not any(
            "Connection refused" in str(port) for port in inaccessible_ports
        ):
            self.log_result(
                "Port Accessibility",
                True,
                "No services running - ports not accessible (OK)",
            )
        elif accessible_ports:
            self.log_result(
                "Port Accessibility",
                True,
                f"Accessible ports: {', '.join(accessible_ports)}",
            )
        else:
            self.log_result(
                "Port Accessibility",
                False,
                f"No accessible ports: {', '.join(inaccessible_ports)}",
            )


def run_all_tests(project_root: str = None) -> Tuple[int, int, List[str], List[str]]:
    """Run all environment validation tests"""

    print("🔍 IRC.atl.chat Environment Validation")
    print("=" * 50)

    test_classes = [
        DirectoryStructureTests,
        ConfigurationTests,
        DockerEnvironmentTests,
        LoggingTests,
        ScriptTests,
        ConnectivityTests,
    ]

    all_results = {}
    all_errors = []
    all_warnings = []

    for test_class in test_classes:
        print(f"\n📋 Running {test_class.__name__}...")
        tester = test_class(project_root)

        # Run all test methods
        for method_name in dir(tester):
            if method_name.startswith("test_"):
                try:
                    method = getattr(tester, method_name)
                    method()
                except Exception as e:
                    tester.log_result(method_name, False, "Test error", str(e))

        all_results.update(tester.results)
        all_errors.extend(tester.errors)
        all_warnings.extend(tester.warnings)

    # Summary
    print("\n" + "=" * 50)
    print("📊 ENVIRONMENT VALIDATION SUMMARY")
    print("=" * 50)

    passed = sum(1 for result in all_results.values() if result["success"])
    total = len(all_results)

    for test_name, result in all_results.items():
        status = "✅ PASSED" if result["success"] else "❌ FAILED"
        print(f"{test_name:<30} {status}")

    print("-" * 50)
    print(f"Total: {passed}/{total} tests passed ({passed / total * 100:.1f}%)")

    if all_warnings:
        print(f"\n⚠️  {len(all_warnings)} warnings:")
        for warning in all_warnings[:5]:  # Show first 5
            print(f"   • {warning}")

    if all_errors:
        print(f"\n❌ {len(all_errors)} errors:")
        for error in all_errors[:5]:  # Show first 5
            print(f"   • {error}")

    if passed == total:
        print("\n🎉 All environment validation tests passed!")
        print("Your IRC server environment is properly configured.")
    else:
        print(f"\n⚠️  {total - passed} test(s) failed.")
        print("Some environment issues need attention.")

    return passed, total, all_errors, all_warnings


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Validate IRC.atl.chat environment setup"
    )
    parser.add_argument(
        "--project-root",
        default=None,
        help="Project root directory (default: current directory)",
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")

    args = parser.parse_args()

    try:
        passed, total, errors, warnings = run_all_tests(args.project_root)

        if args.verbose:
            if errors:
                print("\n🔍 Detailed Errors:")
                for error in errors:
                    print(f"   {error}")
            if warnings:
                print("\n🔍 Detailed Warnings:")
                for warning in warnings:
                    print(f"   {warning}")

        # Exit code: 0 if all passed, 1 if some failed, 2 if major issues
        if passed == total:
            return 0
        elif passed >= total * 0.8:  # 80% pass rate
            return 1
        else:
            return 2

    except KeyboardInterrupt:
        print("\n⏹️  Tests interrupted by user")
        return 130
    except Exception as e:
        print(f"\n💥 Test runner error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
