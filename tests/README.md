# IRC.atl.chat Test Suite

This directory contains the comprehensive test suite for IRC.atl.chat using pytest and uv.

## Structure

- `unit/` - Unit tests for individual components
- `integration/` - Integration tests for component interactions
- `e2e/` - End-to-end tests for complete workflows
- `utils/` - Test utilities and helper functions
- `fixtures/` - Test fixtures and sample data
- `conftest.py` - Shared pytest fixtures and configuration

## Running Tests

### Using Make (Recommended)
```bash
make test              # Run all tests
make test-unit         # Run unit tests only
make test-integration  # Run integration tests only
make test-cov          # Run tests with coverage
make test-docker       # Run Docker-related tests
```

### Using uv directly
```bash
uv run pytest tests/                    # Run all tests
uv run pytest tests/unit/              # Run unit tests
uv run pytest tests/integration/       # Run integration tests
uv run pytest --cov=src               # Run with coverage
uv run pytest -m docker               # Run Docker tests
uv run pytest -m slow                 # Run slow tests
```

## Test Markers

- `@pytest.mark.unit` - Unit tests
- `@pytest.mark.integration` - Integration tests
- `@pytest.mark.docker` - Tests requiring Docker
- `@pytest.mark.irc` - Tests requiring IRC server
- `@pytest.mark.slow` - Slow-running tests
- `@pytest.mark.network` - Tests requiring network access

## Configuration

Tests are configured via:
- `pyproject.toml` - pytest configuration and dependencies
- `pytest.ini` - Additional pytest settings
- `.coveragerc` - Coverage configuration

## Fixtures

Common fixtures available:
- `docker_client` - Docker API client
- `project_root` - Project root directory
- `compose_file` - Docker Compose file path
- `irc_helper` - IRC connection helper
- `docker_compose_helper` - Docker Compose operations
- `sample_config_data` - Sample configuration data

## Dependencies

Test dependencies are managed via uv and defined in `pyproject.toml` under `[project.optional-dependencies] test`.
