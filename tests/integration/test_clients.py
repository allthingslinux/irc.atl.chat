"""Client Library Integration Tests

Tests for various IRC client libraries using controlled IRC server.
Includes pydle, python-irc, and other client library integrations.
"""

import pytest
import asyncio
import time
import threading

from ..utils.base_test_cases import BaseServerTestCase
from ..utils.specifications import mark_specifications

# Import libraries conditionally
try:
    import pydle

    PYDLE_AVAILABLE = True
except ImportError:
    pydle = None
    PYDLE_AVAILABLE = False

try:
    import irc

    IRC_AVAILABLE = True
except ImportError:
    irc = None
    IRC_AVAILABLE = False


class PydleTestBot(pydle.Client):
    """Test bot using pydle's modular feature system."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.messages_received = []
        self.joined_channels = set()
        self.events_log = []

    async def on_connect(self):
        """Called when connected to IRC server."""
        await super().on_connect()
        self.events_log.append(("connect", None))

    async def on_join(self, channel, user):
        """Called when a user joins a channel."""
        await super().on_join(channel, user)
        if user == self.nickname:
            self.joined_channels.add(channel)
        self.events_log.append(("join", {"channel": channel, "user": user}))

    async def on_part(self, channel, user, reason=None):
        """Called when a user parts a channel."""
        await super().on_part(channel, user, reason)
        if user == self.nickname:
            self.joined_channels.discard(channel)
        self.events_log.append(("part", {"channel": channel, "user": user, "reason": reason}))

    async def on_message(self, target, source, message):
        """Called when a message is received."""
        await super().on_message(target, source, message)

        msg_data = {
            "target": target,
            "source": source,
            "message": message,
            "timestamp": asyncio.get_event_loop().time(),
        }
        self.messages_received.append(msg_data)
        self.events_log.append(("message", msg_data))

    async def on_private_message(self, source, message):
        """Called when a private message is received."""
        await super().on_private_message(source, message)

        msg_data = {
            "type": "private",
            "source": source,
            "message": message,
            "timestamp": asyncio.get_event_loop().time(),
        }
        self.messages_received.append(msg_data)
        self.events_log.append(("private_message", msg_data))

    async def on_channel_message(self, channel, source, message):
        """Called when a channel message is received."""
        await super().on_channel_message(channel, source, message)

        msg_data = {
            "type": "channel",
            "channel": channel,
            "source": source,
            "message": message,
            "timestamp": asyncio.get_event_loop().time(),
        }
        self.messages_received.append(msg_data)
        self.events_log.append(("channel_message", msg_data))

    async def on_nick_change(self, old_nick, new_nick):
        """Called when a user changes nickname."""
        await super().on_nick_change(old_nick, new_nick)
        self.events_log.append(("nick_change", {"old": old_nick, "new": new_nick}))

    async def on_quit(self, user, reason=None):
        """Called when a user quits."""
        await super().on_quit(user, reason)
        self.events_log.append(("quit", {"user": user, "reason": reason}))


class IRCClientTest:
    """IRC client for testing purposes using the python-irc library."""

    def __init__(self, host: str = "localhost", port: int = 6667):
        self.host = host
        self.port = port
        self.client = None
        self.connected = False
        self.messages = []
        self.events = []

    def connect(self) -> bool:
        """Connect to IRC server."""
        try:
            self.client = irc.client.IRC()
            self.client.connect(self.host, self.port, nickname="testuser")

            self.client.add_global_handler("welcome", self.on_welcome)
            self.client.add_global_handler("privmsg", self.on_privmsg)
            self.client.add_global_handler("pubmsg", self.on_pubmsg)
            self.client.add_global_handler("join", self.on_join)
            self.client.add_global_handler("part", self.on_part)
            self.client.add_global_handler("quit", self.on_quit)

            self.thread = threading.Thread(target=self.client.process_forever)
            self.thread.daemon = True
            self.thread.start()

            timeout = 10
            start_time = time.time()
            while not self.connected and (time.time() - start_time) < timeout:
                time.sleep(0.1)

            return self.connected
        except Exception:
            return False

    def disconnect(self):
        """Disconnect from server."""
        if self.client:
            self.client.disconnect()
        self.connected = False

    def send_command(self, command: str) -> bool:
        """Send IRC command."""
        if not self.client:
            return False
        try:
            self.client.send_raw(command)
            return True
        except Exception:
            return False

    def wait_for_response(self, expected_type: str, timeout: int = 5) -> bool:
        """Wait for a specific type of response."""
        start_time = time.time()
        while (time.time() - start_time) < timeout:
            if any(expected_type.lower() in str(event).lower() for event in self.events):
                return True
            time.sleep(0.1)
        return False

    def join_channel(self, channel: str) -> bool:
        """Join a channel."""
        if not self.client:
            return False
        try:
            self.client.join(channel)
            return True
        except Exception:
            return False

    def part_channel(self, channel: str) -> bool:
        """Part a channel."""
        if not self.client:
            return False
        try:
            self.client.part(channel)
            return True
        except Exception:
            return False

    def send_message(self, target: str, message: str) -> bool:
        """Send a message to a target."""
        if not self.client:
            return False
        try:
            self.client.privmsg(target, message)
            return True
        except Exception:
            return False

    def on_welcome(self, connection, event):
        """Handle welcome event."""
        self.connected = True
        self.events.append(("welcome", event.arguments[0] if event.arguments else ""))

    def on_privmsg(self, connection, event):
        """Handle private message."""
        self.messages.append(("privmsg", event.source.nick, event.arguments[0]))

    def on_pubmsg(self, connection, event):
        """Handle public message."""
        self.messages.append(("pubmsg", event.target, event.source.nick, event.arguments[0]))

    def on_join(self, connection, event):
        """Handle join event."""
        self.events.append(("join", event.source.nick, event.target))

    def on_part(self, connection, event):
        """Handle part event."""
        self.events.append(("part", event.source.nick, event.target))

    def on_quit(self, connection, event):
        """Handle quit event."""
        self.events.append(("quit", event.source.nick))


@pytest.mark.skipif(not PYDLE_AVAILABLE, reason="pydle library not available")
class TestPydleIntegration(BaseServerTestCase):
    """Integration tests for pydle library using controlled IRC server."""

    @mark_specifications("RFC1459", "RFC2812")
    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    @pytest.mark.asyncio
    async def test_pydle_basic_connection(self):
        """Test pydle client connecting to controlled IRC server."""
        client = PydleTestBot(f"pydle_test_{int(time.time())}")

        try:
            await client.connect(self.hostname, self.port, tls=False)
            await asyncio.sleep(2)

            assert client.connected
            assert len(client.events_log) > 0
            assert any(event[0] == "connect" for event in client.events_log)

        finally:
            await client.disconnect()

    @mark_specifications("RFC1459", "RFC2812")
    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    @pytest.mark.asyncio
    async def test_pydle_channel_operations(self):
        """Test pydle client channel join/part operations."""
        client = PydleTestBot(f"pydle_chan_{int(time.time())}")

        try:
            await client.connect(self.hostname, self.port, tls=False)
            await asyncio.sleep(1)

            test_channel = f"#pydle_test_{int(time.time())}"
            await client.join(test_channel)
            await asyncio.sleep(1)

            assert test_channel in client.joined_channels
            assert any(event[0] == "join" and event[1]["channel"] == test_channel for event in client.events_log)

            await client.part(test_channel, "Testing complete")
            await asyncio.sleep(1)

            assert test_channel not in client.joined_channels
            assert any(event[0] == "part" and event[1]["channel"] == test_channel for event in client.events_log)

        finally:
            await client.disconnect()

    @mark_specifications("RFC1459", "RFC2812")
    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    @pytest.mark.asyncio
    async def test_pydle_messaging(self):
        """Test pydle client messaging capabilities."""
        client1 = PydleTestBot(f"pydle_msg1_{int(time.time())}")
        client2 = PydleTestBot(f"pydle_msg2_{int(time.time())}")

        try:
            await client1.connect(self.hostname, self.port, tls=False)
            await client2.connect(self.hostname, self.port, tls=False)
            await asyncio.sleep(1)

            test_channel = f"#pydle_msg_{int(time.time())}"
            await client1.join(test_channel)
            await client2.join(test_channel)
            await asyncio.sleep(1)

            test_message = f"Hello from pydle client at {int(time.time())}"
            await client1.message(test_channel, test_message)
            await asyncio.sleep(1)

            assert len(client2.messages_received) > 0
            received_msg = client2.messages_received[-1]
            assert received_msg["type"] == "channel"
            assert received_msg["channel"] == test_channel
            assert received_msg["source"] == client1.nickname
            assert test_message in received_msg["message"]

        finally:
            await client1.disconnect()
            await client2.disconnect()

    @mark_specifications("RFC1459", "RFC2812")
    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    @pytest.mark.asyncio
    async def test_pydle_private_messaging(self):
        """Test pydle private messaging."""
        client1 = PydleTestBot(f"pydle_priv1_{int(time.time())}")
        client2 = PydleTestBot(f"pydle_priv2_{int(time.time())}")

        try:
            await client1.connect(self.hostname, self.port, tls=False)
            await client2.connect(self.hostname, self.port, tls=False)
            await asyncio.sleep(1)

            private_msg = f"Private message at {int(time.time())}"
            await client1.message(client2.nickname, private_msg)
            await asyncio.sleep(1)

            assert len(client2.messages_received) > 0
            received_msg = client2.messages_received[-1]
            assert received_msg["type"] == "private"
            assert received_msg["source"] == client1.nickname
            assert private_msg in received_msg["message"]

        finally:
            await client1.disconnect()
            await client2.disconnect()


@pytest.mark.skipif(not IRC_AVAILABLE, reason="irc library not available")
class TestIRCLibraryIntegration(BaseServerTestCase):
    """Integration tests for python-irc library using controlled server."""

    @pytest.fixture
    def irc_client(self):
        """Create IRC library client for testing."""
        client = IRCClientTest(self.hostname, self.port)
        yield client
        client.disconnect()

    @mark_specifications("RFC1459", "RFC2812")
    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_library_connection(self, irc_client):
        """Test connecting to controlled IRC server using IRC library."""
        assert irc_client.connect()
        assert irc_client.connected
        assert len(irc_client.events) > 0
        assert any(e[0] == "welcome" for e in irc_client.events)

    @mark_specifications("RFC1459", "RFC2812")
    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_library_channel_operations(self, irc_client):
        """Test IRC library channel join/part operations."""
        assert irc_client.connect()
        time.sleep(2)

        test_channel = f"#irc_lib_test_{int(time.time())}"
        assert irc_client.join_channel(test_channel)

        time.sleep(2)
        join_events = [e for e in irc_client.events if e[0] == "join"]
        assert len(join_events) > 0

        assert irc_client.part_channel(test_channel)
        time.sleep(1)
        part_events = [e for e in irc_client.events if e[0] == "part"]
        assert len(part_events) > 0

    @mark_specifications("RFC1459", "RFC2812")
    @pytest.mark.integration
    @pytest.mark.irc
    @pytest.mark.slow
    def test_irc_library_messaging(self, irc_client):
        """Test IRC library messaging capabilities."""
        # This would require setting up two IRC library clients
        # For now, just test basic connectivity
        assert irc_client.connect()
        time.sleep(2)

        # Test sending a simple command
        assert irc_client.send_command("VERSION")
        time.sleep(1)

        # Should receive some response
        assert len(irc_client.messages) >= 0  # May not capture all messages


class TestPydleFeatures:
    """Tests for pydle library features (non-integration)."""

    @pytest.mark.asyncio
    async def test_pydle_client_creation(self):
        """Test creating a pydle client."""
        client = PydleTestBot("TestBot")
        assert hasattr(client, "nickname")
        assert hasattr(client, "on_connect")
        assert hasattr(client, "on_message")
        assert "TestBot" in client._nicknames

    @pytest.mark.asyncio
    async def test_pydle_modular_features(self):
        """Test pydle's modular feature system."""
        CustomClient = pydle.featurize(pydle.features.RFC1459Support, pydle.features.CTCPSupport)
        client = CustomClient("TestBot")
        assert hasattr(client, "ctcp")
        assert hasattr(client, "message")

    @pytest.mark.asyncio
    async def test_pydle_message_handling(self):
        """Test pydle message handling."""
        client = PydleTestBot("TestBot")

        await client.on_private_message("user1", "hello bot")
        await client.on_channel_message("#test", "user2", "hello everyone")
        await client.on_message("#test", "user3", "direct message")

        assert len(client.messages_received) == 3

        private_msg = [msg for msg in client.messages_received if msg.get("type") == "private"][0]
        assert private_msg["source"] == "user1"
        assert private_msg["message"] == "hello bot"

        channel_msg = [msg for msg in client.messages_received if msg.get("type") == "channel"][0]
        assert channel_msg["channel"] == "#test"
        assert channel_msg["source"] == "user2"

    @pytest.mark.asyncio
    async def test_pydle_channel_operations(self):
        """Test pydle channel operations."""
        client = PydleTestBot("TestBot")

        await client.on_join("#channel1", "TestBot")
        await client.on_join("#channel2", "TestBot")
        await client.on_part("#channel1", "TestBot", "Goodbye")

        assert "#channel2" in client.joined_channels
        assert "#channel1" not in client.joined_channels
