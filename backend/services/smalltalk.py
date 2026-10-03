"""
services/smalltalk.py

Rule-based detection of pure small talk (greeting / thanks / bye / "what can
you do") so the chat graph can answer directly instead of running a
restaurant search.

Design rule: a message counts as small talk ONLY if the WHOLE message is
small talk. "hello" -> small talk. "hello, spicy kuch batao" -> NOT small
talk (it contains a real request), so it still goes to the normal
parse -> retrieve flow. This keeps false positives near zero.
"""

import random
import re
from typing import Optional

_PUNCT = re.compile(r"[^\w\s]", re.UNICODE)  # also strips emojis


def _norm(text: str) -> str:
    t = _PUNCT.sub(" ", (text or "").lower())
    return re.sub(r"\s+", " ", t).strip()


_LEADING_GREET = re.compile(
    r"^(hello|hi+|hey+|heya|yo|hola|sup|namaste|namaskar|"
    r"good morning|good afternoon|good evening)\b\s*"
)
_GREET_TAIL = re.compile(
    r"(there|everyone|geotaste|bot|buddy|friend|ji|"
    r"how are you|how r u|kaise ho|kaise hain aap|kya haal hai|kya haal chaal|"
    r"whats up|what s up|wassup)?"
)
_LEADING_ACK = re.compile(r"^(ok|okay|cool|great|nice|awesome|perfect|got it)\s+")
_THANKS = re.compile(
    r"(thanks?|thank you|thankyou|thx|ty|shukriya|dhanyavad|dhanyawad)"
    r"( a lot| so much| very much| bahut| you)*( ji)?"
)
_BYE = re.compile(r"(bye|goodbye|good bye|see you|see ya|cya|tata|alvida|good night|gn)( .{0,20})?")
_HELP = re.compile(
    r"(who are you|what are you|what can you do|what do you do|help|help me|"
    r"how do you work|how to use|what is geotaste|kaun ho tum|tum kaun ho|"
    r"kya kar sakte ho|aap kya kar sakte ho)"
)


def detect_smalltalk(text: str) -> Optional[str]:
    """Returns 'greeting' | 'thanks' | 'bye' | 'help' or None."""
    t = _norm(text)
    if not t or len(t.split()) > 7:
        return None

    if _BYE.fullmatch(t):
        return "bye"

    rest = _LEADING_GREET.sub("", t, count=1)
    if rest != t and _GREET_TAIL.fullmatch(rest.strip()):
        return "greeting"
    if _GREET_TAIL.fullmatch(t) and t:  # "how are you", "kaise ho" on their own
        return "greeting"

    if _THANKS.fullmatch(_LEADING_ACK.sub("", t, count=1)):
        return "thanks"

    if _HELP.fullmatch(t):
        return "help"
    return None


_REPLIES = {
    "greeting": [
        "Hey there! 👋 I'm GeoTaste. Tell me what you're craving, a cuisine, a mood or a budget, and I'll find spots in {city}.",
        "Hello! 😊 Hungry? Ask me something like \"spicy biryani under 300\" or \"a cozy cafe\" and I'll suggest places in {city}.",
        "Hi! 🍽️ What are you in the mood for today? I can search restaurants in {city} by cuisine, budget or mood.",
    ],
    "thanks": [
        "Anytime! 😊 Want me to look for something else?",
        "Happy to help! Let me know if you want more options.",
    ],
    "bye": [
        "Bye! 👋 Come back when you're hungry.",
        "See you soon! Happy eating 🍛",
    ],
    "help": [
        "I recommend restaurants in {city} based on what you type. Try: \"street food near me\", "
        "\"cheap South Indian\", \"something sweet\", or after results, \"the first one, love it\" "
        "so I learn your taste.",
    ],
}


def smalltalk_reply(kind: str, city: str = "your city") -> str:
    return random.choice(_REPLIES[kind]).format(city=(city or "your city").title())