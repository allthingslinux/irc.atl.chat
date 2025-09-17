# Development Guide

This guide covers the development workflow, contribution guidelines, and local setup for IRC.atl.chat development.

## Overview

### Development Philosophy

IRC.atl.chat follows modern development practices:

- **Container-first**: All development happens in containers
- **Infrastructure as Code**: Complete environment definition
- **Automated testing**: Comprehensive test coverage
- **Security by design**: Security integrated throughout
- **Documentation-driven**: Docs as first-class deliverables

### Development Environment

#### Prerequisites

- **Docker & Docker Compose**: Container runtime
- **Git**: Version control
- **Modern shell**: Bash/Zsh with standard Unix tools
- **Code editor**: VS Code, Vim, Emacs, etc.
- **Python 3.11+**: For testing and utilities (optional)

#### System Requirements

- **RAM**: 4GB minimum, 8GB recommended
- **Disk**: 10GB free space for containers and data
- **Network**: Stable internet for container downloads
- **OS**: Linux, macOS, or Windows with WSL2

## Local Setup

### Clone Repository

```bash
# Clone with SSH (recommended)
git clone git@github.com:allthingslinux/irc.atl.chat.git
cd irc.atl.chat

# Or with HTTPS
git clone https://github.com/allthingslinux/irc.atl.chat.git
cd irc.atl.chat
```

### Environment Configuration

```bash
# Copy environment template
cp env.example .env

# Edit for local development
vim .env

# Required for development:
PUID=$(id -u)
PGID=$(id -g)
IRC_DOMAIN=localhost
IRC_ROOT_DOMAIN=localhost
LETSENCRYPT_EMAIL=dev@localhost
```

### Development Startup

```bash
# Start full development environment
make up

# Or start with debug logging
DEBUG=1 make up

# Verify services are running
make status
```

### Development URLs

- **IRC Server**: `localhost:6697` (TLS)
- **WebPanel**: `http://localhost:8080`
- **JSON-RPC API**: `localhost:8600`
- **WebSocket**: `localhost:8000`

## Development Workflow

### Branching Strategy

```bash
# Create feature branch
git checkout -b feature/my-feature

# Create bug fix branch
git checkout -b bugfix/issue-number

# Create documentation branch
git checkout -b docs/update-guide
```

#### Branch Naming Conventions

- `feature/description`: New features
- `bugfix/issue-number`: Bug fixes
- `docs/description`: Documentation updates
- `refactor/description`: Code refactoring
- `chore/description`: Maintenance tasks

### Development Cycle

#### 1. Plan and Design

```bash
# Review existing issues
gh issue list

# Create issue for new work
gh issue create --title "Add feature X" --body "Description..."

# Discuss implementation approach
```

#### 2. Local Development

```bash
# Start development environment
make up

# Make changes to code/configuration
vim src/backend/unrealircd/conf/unrealircd.conf.template

# Test changes
make test-unit
make test-integration

# View logs for debugging
make logs-ircd
```

#### 3. Testing

```bash
# Run unit tests
make test-unit

# Run integration tests
make test-integration

# Run full test suite
make test

# Test specific functionality
make test-services
```

#### 4. Code Quality

```bash
# Lint code and configuration
make lint

# Format shell scripts
# (Automatic via pre-commit hooks)

# Security scanning
make test-security
```

#### 5. Documentation

```bash
# Update documentation for changes
vim docs/FEATURE.md

# Test documentation builds
make docs
```

#### 6. Commit and Push

```bash
# Stage changes
git add .

# Commit with conventional format
git commit -m "feat: add new IRC command support

- Add COMMAND implementation
- Update configuration templates
- Add comprehensive tests
- Update documentation

Closes #123"

# Push to branch
git push origin feature/my-feature
```

#### 7. Create Pull Request

```bash
# Create PR
gh pr create --title "Add feature X" \
  --body "Description of changes..." \
  --label "enhancement"

# Or manually via GitHub web interface
```

### Commit Message Format

Follow conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

#### Types

- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Testing
- `chore`: Maintenance

#### Examples

```bash
# Feature commit
feat(auth): add SASL SCRAM-SHA-256 support

- Implement SCRAM-SHA-256 authentication
- Update Atheme configuration
- Add comprehensive tests

# Bug fix commit
fix(ssl): resolve certificate renewal race condition

Certificate renewal could fail under high load due to
concurrent access to Let's Encrypt directory.

- Add file locking during certificate operations
- Improve error handling for renewal failures
- Add tests for concurrent renewal scenarios

Fixes #456

# Documentation commit
docs(api): update JSON-RPC API reference

- Add missing method documentation
- Include request/response examples
- Update authentication section
```

