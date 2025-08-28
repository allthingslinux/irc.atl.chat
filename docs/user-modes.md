# UnrealIRCd User Modes Reference

This is the list of all user modes that can be set on a user. You can only set user modes on yourself and not on other users. Use the command: `MODE yournick +modeshere`.

## Detailed Mode Reference

| User Mode | Module | Description | Restrictions | Sysop Notes |
|-----------|--------|-------------|--------------|-------------|
| `B` | usermodes/bot | Marks you as being a bot. This will add a line to /WHOIS so people can easily recognize bots. | | **Bot Setup:** Essential for transparency. Users can see bot status in /WHOIS. Consider for all automated services. |
| `d` | *built-in* | Makes it so you can not receive channel PRIVMSG's, except for messages prefixed with a channel-command-prefix character. Could be used by bots to reduce traffic so they only see !somecmd type of things. | | **Bot Optimization:** Reduces message load for command bots. Configure channel-command-prefix in your bot's channels (usually `!` or `.`). |
| `D` | usermodes/privdeaf | Makes it so you can not receive private messages (PM's) from anyone except IRCOps, servers and services. | | **High Security:** Recommended for public-facing staff accounts. Prevents PM spam but allows official communications. |
| `G` | usermodes/censor | Swear filter: filters out all the "bad words" configured in the Badword block | | **Content Filtering:** Useful for family-friendly environments. Configure badword blocks in server config. May impact legitimate technical discussions. |
| `H` | *built-in* | Hide IRCop status. Regular users using /WHOIS or other commands will not see that you are an IRC Operator. | IRCOp-only | **Stealth Moderation:** Allows ops to monitor without revealing status. Useful for undercover moderation and reducing targeted harassment. |
| `I` | *built-in* | Hide idle time in /WHOIS. | see set block for more details: set::hide-idle-time | **Privacy:** Configure `set::hide-idle-time` to control who can see idle times. Useful for staff who need to appear available. |
| `i` | *built-in* | Makes you so called 'invisible'. A confusing term to mean that you're just hidden from /WHO and /NAMES if queried by someone outside the channel. Normally set by default through set::modes-on-connect and often by the users' IRC client as well. | | **Default Privacy:** Should be in `set::modes-on-connect`. Doesn't make you truly invisible - just hides from broad searches. Essential for user privacy. |
| `o` | *built-in* | IRC Operator | Set by server | **Operator Status:** Granted via OPER command with valid credentials. Cannot be set manually. Gives access to operator commands and channels. |
| `p` | usermodes/privacy | Hide channels you are in from /WHOIS, for extra privacy. | | **Enhanced Privacy:** Prevents channel list disclosure. Useful for staff who join monitoring channels or users wanting maximum privacy. |
| `q` | usermodes/nokick | Unkickable (only by U:lines, eg: services) | IRCOp-only (but not all) | **Protection Mode:** Prevents kicks except by services. Use sparingly - can be seen as abuse. Good for critical bots in important channels. |
| `r` | *built-in* | Indicates this is a "registered nick" | Set by services | **Authentication Status:** Shows user is identified with services. Cannot be set manually. Used by other modes like `+R` for filtering. |
| `R` | usermodes/regonlymsg | Only receive private messages from users who are "registered users" (authenticated by Services) | | **Anti-Spam:** Highly effective against PM spam. Requires users to register with services first. Recommended for public channels' regular users. |
| `S` | usermodes/servicebot | User is a services bot (gives some extra protection) | Services-only | **Services Protection:** Automatically set by services software. Provides additional protections against kicks/bans. Cannot be manually set. |
| `s` | *built-in* | Server notices for IRCOps, see Snomasks | IRCOp-only | **Monitoring:** Enables server notices. Use `/MODE yournick +s +snomask` to select specific notices. Essential for network monitoring. |
| `T` | usermodes/noctcp | Prevents you from receiving CTCP's. | | **Anti-Flood:** Blocks CTCP requests (VERSION, TIME, etc.). Recommended for bots and users experiencing CTCP floods. May break some client features. |
| `t` | *built-in* | Indicates you are using a /VHOST | Set by server upon /VHOST, /OPER, /*HOST, .. | **Virtual Host Status:** Shows when custom hostname is active. Set automatically by server. Configure vhost blocks for custom hostnames. |
| `W` | usermodes/showwhois | Lets you see when people do a /WHOIS on you. | IRCOp-only | **Monitoring Tool:** Shows who is checking your information. Useful for detecting surveillance or troubleshooting user issues. |
| `w` | *built-in* | Can listen to wallops messages (/WALLOPS from IRCOps') | | **Network Announcements:** Receives important network-wide messages from operators. Recommended for channel operators and regular helpers. |
| `x` | *built-in* | Gives you a hidden / cloaked hostname. | | **Privacy Essential:** Hides real IP/hostname. Should be in `set::modes-on-connect`. Configure `cloak-keys` properly. Critical for user safety. |
| `Z` | usermodes/secureonlymsg | Allows only users on a secure connection to send you private messages/notices/CTCPs. Conversely, you can't send any such messages to non-secure users either. | | **SSL-Only Communication:** Enforces encrypted communications. Good for security-conscious networks. May limit communication with users on non-SSL ports. |
| `z` | *built-in* | Indicates you are connected via SSL/TLS | Set by server | **Security Indicator:** Shows encrypted connection status. Set automatically when connecting via SSL/TLS ports (typically 6697). Cannot be manually set. |

## Configuration Tips for System Operators

### Default User Modes
Set in your `unrealircd.conf`: