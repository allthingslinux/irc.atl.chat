"""IRC protocol integration tests."""

import pytest
import socket
import ssl
import time
import threading
from unittest.mock import patch
import select


class IRCClient:
    """Simple IRC client for testing."""

    def __init__(self, host="localhost", port=6667, use_ssl=False, timeout=30):
        self.host = host
        self.port = port
        self.use_ssl = use_ssl
        self.timeout = timeout
        self.socket = None
        self.buffer = ""
        self.connected = False

    def connect(self):
        """Connect to IRC server."""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(self.timeout)
            self.socket.connect((self.host, self.port))

            if self.use_ssl:
                context = ssl.create_default_context()
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
                self.socket = context.wrap_socket(self.socket)

            self.connected = True
            return True
        except (socket.error, ssl.SSLError) as e:
            print(f"Connection failed: {e}")
            return False

    def disconnect(self):
        """Disconnect from IRC server."""
        if self.socket:
            try:
                self.socket.close()
            except:
                pass
        self.connected = False

    def send(self, message):
        """Send message to server."""
        if not self.connected or not self.socket:
            return False

        try:
            self.socket.send(f"{message}\r\n".encode())
            return True
        except socket.error:
            self.connected = False
            return False

    def receive(self, timeout=5):
        """Receive data from server."""
        if not self.connected or not self.socket:
            return None

        try:
            ready = select.select([self.socket], [], [], timeout)
            if ready[0]:
                data = self.socket.recv(4096).decode()
                if data:
                    self.buffer += data
                    return data
        except socket.error:
            self.connected = False

        return None

    def read_line(self):
        """Read a complete line from buffer."""
        if "\r\n" in self.buffer:
            line, self.buffer = self.buffer.split("\r\n", 1)
            return line
        return None

    def wait_for_message(self, expected_text, timeout=10):
        """Wait for a specific message from server."""
        start_time = time.time()

        while time.time() - start_time < timeout:
            data = self.receive(1)
            if data and expected_text in data:
                return True
            time.sleep(0.1)

        return False


class TestIRCProtocol:
    """Test IRC protocol functionality."""

    @pytest.fixture
    def irc_client(self):
        """Create IRC client for testing."""
        client = IRCClient()
        yield client
        client.disconnect()

    @pytest.fixture
    def ssl_irc_client(self):
        """Create SSL IRC client for testing."""
        client = IRCClient(use_ssl=True, port=6697)
        yield client
        client.disconnect()

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_server_connection(self, irc_client):
        """Test basic IRC server connection."""
        assert irc_client.connect(), "Should be able to connect to IRC server"

        # Wait for server welcome message
        assert irc_client.wait_for_message("001"), "Should receive server welcome (001)"

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_ssl_connection(self, ssl_irc_client):
        """Test SSL IRC server connection."""
        assert ssl_irc_client.connect(), (
            "Should be able to connect to IRC server via SSL"
        )

        # Wait for server welcome message
        assert ssl_irc_client.wait_for_message("001"), (
            "Should receive server welcome (001) over SSL"
        )

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_nick_registration(self, irc_client):
        """Test IRC nick registration."""
        assert irc_client.connect(), "Should connect to IRC server"

        # Set nickname
        test_nick = f"testuser_{int(time.time())}"
        assert irc_client.send(f"NICK {test_nick}"), "Should send NICK command"
        assert irc_client.send("USER testuser 0 * :Test User"), (
            "Should send USER command"
        )

        # Should receive welcome message
        assert irc_client.wait_for_message("001"), "Should receive welcome message"

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_channel_join(self, irc_client):
        """Test IRC channel joining."""
        assert irc_client.connect(), "Should connect to IRC server"

        # Register user
        test_nick = f"testuser_{int(time.time())}"
        assert irc_client.send(f"NICK {test_nick}")
        assert irc_client.send("USER testuser 0 * :Test User")
        assert irc_client.wait_for_message("001")

        # Join channel
        test_channel = f"#test_{int(time.time())}"
        assert irc_client.send(f"JOIN {test_channel}")

        # Should receive JOIN confirmation and channel info
        assert irc_client.wait_for_message("JOIN"), "Should receive JOIN confirmation"
        assert irc_client.wait_for_message("353"), (
            "Should receive channel user list (353)"
        )

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_ping_pong(self, irc_client):
        """Test IRC PING/PONG mechanism."""
        assert irc_client.connect(), "Should connect to IRC server"

        # Register user
        test_nick = f"testuser_{int(time.time())}"
        assert irc_client.send(f"NICK {test_nick}")
        assert irc_client.send("USER testuser 0 * :Test User")
        assert irc_client.wait_for_message("001")

        # Send PING and expect PONG
        ping_token = f"test_{int(time.time())}"
        assert irc_client.send(f"PING {ping_token}")

        # Should receive PONG response
        assert irc_client.wait_for_message(f"PONG {ping_token}"), (
            "Should receive PONG response"
        )

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_multiple_clients(self):
        """Test multiple IRC clients connecting simultaneously."""
        clients = []
        nicks = []

        # Create multiple clients
        for i in range(3):
            client = IRCClient()
            nick = f"multitest_{i}_{int(time.time())}"
            clients.append(client)
            nicks.append(nick)

        try:
            # Connect all clients
            for i, client in enumerate(clients):
                assert client.connect(), f"Client {i} should connect"

                # Register each client
                assert client.send(f"NICK {nicks[i]}")
                assert client.send(f"USER user{i} 0 * :Test User {i}")
                assert client.wait_for_message("001"), (
                    f"Client {i} should receive welcome"
                )

            # All clients should be connected
            assert all(client.connected for client in clients), (
                "All clients should be connected"
            )

        finally:
            # Cleanup
            for client in clients:
                client.disconnect()

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_server_info(self, irc_client):
        """Test IRC server information commands."""
        assert irc_client.connect(), "Should connect to IRC server"

        # Register user
        test_nick = f"testuser_{int(time.time())}"
        assert irc_client.send(f"NICK {test_nick}")
        assert irc_client.send("USER testuser 0 * :Test User")
        assert irc_client.wait_for_message("001")

        # Test VERSION command
        assert irc_client.send("VERSION")
        assert irc_client.wait_for_message("351"), (
            "Should receive VERSION response (351)"
        )

        # Test TIME command
        assert irc_client.send("TIME")
        assert irc_client.wait_for_message("391"), "Should receive TIME response (391)"

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_connection_timeout(self):
        """Test connection timeout handling."""
        # Try to connect to non-existent server
        client = IRCClient(host="127.0.0.1", port=9999, timeout=5)

        start_time = time.time()
        result = client.connect()
        end_time = time.time()

        assert not result, "Should not connect to non-existent server"
        assert end_time - start_time < 10, "Should timeout within reasonable time"

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_reconnection(self, irc_client):
        """Test IRC reconnection capability."""
        assert irc_client.connect(), "Should connect initially"

        # Register user
        test_nick = f"testuser_{int(time.time())}"
        assert irc_client.send(f"NICK {test_nick}")
        assert irc_client.send("USER testuser 0 * :Test User")
        assert irc_client.wait_for_message("001")

        # Disconnect
        irc_client.disconnect()
        assert not irc_client.connected, "Should be disconnected"

        # Reconnect
        assert irc_client.connect(), "Should reconnect"
        assert irc_client.wait_for_message("001"), (
            "Should receive welcome after reconnection"
        )

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_message_buffering(self, irc_client):
        """Test IRC message buffering and parsing."""
        assert irc_client.connect(), "Should connect to IRC server"

        # Send multiple commands quickly
        test_nick = f"testuser_{int(time.time())}"
        commands = [
            f"NICK {test_nick}",
            "USER testuser 0 * :Test User",
            "VERSION",
            "TIME",
        ]

        for cmd in commands:
            assert irc_client.send(cmd)

        # Should receive responses for all commands
        responses_received = 0
        start_time = time.time()

        while time.time() - start_time < 10 and responses_received < 4:
            data = irc_client.receive(1)
            if data:
                if "001" in data or "351" in data or "391" in data:
                    responses_received += 1

        assert responses_received >= 2, "Should receive expected server responses"