## Code Organization

### Directory Structure

```
irc.atl.chat/
├── src/                    # Source code
│   ├── backend/           # Server components
│   │   ├── unrealircd/    # IRC server
│   │   └── atheme/        # IRC services
│   └── frontend/          # Client interfaces
│       ├── webpanel/      # Admin interface
│       └── gamja/         # Web IRC client
├── tests/                 # Test suite
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   ├── e2e/              # End-to-end tests
│   └── fixtures/         # Test data
├── docs/                 # Documentation
├── scripts/              # Management scripts
├── compose.yaml          # Docker composition
└── pyproject.toml        # Python project config
```

### Configuration Templates

#### Template Structure

```bash
# Template file naming
component.conf.template

# Variable substitution
${VARIABLE_NAME}
${VARIABLE_NAME:-default_value}
```

#### Adding New Variables

```bash
# 1. Add to env.example
NEW_VARIABLE=default_value

# 2. Document in CONFIG.md
## NEW_VARIABLE
# Description of what this variable controls

# 3. Use in templates
setting = "${NEW_VARIABLE}"

# 4. Update tests
# Add validation in test_environment_validation.py
```

### Container Development

#### Building Custom Images

```dockerfile
# In Containerfile
FROM alpine:latest

# Install development tools
RUN apk add --no-cache \
    build-base \
    git \
    vim \
    htop \
    tcpdump

# Development entrypoint
COPY docker-entrypoint.dev.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.dev.sh"]
```

#### Development Entrypoint

```bash
#!/bin/sh
# Development entrypoint script

# Install development dependencies
if [ "$DEVELOPMENT" = "true" ]; then
    apk add --no-cache \
        strace \
        gdb \
        valgrind
fi

# Execute original entrypoint
exec /usr/local/bin/original-entrypoint.sh "$@"
```

## Testing Strategy

### Test Categories

#### Unit Tests

Fast, isolated tests for individual components:

```python
def test_domain_validation():
    """Test domain name validation logic"""
    validator = DomainValidator()

    assert validator.is_valid("irc.example.com")
    assert not validator.is_valid("invalid..domain")

def test_irc_message_parsing():
    """Test IRC message parsing"""
    parser = IRCMessageParser()

    msg = parser.parse(":nick!user@host PRIVMSG #channel :Hello")
    assert msg.command == "PRIVMSG"
    assert msg.params == ["#channel"]
    assert msg.trailing == "Hello"
```

#### Integration Tests

Test component interactions:

```python
def test_nickserv_registration(irc_server, atheme_services):
    """Test NickServ registration workflow"""
    client = IRCClient.connect(irc_server.host, irc_server.port)

    # Register nickname
    client.send("NICKSERV REGISTER password email@example.com")
    response = client.receive()

    assert "nickname registered" in response.lower()

    # Verify in database
    db = atheme_services.get_database()
    user = db.get_user("testuser")
    assert user.email == "email@example.com"
```

#### End-to-End Tests

Complete user journey testing:

```python
def test_user_registration_flow():
    """Test complete user registration and authentication"""
    # Start services
    services = DockerServices()
    services.start()

    try:
        # Connect client
        client = IRCClient()
        client.connect("localhost", 6697, tls=True)

        # Register account
        client.register_account("testuser", "password", "test@example.com")

        # Verify email (mock)
        client.verify_email("verification_code")

        # Authenticate
        client.authenticate("testuser", "password")

        # Join channel
        client.join("#test")

        # Verify successful connection
        assert client.is_connected()
        assert "#test" in client.get_channels()

    finally:
        services.stop()
```

### Running Tests

#### Local Test Execution

```bash
# Run all tests
make test

# Run specific test categories
make test-unit
make test-integration
make test-e2e

# Run with coverage
uv run pytest --cov=src --cov-report=html

# Run specific test file
uv run pytest tests/integration/test_services.py

# Run tests matching pattern
uv run pytest -k "nickserv"
```

#### Debug Testing

```bash
# Debug failing test
uv run pytest --pdb tests/unit/test_config.py::test_domain_validation

# Verbose output
uv run pytest -v -s tests/integration/test_irc_server.py

# Log testing
uv run pytest --log-cli-level=DEBUG
```

### Writing Tests

#### Test File Structure

