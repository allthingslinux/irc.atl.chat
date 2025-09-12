#!/usr/bin/env python3
"""
Test Runner for IRC.atl.chat

Runs both environment validation and IRC functionality tests.
"""

import sys
import os
import subprocess
import time
from pathlib import Path


def run_command(cmd, description, timeout=60):
    """Run a command and return success status"""
    print(f"\n🔍 {description}")
    print("-" * 50)

    try:
        result = subprocess.run(
            cmd, cwd=Path(__file__).parent.parent, timeout=timeout, text=True
        )

        success = result.returncode == 0
        status = "✅ PASSED" if success else "❌ FAILED"
        print(f"\n{status} {description}")

        return success

    except subprocess.TimeoutExpired:
        print(f"\n⏰ TIMEOUT: {description} took longer than {timeout}s")
        return False
    except Exception as e:
        print(f"\n💥 ERROR: {description} failed with: {e}")
        return False


def main():
    """Run all tests"""
    print("🚀 IRC.atl.chat Comprehensive Test Suite")
    print("=" * 60)
    print("This will run both environment validation and IRC functionality tests.")
    print()

    # Test configurations
    tests = [
        {
            "cmd": [
                sys.executable,
                "tests/test_environment_validation.py",
                "--verbose",
            ],
            "description": "Environment Validation Tests",
            "timeout": 60,
        },
        {
            "cmd": [sys.executable, "tests/test_irc_functionality.py"],
            "description": "IRC Functionality Tests",
            "timeout": 120,
        },
    ]

    results = []

    for test_config in tests:
        success = run_command(
            test_config["cmd"],
            test_config["description"],
            test_config.get("timeout", 60),
        )
        results.append((test_config["description"], success))

        # Brief pause between test suites
        time.sleep(2)

    # Overall summary
    print("\n" + "=" * 60)
    print("📊 COMPREHENSIVE TEST RESULTS")
    print("=" * 60)

    passed = sum(1 for _, success in results if success)
    total = len(results)

    for test_name, success in results:
        status = "✅ PASSED" if success else "❌ FAILED"
        print(f"{test_name:<35} {status}")

    print("-" * 60)
    print(f"Overall: {passed}/{total} test suites passed ({passed / total * 100:.1f}%)")

    if passed == total:
        print("\n🎉 All test suites passed!")
        print("Your IRC server is fully functional and properly configured.")
        return 0
    else:
        print(f"\n⚠️  {total - passed} test suite(s) failed.")
        print("Check the detailed output above for specific issues.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
