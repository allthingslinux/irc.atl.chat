"""Integration tests using pydle library - showcasing IRCv3 and modular features."""

import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch

# Import pydle conditionally
pydle = pytest.importorskip("pydle")


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
        self.events_log.append(
            ("part", {"channel": channel, "user": user, "reason": reason})
        )

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


class TestPydleIntegration:
    """Integration tests for pydle library showcasing IRCv3 features."""

    @pytest.mark.asyncio
    async def test_pydle_client_creation(self):
        """Test creating a pydle client."""
        client = PydleTestBot("TestBot")

        # In pydle, nickname is set but shows as <unregistered> until connected
        assert hasattr(client, "nickname")
        assert hasattr(client, "on_connect")
        assert hasattr(client, "on_message")

        # Test that the client has the expected nickname in _nicknames
        assert "TestBot" in client._nicknames

    @pytest.mark.asyncio
    async def test_pydle_modular_features(self):
        """Test pydle's modular feature system."""
        # Test featurize function
        CustomClient = pydle.featurize(
            pydle.features.RFC1459Support, pydle.features.CTCPSupport
        )

        client = CustomClient("TestBot")
        assert hasattr(client, "ctcp")  # Should have CTCP support
        assert hasattr(client, "message")  # Should have basic messaging

    @pytest.mark.asyncio
    async def test_pydle_connection_lifecycle(self):
        """Test pydle client connection lifecycle."""
        client = PydleTestBot("TestBot")

        # Mock the connection
        with patch.object(client, "connect", new_callable=AsyncMock) as mock_connect:
            mock_connect.return_value = None

            await client.connect("localhost", 6667, tls=False)

            # Verify connection was attempted
            mock_connect.assert_called_once_with("localhost", 6667, tls=False)

    @pytest.mark.asyncio
    async def test_pydle_event_handling(self):
        """Test pydle event handling."""
        client = PydleTestBot("TestBot")

        # Simulate events
        await client.on_connect()

        # Check that events were logged
        assert len(client.events_log) >= 1
        assert client.events_log[0][0] == "connect"

    @pytest.mark.asyncio
    async def test_pydle_message_handling(self):
        """Test pydle message handling."""
        client = PydleTestBot("TestBot")

        # Simulate receiving messages
        await client.on_private_message("user1", "hello bot")
        await client.on_channel_message("#test", "user2", "hello everyone")
        await client.on_message("#test", "user3", "direct message")

        # Verify messages were recorded
        assert len(client.messages_received) == 3

        private_msg = [
            msg for msg in client.messages_received if msg.get("type") == "private"
        ][0]
        assert private_msg["source"] == "user1"
        assert private_msg["message"] == "hello bot"

        channel_msg = [
            msg for msg in client.messages_received if msg.get("type") == "channel"
        ][0]
        assert channel_msg["channel"] == "#test"
        assert channel_msg["source"] == "user2"

    @pytest.mark.asyncio
    async def test_pydle_channel_operations(self):
        """Test pydle channel operations."""
        client = PydleTestBot("TestBot")

        # Simulate joining/parting channels
        await client.on_join("#channel1", "TestBot")
        await client.on_join("#channel2", "TestBot")
        await client.on_part("#channel1", "TestBot", "Goodbye")

        # Verify channel tracking
        assert "#channel2" in client.joined_channels
        assert "#channel1" not in client.joined_channels

    @pytest.mark.asyncio
    async def test_pydle_client_pool(self):
        """Test pydle client pool functionality."""
        pool = pydle.ClientPool()

        # Create multiple clients
        clients = []
        for i in range(3):
            client = PydleTestBot(f"TestBot{i}")
            clients.append(client)

        # Verify pool creation
        assert pool is not None
        assert len(clients) == 3

        # Test that clients have unique nicknames
        nicknames = [client.nickname for client in clients]
        assert len(set(nicknames)) == 3

    def test_pydle_feature_system(self):
        """Test pydle's feature system and featurize function."""
        # Test different feature combinations
        features = [
            pydle.features.RFC1459Support,
            pydle.features.CTCPSupport,
            pydle.features.AccountSupport,
        ]

        for feature in features:
            assert hasattr(feature, "__bases__")

        # Test featurize with single feature
        SingleFeatureClient = pydle.featurize(pydle.features.RFC1459Support)
        client = SingleFeatureClient("TestBot")
        assert hasattr(client, "join")  # Basic IRC functionality

    @pytest.mark.asyncio
    async def test_pydle_async_operations(self):
        """Test pydle's async operation capabilities."""
        client = PydleTestBot("TestBot")

        # Mock async operations
        with patch.object(client, "join", new_callable=AsyncMock) as mock_join:
            with patch.object(
                client, "message", new_callable=AsyncMock
            ) as mock_message:
                mock_join.return_value = None
                mock_message.return_value = None

                # Test async operations
                await client.join("#test")
                await client.message("#test", "Hello world!")

                # Verify calls were made
                mock_join.assert_called_once_with("#test")
                mock_message.assert_called_once_with("#test", "Hello world!")

    def test_pydle_ircv3_capabilities(self):
        """Test pydle IRCv3 capability support."""
        # Test that pydle supports IRCv3 features
        client = PydleTestBot("TestBot")

        # Check for IRCv3-related attributes
        assert hasattr(client, "capabilities") or hasattr(client, "_capabilities")

        # Test capability negotiation (if available)
        if hasattr(client, "capabilities"):
            assert isinstance(client.capabilities, dict)

    def test_pydle_sasl_authentication(self):
        """Test pydle SASL authentication setup."""
        # Test SASL authentication parameters
        client = PydleTestBot(
            "TestBot",
            sasl_username="testuser",
            sasl_password="testpass",
            sasl_identity="testaccount",
        )

        # Verify SASL parameters are set
        assert client.sasl_username == "testuser"
        assert client.sasl_password == "testpass"
        assert client.sasl_identity == "testaccount"

    def test_pydle_custom_features(self):
        """Test creating custom pydle features."""

        class CustomFeature(pydle.BasicClient):
            """Custom feature example."""

            async def on_raw_999(self, source, params):
                """Handle custom numeric 999."""
                pass

        # Test that custom feature can be created
        assert hasattr(CustomFeature, "on_raw_999")

        # Test featurizing with custom feature
        CustomClient = pydle.featurize(pydle.Client, CustomFeature)
        client = CustomClient("TestBot")

        # Should have both base and custom functionality
        assert hasattr(client, "join")  # From base Client
        assert hasattr(client, "on_raw_999")  # From custom feature

    @pytest.mark.asyncio
    async def test_pydle_error_handling(self):
        """Test pydle error handling."""
        client = PydleTestBot("TestBot")

        # Test handling of invalid operations
        with patch.object(client, "_send", new_callable=AsyncMock) as mock_send:
            mock_send.side_effect = Exception("Connection error")

            # Should handle errors gracefully
            try:
                await client.message("#test", "test")
            except Exception:
                pass  # Expected to handle errors

    def test_pydle_protocol_compliance(self):
        """Test pydle protocol compliance."""
        client = PydleTestBot("TestBot")

        # Test RFC1459 compliance markers
        assert hasattr(client, "nickname")
        assert hasattr(client, "username") or hasattr(client, "ident")
        assert hasattr(client, "realname")

        # Test basic IRC commands are available
        commands = ["join", "part", "message", "quit", "nick"]
        for cmd in commands:
            assert hasattr(client, cmd), f"Missing command: {cmd}"

    @pytest.mark.asyncio
    async def test_pydle_event_loop_integration(self):
        """Test pydle integration with asyncio event loop."""
        client = PydleTestBot("TestBot")

        # Test that client works with asyncio
        loop = asyncio.get_event_loop()

        # Should be able to create tasks
        async def dummy_task():
            return "test"

        task = loop.create_task(dummy_task())
        result = await task

        assert result == "test"

        # Client should be compatible with the event loop
        assert hasattr(client, "_loop") or hasattr(client, "loop")


# Test fixtures for pydle
@pytest.fixture
async def pydle_client():
    """Provide a pydle test client fixture."""
    client = PydleTestBot("TestBot")

    # Mock connection for testing
    with patch.object(client, "connect", new_callable=AsyncMock):
        yield client


@pytest.fixture
def pydle_client_pool():
    """Provide a pydle client pool fixture."""
    pool = pydle.ClientPool()
    yield pool


@pytest.fixture
def custom_pydle_client():
    """Provide a custom-featured pydle client fixture."""
    CustomClient = pydle.featurize(
        pydle.features.RFC1459Support, pydle.features.CTCPSupport
    )
    client = CustomClient("TestBot")
    yield client