```python
import pytest
from irc_atl_chat.core import IRCClient, IRCServer

class TestIRCClient:
    """Test IRC client functionality"""

    def test_connection_establishment(self, irc_server):
        """Test basic IRC connection"""
        client = IRCClient()
        client.connect(irc_server.host, irc_server.port)

        assert client.is_connected()
        assert client.get_nickname() is None  # Not set yet

    def test_nickname_registration(self, irc_server):
        """Test nickname registration"""
        client = IRCClient()
        client.connect(irc_server.host, irc_server.port)

        client.set_nickname("testuser")
        assert client.get_nickname() == "testuser"

        # Verify server acknowledgment
        messages = client.get_messages()
        welcome_msg = next((m for m in messages if "001" in str(m)), None)
        assert welcome_msg is not None

    @pytest.mark.parametrize("invalid_nick", [
        "",  # Empty
        "nick with spaces",  # Spaces
        "nick@host",  # Special characters
        "a" * 51,  # Too long
    ])
    def test_invalid_nicknames(self, invalid_nick):
        """Test rejection of invalid nicknames"""
        client = IRCClient()

        with pytest.raises(ValueError):
            client.set_nickname(invalid_nick)
```

#### Test Fixtures

```python
@pytest.fixture(scope="session")
def irc_server():
    """IRC server fixture for testing"""
    server = IRCTestServer()
    server.start()
    yield server
    server.stop()

@pytest.fixture
def irc_client(irc_server):
    """Connected IRC client fixture"""
    client = IRCClient()
    client.connect(irc_server.host, irc_server.port)
    yield client
    client.disconnect()

@pytest.fixture
def sample_user_data():
    """Sample user registration data"""
    return {
        "nickname": "testuser",
        "username": "test",
        "realname": "Test User",
        "password": "securepassword123",
        "email": "test@example.com"
    }
```

## Code Quality

### Linting and Formatting

#### Shell Scripts

```bash
# Lint with shellcheck
shellcheck scripts/*.sh

# Format with shfmt
shfmt -w scripts/*.sh
```

#### Configuration Files

```bash
# YAML linting
yamllint .github/workflows/*.yml

# Docker linting
hadolint src/backend/unrealircd/Containerfile
```

### Pre-commit Hooks

```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run on all files
pre-commit run --all-files

# Update hooks
pre-commit autoupdate
```

#### Pre-commit Configuration

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files

  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.5
    hooks:
      - id: shellcheck

  - repo: https://github.com/scop/pre-commit-shfmt
    rev: v3.7.0
    hooks:
      - id: shfmt
```

## Security Development

### Security-First Approach

#### Input Validation

```python
def validate_nickname(nickname: str) -> bool:
    """Validate IRC nickname format"""
    if not nickname or len(nickname) > 50:
        return False

    # IRC nickname rules: letters, numbers, special chars
    import re
    return bool(re.match(r'^[a-zA-Z\[\]\\\`\^\{\}\|][a-zA-Z0-9\[\]\\\`\^\{\}\|]{0,49}$', nickname))
```

#### Secure Configuration

```bash
# Secure environment file
chmod 600 .env

# Validate configuration on load
def load_config():
    config = load_environment()

    # Validate critical settings
    if not is_valid_domain(config['IRC_DOMAIN']):
        raise ValueError("Invalid IRC_DOMAIN")

    if not is_valid_email(config['LETSENCRYPT_EMAIL']):
        raise ValueError("Invalid LETSENCRYPT_EMAIL")

    return config
```

#### Secret Management

```python
# Secure password generation
def generate_secure_password(length: int = 32) -> str:
    """Generate cryptographically secure password"""
    import secrets
    import string

    alphabet = string.ascii_letters + string.digits + string.punctuation
    return ''.join(secrets.choice(alphabet) for _ in range(length))

# Password hashing
def hash_password(password: str) -> str:
    """Hash password with Argon2"""
    import argon2

    ph = argon2.PasswordHasher()
    return ph.hash(password)
```

### Security Testing

#### Vulnerability Scanning

```bash
# Scan dependencies
safety check

# Scan containers
trivy image unrealircd:latest

# Scan code for secrets
gitleaks detect --verbose
```

#### Security Test Cases

```python
def test_password_complexity():
    """Test password complexity requirements"""
    validator = PasswordValidator()

    # Should accept strong passwords
    assert validator.is_strong("MySecurePass123!")

    # Should reject weak passwords
    assert not validator.is_strong("password")
    assert not validator.is_strong("123456")

def test_input_sanitization():
    """Test input sanitization prevents injection"""
    sanitizer = InputSanitizer()

    # Should clean dangerous input
    clean = sanitizer.clean("'; DROP TABLE users; --")
    assert "DROP TABLE" not in clean
    assert ";" not in clean