class TestIRCProtocolEdgeCases:
    """Test IRC protocol edge cases and error conditions."""

    @pytest.mark.integration
    @pytest.mark.irc
    def test_irc_invalid_nick(self, irc_client):
        """Test handling of invalid nickname."""
        assert irc_client.connect(), "Should connect to IRC server"

        # Try invalid nickname (too long)
        long_nick = "a" * 100
        assert irc_client.send(f"NICK {long_nick}")

        # Should receive error response
        assert irc_client.wait_for_message("432"), (
            "Should receive ERR_ERRONEUSNICKNAME (432)"
        )

    @pytest.mark.integration
    @pytest.mark.irc
    def test_irc_duplicate_nick(self, irc_client):
        """Test handling of duplicate nickname."""
        # This test requires two clients - simplified version
        assert irc_client.connect(), "Should connect to IRC server"

        # Try to set a nickname that might already exist
        # In practice, this depends on server state
        test_nick = f"testuser_{int(time.time())}"
        assert irc_client.send(f"NICK {test_nick}")
        assert irc_client.send("USER testuser 0 * :Test User")

        # Should either succeed or get nick in use error
        response = irc_client.wait_for_message("001") or irc_client.wait_for_message(
            "433"
        )
        assert response, "Should receive either welcome (001) or nick in use (433)"

    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_connection_limits(self):
        """Test IRC server connection limits (if any)."""
        # This is a basic test - actual limits depend on server configuration
        clients = []

        try:
            # Try to create many connections
            for i in range(10):  # Reasonable number for testing
                client = IRCClient(timeout=5)
                if client.connect():
                    clients.append(client)
                else:
                    break

            # Should have at least some successful connections
            assert len(clients) > 0, "Should be able to create at least one connection"

        finally:
            for client in clients:
                client.disconnect()

    @pytest.mark.integration
    @pytest.mark.irc
    def test_irc_command_case_insensitivity(self, irc_client):
        """Test that IRC commands are case insensitive."""
        assert irc_client.connect(), "Should connect to IRC server"

        # Send commands in different cases
        test_nick = f"testuser_{int(time.time())}"

        # Mix of upper and lowercase
        assert irc_client.send(f"NiCk {test_nick}")
        assert irc_client.send("UsEr testuser 0 * :Test User")

        # Should still receive welcome
        assert irc_client.wait_for_message("001"), (
            "Should receive welcome despite case mixing"
        )