```

## Documentation

### Documentation Standards

#### README Structure

Every component should have:

```markdown
# Component Name

Brief description of what it does.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

Installation instructions.

## Configuration

Configuration options and examples.

## Usage

Usage examples and code samples.

## API Reference

If applicable, API documentation.

## Troubleshooting

Common issues and solutions.

## Contributing

How to contribute to this component.
```

#### Code Documentation

```python
def connect_to_irc(host: str, port: int, tls: bool = False) -> IRCConnection:
    """
    Establish connection to IRC server.

    Args:
        host: IRC server hostname or IP address
        port: IRC server port (usually 6667 or 6697)
        tls: Whether to use TLS/SSL connection

    Returns:
        IRCConnection: Established connection object

    Raises:
        ConnectionError: If connection fails
        TLSValidationError: If TLS certificate validation fails

    Example:
        >>> conn = connect_to_irc("irc.example.com", 6697, tls=True)
        >>> conn.is_connected()
        True
    """
    # Implementation here
    pass
```

### Documentation Testing

```bash
# Test documentation builds
make docs

# Check links
markdown-link-check docs/*.md

# Validate examples
python -m doctest src/**/*.py
```

## Release Process

### Version Management

#### Semantic Versioning

```bash
# Version format: MAJOR.MINOR.PATCH
# 1.0.0 - Initial release
# 1.1.0 - New features
# 1.1.1 - Bug fixes
# 2.0.0 - Breaking changes
```

#### Version Bumping

```bash
# Update version in relevant files
vim pyproject.toml  # Python version
vim src/backend/unrealircd/Containerfile  # Container version

# Create git tag
git tag -a v1.2.0 -m "Release version 1.2.0"

# Push tag
git push origin v1.2.0
```

### Release Checklist

#### Pre-Release

- [ ] All tests pass (`make test`)
- [ ] Code quality checks pass (`make lint`)
- [ ] Security scan clean
- [ ] Documentation updated
- [ ] Version numbers updated
- [ ] Changelog written

#### Release

- [ ] Create release branch
- [ ] Tag release
- [ ] Build and publish containers
- [ ] Create GitHub release
- [ ] Update documentation
- [ ] Announce release

#### Post-Release

- [ ] Monitor for issues
- [ ] Plan next development cycle
- [ ] Update roadmap
- [ ] Gather feedback

## Contributing Guidelines

### Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help newcomers learn
- Maintain professional communication

### Pull Request Process

#### PR Requirements

- [ ] Tests included for new functionality
- [ ] Documentation updated
- [ ] Code follows style guidelines
- [ ] Commit messages follow conventional format
- [ ] PR description explains changes and rationale

#### PR Review Process

1. **Automated Checks**: CI/CD pipeline runs automatically
2. **Peer Review**: At least one maintainer reviews code
3. **Testing**: Reviewer tests functionality
4. **Approval**: PR approved by maintainer
5. **Merge**: Squash merge with conventional commit message

### Issue Reporting

#### Bug Reports

```markdown
## Bug Report

**Description**
Clear description of the bug.

**Steps to Reproduce**
1. Step 1
2. Step 2
3. Step 3

**Expected Behavior**
What should happen.

**Actual Behavior**
What actually happens.

**Environment**
- OS: [e.g., Ubuntu 22.04]
- Docker version: [e.g., 24.0.1]
- IRC.atl.chat version: [e.g., v1.0.0]

**Additional Context**
Any other relevant information.
```

#### Feature Requests

```markdown
## Feature Request

**Problem**
Description of the problem this feature would solve.

**Solution**
Description of the proposed solution.

**Alternatives**
Alternative solutions considered.

**Additional Context**
Any other relevant information.
```

## Community Resources

### Getting Help

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General discussion and Q&A
- **IRC Channel**: #help on irc.atl.chat
- **Documentation**: Comprehensive guides and API reference

### Development Resources

- **Architecture Overview**: High-level system design
- **API Documentation**: Complete API reference
- **Testing Guide**: Testing strategies and best practices
- **Security Guide**: Security considerations and practices

## Related Documentation

- [README.md](../README.md) - Project overview and quick start
- [TESTING.md](TESTING.md) - Comprehensive testing guide
- [DOCKER.md](DOCKER.md) - Container development and deployment
- [API.md](API.md) - JSON-RPC and WebSocket API documentation
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [CI_CD.md](CI_CD.md) - CI/CD pipeline and automation